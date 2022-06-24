import std.algorithm;
import std.math;
import std.conv;
import core.stdc.config;
import std.stdio;
import std.range;
import std.typetuple;
import std.traits;

// taken from vst 2.3 adelay

template isMultiDimArray(R)
{
    static if (isArray!(ElementType!R))
        enum isMultiDimArray = true;
    else
        enum isMultiDimArray = false;
}

template BaseElementType(R)
{
    static if (isArray!(ElementType!R))
        alias BaseElementType = BaseElementType!(ElementType!R);
    else static if (is (typeof({ return R.init.front(); }())T))
        alias BaseElementType = T;
    else
        alias BaseElementType = void;
}

struct ADelayProgram
{
    float fDelay    = 0.2;
    float fFeedBack = 0.5;
    float fOut      = 0.75;
    string name     = "Init";
}

enum
{
	// Global
	kNumPrograms = 16,

	// Parameters
	kDelay = 0,
	kFeedBack,
	kOut,
	kNumParams
}

class Delay
{
    this(int numPrograms, int SampleRate)
    {
        size     = 44100;
        cursor1   = 0;
        cursor2   = 0;
        delay1    = 0;
        delay2    = 0;
        buffer1   = new float[](size);
        buffer2   = new float[](size);
        programs.length = numPrograms;

        fDelay   = fFeedBack = fOut = 0;
        setProgram(0);
        resume();
    }

    void process(T)(ref T inputs, ref T outputs, int sampleFrames)
    if (isMultiDimArray!T && is(BaseElementType!T == float))
    {
        /+ version (Debug)
        {
            import std.math;
            FloatingPointControl fpc;
            fpc.disableExceptions(FloatingPointControl.allExceptions);
        } +/

        float* in1  = inputs[0].ptr;
        float* in2  = inputs[1].ptr;
        float* out1 = outputs[0].ptr;
        float* out2 = outputs[1].ptr;

        //~ while (--sampleFrames >= 0)
        //~ {
            //~ float x = (*in1++ + *in2++) / 2;
            //~ float y = buffer1[cursor];

            //~ buffer1[cursor++] = min(1.0, (x + y) * fFeedBack);

            //~ if (cursor >= delay)
                //~ cursor = 0;

            //~ *out1++ = y;
            //~ *out2++ = y;
        //~ }

        while (--sampleFrames >= 0)
        {
            float x1 = *in1++;
            float x2 = *in2++;
            float y1 = buffer1[cursor1];
            float y2 = buffer2[cursor2];

            buffer1[cursor1++] = (x1 + y1) * fFeedBack;
            buffer2[cursor2++] = (x2 + y2) * fFeedBack;

            if (cursor1 >= delay1)
                cursor1 = 0;

            if (cursor2 >= delay2)
                cursor2 = 0;

            *out1++ += (y1 * 0.5);
            *out2++ += (y2 * 0.5);
        }
    }

    void setProgram(int program)
    {
        curProgram = program;

        with (programs[program])
        {
            setParameter(kDelay, fDelay);
            setParameter(kFeedBack, fFeedBack);
            setParameter(kOut, fOut);
        }
    }

    void resume()
    {
        buffer1[] = 0;
        buffer2[] = 0;
    }

    void setDelay(float fdelay)
    {
        fDelay = fdelay;
        programs[curProgram].fDelay = fdelay;
        cursor1 = 0;
        cursor2 = 0;
        delay1  = cast(c_long)(fdelay * cast(float)(size - 1));
        delay2  = cast(c_long)(fdelay * cast(float)(size - 1));
    }

    void setNewDelay(int del)(float fdelay)
    {
        fDelay = fdelay;
        programs[curProgram].fDelay = fdelay;
        cursor1 = 0;
        cursor2 = 0;
        static if (del == 1)
        {
            delay1 = cast(c_long)(fdelay * cast(float)(size - 1));
        }
        else
        {
            delay2 = cast(c_long)(fdelay * cast(float)(size - 1));
        }
    }

    void setParameter(int index, float value)
    {
        switch (index)
        {
            case kDelay:
                setDelay(value);
                break;

            case kFeedBack:
                fFeedBack = programs[curProgram].fFeedBack = value;
                break;

            case kOut:
                fOut = programs[curProgram].fOut = value;
                break;

            default:
        }
    }

    float getParameter(int index)
    {
        float v = 0;

        switch (index)
        {
            case kDelay:
                v = fDelay;
                break;

            case kFeedBack:
                v = fFeedBack;
                break;

            case kOut:
                v = fOut;
                break;

            default:
        }

        return v;
    }

    float[] buffer1;
    float[] buffer2;

    ADelayProgram[] programs;
    size_t curProgram;

    float  fDelay;
    float  fFeedBack;
    float  fOut;
    c_long delay1;
    c_long delay2;
    c_long size;
    c_long cursor1;
    c_long cursor2;
}
