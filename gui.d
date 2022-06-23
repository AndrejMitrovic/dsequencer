/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gui;

import userdata;
import sound;

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

import sawtooth;
import effects;

import zynd.dsp.svfilter;

struct StateContext
{
    Context ctx;

    this(Context ctx)
    {
        this.ctx = ctx;
        ctx.save();
    }

    ~this()
    {
        ctx.restore();
    }

    alias ctx this;
}

/* A place to hold Widget objects. Since each window has a unique HWND,
 * we can use this hash type to store references to Widgets and call
 * their window processing methods.
 */
Widget[HWND] WidgetHandles;

string WidgetClass = "WidgetClass";

HANDLE makeWindow(HWND hwnd, int childID = 1, string classname = WidgetClass, string description = null)
{
    return CreateWindow(classname.toUTF16z, description.toUTF16z,
                        WS_CHILDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN,        // WS_CLIPCHILDREN is necessary
                        0, 0, 0, 0,                                           // Size!int and Position are set by MoveWindow
                        hwnd, cast(HANDLE)childID,                            // child ID
                        cast(HINSTANCE)GetWindowLongPtr(hwnd, GWL_HINSTANCE), // hInstance
                        NULL);
}

RGB brightness(RGB rgb, double amount)
{
    with (rgb)
    {
        if (red > 0)
            red = max(0, min(1.0, red + amount));

        if (green > 0)
            green = max(0, min(1.0, green + amount));

        if (blue > 0)
            blue  = max(0, min(1.0, blue  + amount));
    }

    return rgb;
}

// Derived from http://cairographics.org/cookbook/roundedrectangles/
void DrawRoundedRect(Context ctx, int x, int y, int width, int height, int radius = 10)
{
    ctx.moveTo(x + radius, y);                                                                 // Move to A
    ctx.lineTo(x + width - radius, y);                                                         // Straight line to B
    ctx.curveTo(x + width, y, x + width, y, x + width, y + radius);                            // Curve to C, Control points are both at Q
    ctx.lineTo(x + width, y + height - radius);                                                // Move to D
    ctx.curveTo(x + width, y + height, x + width, y + height, x + width - radius, y + height); // Curve to E
    ctx.lineTo(x + radius, y + height);                                                        // Line to F
    ctx.curveTo(x, y + height, x, y + height, x, y + height - radius);                         // Curve to G
    ctx.lineTo(x, y + radius);                                                                 // Line to H
    ctx.curveTo(x, y, x, y, x + radius, y);                                                    // Curve to A
}

/* Each allocation consumes 3 GDI objects. */
class PaintBuffer
{
    this(HDC localHdc, int cxClient, int cyClient)
    {
        width  = cxClient;
        height = cyClient;

        hBuffer    = CreateCompatibleDC(localHdc);
        hBitmap    = CreateCompatibleBitmap(localHdc, cxClient, cyClient);
        hOldBitmap = SelectObject(hBuffer, hBitmap);

        surf        = new Win32Surface(hBuffer);
        ctx         = Context(surf);
        initialized = true;
    }

    ~this()
    {
        if (initialized)
        {
            clear();
        }
    }

    void clear()
    {
        // segfaults
        //~ surf.dispose();
        //~ ctx.dispose();
        //~ surf.finish();

        SelectObject(hBuffer, hOldBitmap);
        DeleteObject(hBitmap);
        DeleteDC(hBuffer);

        initialized = false;
    }

    bool initialized;
    int  width, height;
    HDC  hBuffer;
    HBITMAP hBitmap;
    HBITMAP hOldBitmap;
    Context ctx;
    Surface surf;
}

abstract class Widget
{
    Widget parent;
    PaintBuffer paintBuffer;
    PAINTSTRUCT ps;

    HWND hwnd;
    int  width, height;
    bool needsRedraw = true;

    this(Widget parent, HWND hwnd, int width, int height)
    {
        this.parent = parent;
        this.hwnd   = hwnd;
        this.width  = width;
        this.height = height;
    }

    @property Size!int size()
    {
        return Size!int(width, height);
    }

