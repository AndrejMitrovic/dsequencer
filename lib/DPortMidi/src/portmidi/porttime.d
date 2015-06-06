module portmidi.porttime;  /* millisecond timer */

/+
 + This is a translation of PortMidi's millisecond timer function to the D2 language.
 + Translated by Andrej Mitrovic.
 +/

import std.stdio;
import core.time;
import core.thread;

import win32.basetsd;
import win32.mmsystem;
import win32.windef;

version(Windows)
{
    pragma(lib, "winmm.lib");
}

import portmidi.portmidi;

enum PtError {
    ptNoError = 0,         /* success */
    ptHostError = -10000,  /* a system-specific error occurred */
    ptAlreadyStarted,      /* cannot start timer because it is already started */
    ptAlreadyStopped,      /* cannot stop timer because it is already stopped */
    ptInsufficientMemory   /* memory could not be allocated */
}

alias int PtTimestamp;
alias void function(PtTimestamp timestamp, void* userData) PtCallback;
alias void delegate(PtTimestamp timestamp, void* userData) PtDelegateCallback;

__gshared TIMECAPS caps;
__gshared int time_offset;
__gshared bool time_started_flag;
__gshared uint time_resolution;
__gshared uint timer_id;
__gshared PtCallback time_callback;
__gshared PtDelegateCallback time_DelegateCallback;

extern(Windows)
void winmm_time_DelegateCallback(uint uID, uint uMsg, DWORD_PTR dwUser, DWORD_PTR dw1, DWORD_PTR dw2)
{
    time_DelegateCallback(Pt_Time(null), cast(void*)dwUser);
}

PtError Pt_Start(uint resolution, PtDelegateCallback callback, void* userData)
{
    if (time_started_flag)
        return PtError.ptAlreadyStarted;

    timeBeginPeriod(resolution);
    time_resolution = resolution;
    time_offset = timeGetTime();
    time_started_flag = true;
    time_DelegateCallback = callback;

    if (callback)
    {
        timer_id = timeSetEvent(resolution, 1, cast(LPTIMECALLBACK)&winmm_time_DelegateCallback,
            cast(DWORD_PTR)userData, TIME_PERIODIC | TIME_CALLBACK_FUNCTION);

        if (!timer_id)
            return PtError.ptHostError;
    }

    return PtError.ptNoError;
}

extern(Windows)
void winmm_time_callback(uint uID, uint uMsg, DWORD_PTR dwUser, DWORD_PTR dw1, DWORD_PTR dw2)
{
    time_callback(Pt_Time(null), cast(void*)dwUser);
}

PtError Pt_Start(uint resolution, PtCallback callback, void* userData)
{
    if (time_started_flag)
        return PtError.ptAlreadyStarted;

    // todo: do checks for TIMERR_NOERROR here
    timeBeginPeriod(resolution);
    time_resolution = resolution;
    time_offset = timeGetTime();
    time_started_flag = true;
    time_callback = callback;

    if (callback)
    {
        timer_id = timeSetEvent(resolution, 1, cast(LPTIMECALLBACK)&winmm_time_callback,
            cast(DWORD_PTR)userData, TIME_PERIODIC | TIME_CALLBACK_FUNCTION);

        if (!timer_id)
            return PtError.ptHostError;
    }

    return PtError.ptNoError;
}

PtError Pt_Stop()
{
    if (!time_started_flag)
        return PtError.ptAlreadyStopped;

    if ((time_callback || time_DelegateCallback) && timer_id) {
        timeKillEvent(timer_id);
        time_callback = null;
        time_DelegateCallback = null;
        timer_id = 0;
    }

    time_started_flag = false;
    timeEndPeriod(time_resolution);
    return PtError.ptNoError;
}

int Pt_Started()
{
    return time_started_flag;
}

extern(C) PtTimestamp Pt_Time(void *time_info)
{
    return timeGetTime() - time_offset;
}

/** Sleep for duration milliseconds. */
void Pt_Sleep(int duration)
{
    Pt_Sleep(dur!("msecs")(duration));
}

/** Sleep for the target duration. */
void Pt_Sleep(Duration duration)
{
    Thread.sleep(duration);
}
