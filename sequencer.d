/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module sequencer;

import gui;
import userdata;
import sound;

import sawtooth;
import effects;

import zynd.dsp.svfilter;

import core.memory;
import core.runtime;
import core.thread;
import core.stdc.config;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.functional;
import std.math;
import std.random;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import std.utf;

pragma(lib, "gdi32.lib");

import win32.windef;
import win32.winuser;
import win32.wingdi;

alias std.algorithm.min min;
alias std.algorithm.max max;

import cairo.cairo;
import cairo.win32;

alias cairo.cairo.RGB RGB;

import portaudio.portaudio;
import portaudio.exception;

import portmidi.portmidi;
import portmidi.exception;
import portmidi.porttime;

// Note: must be gshared or otherwise put them in the user data
__gshared bool use_sine_synth = true;
__gshared bool use_fm_synth = false;

extern(C) int patestCallback(const void* inputBuffer,
                             void* outputBuffer,
                             c_ulong framesPerBuffer,
                             const PaStreamCallbackTimeInfo* timeInfo,
                             PaStreamCallbackFlags statusFlags,
                             void* inData)
{
    //~ version (Debug)
    //~ {
        //~ import std.math;
        //~ FloatingPointControl fpc;
        //~ fpc.enableExceptions(FloatingPointControl.severeExceptions);
    //~ }

    UserData* userData = cast(UserData*)inData;
    float* _out        = cast(float*)outputBuffer;

    double step = 0;
    double lSample = 0;
    double rSample = 0;
    double result = 0;
    enum attenuation = 2.0;

    for (int i = 0; i < framesPerBuffer; i++)
    {
        foreach (ref data; userData.sineTables)
        {
            data.left_phase += (data.phase_increment * data.multIncrement1);

            if (data.left_phase >= 1.0f)
                data.left_phase -= 1.0f;

            data.right_phase += (data.phase_increment * data.multIncrement2);

            if (data.right_phase >= 1.0f)
                data.right_phase -= 1.0f;
        }

        lSample = 0;
        rSample = 0;

        double activeSteps = 1;
        foreach (ref data; userData.sineTables)
        {
            if (use_sine_synth)
            {
                lSample += LookupSine(data, data.left_phase)  * 0.5;
                rSample += LookupSine(data, data.right_phase) * 0.5;
            }

            if (data.isActive)
            {
                activeSteps += 1;

                step = (5.0 * (data.keyIndex + 2)) / 15000.0;

                if (use_fm_synth)
                {
                    lSample += ADC_out(attenuation * update_blit(userData.blit, step));
                    rSample += ADC_out(attenuation * update_blit(userData.blit, step));
                }
            }
        }

        lSample /= activeSteps;
        rSample /= activeSteps;

        *_out++ = lSample / 2.0;
        *_out++ = rSample / 2.0;
    }

    // deinterleaving
    _out = cast(float*)outputBuffer;
    foreach (frame; 0 .. framesPerBuffer)
    {
        foreach (channel; 0 .. ChannelCount)
        {
            userData.EffectBuffer[channel][frame] = *_out++;
        }
    }

    userData.l_filter.filterout(userData.EffectBuffer[0]);
    userData.r_filter.filterout(userData.EffectBuffer[1]);
    userData.effect.process(userData.EffectBuffer, userData.EffectBuffer, framesPerBuffer);

    // interleaving
    _out = cast(float*)outputBuffer;
    foreach (frame; 0 .. framesPerBuffer)
    {
        foreach (channel; 0 .. ChannelCount)
        {
            *_out++ = userData.EffectBuffer[channel][frame];
        }
    }

    return PaStreamCallbackResult.paContinue;
}

extern(C) static void StreamFinished(void* userData)
{
    UserData* data = cast(UserData*)userData;
    data.playing = false;
}