    abstract LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        switch (message)
        {
            case WM_ERASEBKGND:
            {
                return 1;
            }

            case WM_PAINT:
            {
                OnPaint(hwnd, message, wParam, lParam);
                return 0;
            }

            case WM_SIZE:
            {
                width  = LOWORD(lParam);
                height = HIWORD(lParam);

                auto localHdc = GetDC(hwnd);

                if (paintBuffer !is null)
                {
                    paintBuffer.clear();
                }

                paintBuffer = new PaintBuffer(localHdc, width, height);
                ReleaseDC(hwnd, localHdc);

                needsRedraw = true;
                blit();
                return 0;
            }

            case WM_TIMER:
            {
                blit();
                return 0;
            }

            case WM_DESTROY:
            {
                // @BUG@
                // Not doing this here causes exceptions being thrown from within cairo
                // when calling surface.dispose(). I'm not sure why yet.
                paintBuffer.clear();
                return 0;
            }

            default:
        }

        return DefWindowProc(hwnd, message, wParam, lParam);
    }

    void redraw()
    {
        needsRedraw = true;
        blit();
    }

    void blit()
    {
        InvalidateRect(hwnd, null, true);
    }

    void OnPaint(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
    {
        auto ctx       = &paintBuffer.ctx;
        auto hBuffer   = paintBuffer.hBuffer;
        auto hdc       = BeginPaint(hwnd, &ps);
        auto boundRect = ps.rcPaint;

        if (needsRedraw)
        {
            draw(StateContext(*ctx));
            needsRedraw = false;
        }

        with (boundRect)
        {
            BitBlt(hdc, left, top, right - left, bottom - top, hBuffer, left, top, SRCCOPY);
        }

        EndPaint(hwnd, &ps);
    }

    abstract void draw(StateContext ctx);
}

class StepWidget : Widget
{
    UserData* userData;
    alias UserData.curBeat curBeat;
    static bool selectState;

    this(Widget parent, UserData* userData, HWND hwnd, int width, int height)
    {
        this.userData = userData;
        super(parent, hwnd, width, height);
    }
}

class Step : StepWidget
{
    bool  _selected;
    size_t beatIndex;
    size_t stepIndex;

    @property void selected(bool state)
    {
        _selected = state;
        redraw();
    }

    @property bool selected()
    {
        return _selected;
    }

    this(Widget parent, UserData* userData, size_t beatIndex, size_t stepIndex, HWND hwnd, int width, int height)
    {
        this.beatIndex = beatIndex;
        this.stepIndex = stepIndex;
        super(parent, userData, hwnd, width, height);
    }

    override LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        switch (message)
        {
            case WM_LBUTTONDOWN:
            {
                selected = !selected;
                selectState = selected;
                //~ userData.sequence[beatIndex][stepIndex] = selected;
                break;
            }

            case WM_MOUSEMOVE:
            {
                if (wParam & MK_LBUTTON)
                {
                    selected = selectState;
                    //~ userData.sequence[beatIndex][stepIndex] = selected;
                }
                break;
            }

            default:
        }

        return super.process(message, wParam, lParam);
    }

    override void draw(StateContext ctx)
    {
        ctx.rectangle(1, 1, width - 2, height - 2);
        ctx.setSourceRGB(0, 0, 0.8);
        ctx.fill();

        if (selected)
        {
            auto darkCyan = RGB(0, 0.6, 1);
            ctx.setSourceRGB(darkCyan);
            DrawRoundedRect(ctx, 5, 5, width - 10, height - 10, 15);
            ctx.fill();

            if (beatIndex == curBeat)
            {
                ctx.setSourceRGB(1, 1, 0);
            }
            else
            {
                ctx.setSourceRGB(brightness(darkCyan, + 0.4));
            }

            DrawRoundedRect(ctx, 10, 10, width - 20, height - 20, 15);
            ctx.fill();
        }
    }
}

class TimeStep : StepWidget
{
    size_t beatIndex;

    this(Widget parent, size_t beatIndex, HWND hwnd, int width, int height)
    {
        this.beatIndex = beatIndex;
        super(parent, null, hwnd, width, height);
    }

    override LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        return super.process(message, wParam, lParam);
    }

    override void draw(StateContext ctx)
    {
        ctx.rectangle(1, 1, width - 2, height - 2);
        ctx.setSourceRGB(0, 0, 0.6);
        ctx.fill();

        if (beatIndex == curBeat)
        {
            auto darkBlue = RGB(0, 0, 0.8);
            ctx.setSourceRGB(darkBlue);
            DrawRoundedRect(ctx, 5, 5, width - 10, height - 10, 15);
            ctx.fill();

            ctx.setSourceRGB(brightness(darkBlue, + 0.2));
            DrawRoundedRect(ctx, 10, 10, width - 20, height - 20, 15);
            ctx.fill();
        }
    }
}

