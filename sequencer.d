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

alias std.algorithm.min min;
alias std.algorithm.max max;

import cairo.cairo;

alias cairo.cairo.RGB RGB;

import portaudio.portaudio;
import portaudio.exception;

import portmidi.portmidi;
import portmidi.exception;
//import portmidi.porttime;

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

void initPortAudio()
{
    auto error = Pa_Initialize();
    enforce(error >= PaErrorCode.paNoError, new PortaudioException(error));
}

void killPortAudio()
{
    Pa_Terminate();
}

