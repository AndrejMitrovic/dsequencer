/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module sound;

import userdata;

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

double getFreqStep(int index)
{
    static float[16] values =
    [130.813, 146.832, 164.814, 174.614,
    195.998, 220.000, 246.942, 261.626,
    293.665, 329.628, 349.228, 391.995,
    440.000, 493.883, 523.251, 587.330];

    return values[index + 6];
}

auto CalcPhaseIncrement(T)(T freq)
{
    return freq / SampleRate;
}

/* Convert phase between and 1.0 to sine value
 * using linear interpolation.
 */
float LookupSine(ref SineTable data, float phase)
{
    static float fIndex;
    static int index;
    static float fract;
    static float lo;
    static float hi;
    static float val;

    fIndex = phase * TableSize;
    index  = cast(int)fIndex;
    fract  = fIndex - index;
    lo     = data.sine[index];
    hi     = data.sine[index + 1];
    val    = lo + fract * (hi - lo);

    return val;
}

SineTable makeSineTable(size_t idx)
{
    SineTable data;
    /* initialize sine wavetable */
    foreach (i; 0 .. TableSize)
    {
        data.sine[i] = 0.90f * cast(float)sin( (cast(double)i / cast(double)TableSize) * PI * 2.0);
    }

    data.sine[TableSize] = data.sine[0]; /* set guard point. */
    data.left_phase = data.right_phase = 0.0;
    data.multIncrement1 = 1.0;
    data.multIncrement2 = 1.0;
    data.phase_increment = 0;
    return data;
}

Blit makeBlit()
{
    Blit blue;
    init_blit(blue, 0.9, 0.001);
    return blue;
}