class Steps : Widget
{
    UserData* userData;

    alias UserData.BeatCount BeatCount;
    alias UserData.StepCount StepCount;

    TimeStep[BeatCount] timeSteps;
    Step[StepCount][BeatCount] steps;
    alias UserData.curBeat curBeat;

    int stepWidth;
    int stepHeight;

    // note: the main window is still not a Widget class, so parent is null
    this(Widget parent, UserData* userData, HWND hwnd, int width, int height)
    {
        super(parent, hwnd, width, height);

        this.userData = userData;

        stepWidth  = width / BeatCount;
        stepHeight = height / 10;

        createWidgets!TimeStep();
        createWidgets!Step(stepHeight);

        enum TimerID = 5;
        enum double BPM = 140.0 * 2;
        //~ SetTimer(hwnd, TimerID, cast(int)((60.0 / BPM) * 1000), NULL);
        Pt_Start(cast(int)((60.0 / BPM) * 1000), &timerCallback, null);
    }

    // todo: figure out how to remove code duplication here. The root cause are
    // the 1 vs 2 foreach loops.
    void createWidgets(WidgetType)(size_t vOffset = 0) if (is(WidgetType == TimeStep))
    {
        foreach (beatIndex; 0 .. BeatCount)
        {
            auto hWindow = makeWindow(hwnd);
            auto widget = new WidgetType(this, beatIndex, hWindow, stepWidth, stepHeight);
            WidgetHandles[hWindow] = widget;
            timeSteps[beatIndex]   = widget;

            auto size = widget.size;
            MoveWindow(hWindow, beatIndex * stepWidth, 0, size.width, size.height, true);
        }
    }

    void createWidgets(WidgetType)(size_t vOffset = 0) if (is(WidgetType == Step))
    {
        // set random calls as enabled on start of the app
        int steps_to_enable = 20;

        foreach (beatIndex; 0 .. BeatCount)
        {
            foreach (stepIndex; 0 .. StepCount)
            {
                auto hWindow = makeWindow(hwnd);
                auto widget = new WidgetType(this, userData, beatIndex, stepIndex, hWindow, stepWidth, stepHeight);
                WidgetHandles[hWindow]      = widget;
                steps[beatIndex][stepIndex] = widget;

                auto size = widget.size;
                MoveWindow(hWindow, beatIndex * stepWidth, vOffset + (stepIndex * stepHeight), size.width, size.height, true);
            }

            bool select = cast(bool)uniform(0, 2);
            steps[beatIndex][uniform(0, StepCount)].selected = select;
        }
    }

    void randomizeSteps()
    {
        foreach (beatIndex; 0 .. BeatCount)
        {
            auto max_enabled = uniform(1, 3);

            foreach (stepIndex; 0 .. StepCount)
            {
                auto enabled = max_enabled ? dice(70, 20) : 0;
                steps[beatIndex][stepIndex].selected = !!enabled;
                max_enabled -= enabled;
            }
        }
    }

    void redrawSteps(size_t beatIndex)
    {
        timeSteps[beatIndex].redraw();
        foreach (step; steps[beatIndex])
            step.redraw();
    }

    void timerCallback(PtTimestamp timestamp, void* none)
    {
        auto lastBeat = curBeat;
        curBeat = (curBeat + 1) % BeatCount;

        size_t index;

        // todo: optimize by having an int[BeatCount] of values, or int[][BeatCount]
        foreach (step; retro(steps[curBeat][]))
        {
            if (step.selected)
            {
                auto freq = getFreqStep(index);
                userData.sineTables[index].phase_increment = CalcPhaseIncrement(freq);
                userData.sineTables[index].keyIndex = index;
                userData.sineTables[index].isActive = true;
            }
            else
            {
                userData.sineTables[index].phase_increment = 0;
                userData.sineTables[index].keyIndex = index;
                userData.sineTables[index].isActive = false;
            }

            index++;
        }

        redrawSteps(lastBeat);
        redrawSteps(curBeat);
    }

    override LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        switch (message)
        {
            default:
        }

        return super.process(message, wParam, lParam);
    }

    override void draw(StateContext ctx)
    {
        ctx.setSourceRGB(1, 1, 1);
        ctx.paint();
    }
}