void createStream(PaStream** stream, UserData* data)
{
    PaStreamParameters outputParameters;
    PaError error;

    outputParameters.device = Pa_GetDefaultOutputDevice();
    enforce(outputParameters.device != paNoDevice,
            new PortaudioException("Error: No default output device."));

    outputParameters.channelCount     = 2;         /* stereo output */
    outputParameters.sampleFormat     = paFloat32; /* 32 bit floating point output */
    outputParameters.suggestedLatency = Pa_GetDeviceInfo(outputParameters.device).defaultLowOutputLatency;
    outputParameters.hostApiSpecificStreamInfo = null;

    error = Pa_OpenStream(
        stream,
        null, // no input
        &outputParameters,
        SampleRate,
        FramesPerBuffer,
        paNoFlag,
        &patestCallback,
        data);

    enforce(error >= PaErrorCode.paNoError, new PortaudioException(error));
}

void startStream(PaStream* stream)
{
    auto error = Pa_StartStream(stream);
    enforce(error >= PaErrorCode.paNoError, new PortaudioException(error));
}

void stopStream(PaStream* stream)
{
    auto error = Pa_StopStream(stream);
    enforce(error >= PaErrorCode.paNoError, new PortaudioException(error));
}

/*
 * All Widget windows have this window procedure registered via RegisterClass(),
 * we use it to dispatch to the appropriate Widget window processing method.
 *
 * A similar technique is used in the DFL and DGUI libraries for all of its
 * windows and widgets.
 */
