module asio.generateAudioTable;

import std.algorithm;
import std.conv;
import std.math;
import std.stdio;
import std.traits;
import std.typetuple;

struct Phase(int Limit = -1)
{
    static if (Limit == -1)
    {
        private int limit = Limit;
    }
    else
    {
        private int limit;
    }
    
    //~ private int limit = Limit;
    private int phase;
    
    
    
    int opCall(int setlimit)
    {
        return phase;
    }    
    
    int opCall()
    {
        return phase;
    }
    
    int opOpAssign(string op)(int rhs) if (op == "+")
    {
        phase += rhs;
        boundsCheck();
        return phase;
    }
    
    void boundsCheck()
    {
        if (phase >= limit)
            phase -= limit;
    }
    
    string toString()
    {
        return to!string(phase);
    }
}

// find a way of having types constructable at compile time and via constructor
struct RunPhase
{
    this(int bufferSize)
    {
        limit = bufferSize;
    }
    
    private int limit;
    private int phase;
    
    @disable
    int opCall()
    {
        return phase;
    }
    
    int opOpAssign(string op)(int rhs) if (op == "+")
    {
        phase += rhs;
        boundsCheck();
        return phase;
    }
    
    void boundsCheck()
    {
        if (phase >= limit)
            phase -= limit;
    }
    
    string toString()
    {
        return to!string(phase);
    }
}

template isOneOf(X, T...)
{
    static if (!T.length)
        enum bool isOneOf = false;
    else static if (is (X == T[0]))
        enum bool isOneOf = true;
    else
        enum bool isOneOf = isOneOf!(X, T[1..$]);
}

typedef void Sine;
typedef void Saw;
typedef void Square;
alias TypeTuple!(Sine, Saw, Square) WaveForms;

private auto GenAudioTable(WaveForm, SampleType, int TableSize)()
    if (isOneOf!(WaveForm, WaveForms) && isOneOf!(SampleType, float, double))
{
    SampleType[TableSize] result;
    
    static if (is( WaveForm == Sine ))
    {
        foreach (index, ref sample; result)
        {
            result[index] = cast(SampleType)sin((cast(double)index / cast(double)TableSize) * PI * 2.);
        }  
    }
    else static if (is( WaveForm == Saw ))
    {
        foreach (index, ref sample; result)
        {
            result[index] = cast(SampleType)sin((cast(double)index / cast(double)TableSize) * PI * 1.);
        }        
    }
    else
    {
        static assert(0, "Failed");
    }
    
    return result;
}

struct AudioTable(WaveForm, SampleType, int PhaseCount, int TableSize) 
    if (isOneOf!(WaveForm, WaveForms) && isOneOf!(SampleType, float, double))
{
    @disable static void opCall() { }  // disable default ctor calls

    SampleType[TableSize] table = GenAudioTable!(WaveForm, SampleType, TableSize);
    Phase!TableSize[PhaseCount] phase;
}

//~ enum TableSize = 200;
//~ enum StereoPhase = 2;  // each channel will have its own phase
//~ AudioTable!(Sine, float, StereoPhase, TableSize) sineTable;

//~ void main()
//~ {    
    //~ float[1024][2] channels;
    
    //~ foreach (index, ref channel; channels)
    //~ {
        //~ foreach (ref sample; channel)
        //~ {
            //~ // left  channel has normal pitch
            //~ // right channel has higher pitch (skips the phase by +3 on each iteration)
            //~ sample = (index == 0) ? sineTable.table[sineTable.phase[0] += 1]    
                                  //~ : sineTable.table[sineTable.phase[1] += 3];   
        //~ }
    //~ }
    
    //~ writeln(channels);
//~ }
