/*
 *             Copyright Andrej Mitrovic 2018.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module winmain;

import sequencer;

pragma(lib, "gdi32.lib");

import win32.windef;
import win32.winuser;
import win32.wingdi;

import std.stdio;

import portaudio.portaudio;
import cairo.win32;

import gui;
import effects;
import sound;
import userdata;

import std.utf;
import core.runtime;
import zynd.dsp.svfilter;

import std.algorithm : min, max;

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

    try
    {
        Runtime.initialize();
        myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch (Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = -1;
    }

    return result;
}