extern (Windows)
LRESULT winDispatch(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    auto widget = hwnd in WidgetHandles;

    if (widget !is null)
    {
        return widget.process(message, wParam, lParam);
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

extern (Windows)
LRESULT mainWinProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    static PaintBuffer paintBuffer;
    static int width, height;

    version (AudioEngine)
    {
        static UserData userData;
        static PaStream* stream;
        static Steps widget;
    }

    void draw(StateContext ctx)
    {
        ctx.setSourceRGB(1, 1, 1);
        ctx.paint();
    }

    switch (message)
    {
        case WM_CREATE:
        {
            // todo: move synth initialization somewhere else
            import zynd.globals;
            synth = new SYNTH_T;
            synth.buffersize = FramesPerBuffer;
            synth.samplerate = SampleRate;

            auto hDesk = GetDesktopWindow();
            RECT rc;
            GetClientRect(hDesk, &rc);

            auto localHdc = GetDC(hwnd);
            paintBuffer = new PaintBuffer(localHdc, rc.right, rc.bottom);

            GetClientRect(hwnd, &rc);
            auto hWindow = makeWindow(hwnd);
            widget = new Steps(null, &userData, hWindow, 400, 400);
            WidgetHandles[hWindow] = widget;

            auto size = widget.size;
            MoveWindow(hWindow, 0, 0, size.width + 10, size.height, true);

            // userData init
            version (AudioEngine)
            {
                foreach (idx, ref sineTable; userData.sineTables)
                {
                    sineTable = makeSineTable(idx);
                }

                userData.blit = makeBlit();
                userData.effect = new Delay(16, FramesPerBuffer);

                with (userData.effect)
                {
                    fFeedBack = 0.5;
                    setNewDelay!1(0.3);
                    setNewDelay!2(0.6);
                }

                userData.l_filter = new SVFilter(0, 2400, 0.3, 0);
                userData.r_filter = new SVFilter(0, 2400, 0.3, 0);

                userData.EffectBuffer[0][] = 0;
                userData.EffectBuffer[1][] = 0;

                createStream(&stream, &userData);
                startStream(stream);
            }

            return 0;
        }

        case WM_LBUTTONDOWN:
        {
            SetFocus(hwnd);
            return 0;
        }

        case WM_SIZE:
        {
            width  = LOWORD(lParam);
            height = HIWORD(lParam);
            return 0;
        }

        case WM_PAINT:
        {
            auto ctx     = paintBuffer.ctx;
            auto hBuffer = paintBuffer.hBuffer;
            PAINTSTRUCT ps;
            auto hdc       = BeginPaint(hwnd, &ps);
            auto boundRect = ps.rcPaint;

            draw(StateContext(paintBuffer.ctx));

            with (boundRect)
            {
                BitBlt(hdc, left, top, right - left, bottom - top, paintBuffer.hBuffer, left, top, SRCCOPY);
            }

            EndPaint(hwnd, &ps);
            return 0;
        }

        case WM_TIMER:
        {
            InvalidateRect(hwnd, null, true);
            return 0;
        }

        case WM_MOUSEWHEEL:
        {
            return 0;
        }

        case WM_DESTROY:
        {
            PostQuitMessage(0);
            return 0;
        }

        case WM_CHAR:
        {
            switch (wParam)
            {
                case 's':
                {
                    use_sine_synth ^= 1;
                    writefln("Sine Synth set to: %s", use_sine_synth);
                    return 0;
                }

                case 'f':
                {
                    use_fm_synth ^= 1;
                    writefln("FM Synth set to: %s", use_fm_synth);
                    return 0;
                }

                case 'r':
                {
                    widget.randomizeSteps();
                    writeln("Randomizing steps");

                    return 0;
                }

                default:
                    writeln(cast(char)wParam);
                    return 0;
            }
        }

        case WM_KEYDOWN:
        {
            switch (wParam)
            {
                case VK_UP:
                {
                    userData.l_filter.setfreq(userData.l_filter.getfreq + 40);
                    userData.r_filter.setfreq(userData.l_filter.getfreq + 40);
                    //~ writeln(userData.l_filter.getfreq);
                    return 0;
                }

                case VK_DOWN:
                {
                    userData.l_filter.setfreq(userData.l_filter.getfreq - 40);
                    userData.r_filter.setfreq(userData.l_filter.getfreq - 40);
                    //~ writeln(userData.l_filter.getfreq);
                    return 0;
                }

                case VK_LEFT:
                {
                    auto type = userData.l_filter.gettype;
                    userData.l_filter.settype(min(3, max(0, type ? (type - 1) : 0)));
                    userData.r_filter.settype(min(3, max(0, type ? (type - 1) : 0)));
                    return 0;
                }

                case VK_RIGHT:
                {
                    auto type = userData.l_filter.gettype;
                    userData.l_filter.settype(max(0, min(3, type + 1)));
                    userData.r_filter.settype(max(0, min(3, type + 1)));
                    return 0;
                }

                default:
            }

            return 0;
        }

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

void initPortAudio()
{
    auto error = Pa_Initialize();
    enforce(error >= PaErrorCode.paNoError, new PortaudioException(error));
}

void killPortAudio()
{
    Pa_Terminate();
}


int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    version (AudioEngine)
    {
        initPortAudio();
        scope(exit)
        {
            killPortAudio();
        }
    }

    string appName = "Step Sequencer";

    HWND hwnd;
    MSG  msg;
    WNDCLASS wndclass;

    /* One class for the main window */
    wndclass.lpfnWndProc   = &mainWinProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wndclass.hbrBackground = null;
    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = appName.toUTF16z;

    if (!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    /* Separate window class for Widgets. */
    wndclass.hbrBackground = null;
    wndclass.lpfnWndProc   = &winDispatch;
    wndclass.cbWndExtra    = 0;
    wndclass.hIcon         = NULL;
    wndclass.lpszClassName = WidgetClass.toUTF16z;

    if (!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z, "step sequencer",
                        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,  // WS_CLIPCHILDREN is necessary
                        cast(int)(1680 / 3.3), 1050 / 3,
                        400, 400,
                        NULL, NULL, hInstance, NULL);

    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;
    void exceptionHandler(Throwable e) { throw e; }

    try
    {
        Runtime.initialize(&exceptionHandler);
        myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate(&exceptionHandler);
    }
    catch (Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = -1;
    }

    return result;
}
