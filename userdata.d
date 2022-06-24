/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module userdata;


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

//import win32.windef;
//import win32.winuser;
//import win32.wingdi;

alias std.algorithm.min min;
alias std.algorithm.max max;

import cairo.cairo;
//import cairo.win32;

alias cairo.cairo.RGB RGB;

import portaudio.portaudio;
import portaudio.exception;

import portmidi.portmidi;
import portmidi.exception;
//import portmidi.porttime;

import sawtooth;
import effects;

import zynd.dsp.svfilter;

enum ChannelCount = 2;

// todo: dynamically initialize
enum SampleRate      = 44100;
enum FramesPerBuffer = 512;
enum MinFreq   = 88.0f;
enum FreqStep  = 50.0f;
enum TableSize = 400;

struct SineTable
{
    bool isActive;
    float[TableSize + 1] sine;  /* add one for guard point for interpolation */
    float phase_increment = 0;
    float left_phase = 0;
    float right_phase = 0;
    float multIncrement1 = 1.0f;
    float multIncrement2 = 1.0f;
    int keyIndex;
}

struct UserData
{
    SVFilter l_filter;
    SVFilter r_filter;
    Delay effect;
    float[FramesPerBuffer][ChannelCount] EffectBuffer;
    enum BeatCount = 8;  // horizontal steps
    enum StepCount = 8;  // vertical steps

    __gshared static size_t curBeat;

    SineTable[8] sineTables;
    Blit blit;

    bool playing;
}
