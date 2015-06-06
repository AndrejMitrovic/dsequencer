/* Converted to D from globals.h by htod */
module zynd.globals;

// todo: temporary workaround for client code,
// replace with casts later
version(X86)
    alias float sizef_t;
else version(X86_64)
    alias double sizef_t;

import std.math;
import std.random;

/*
   ZynAddSubFX - a software synthesizer

   globals.h - it contains program settings and the program capabilities
              like number of parts, of effects
   Copyright (C) 2002-2005 Nasca Octavian Paul
   Author: Nasca Octavian Paul

   This program is free software; you can redistribute it and/or modify
   it under the terms of version 2 of the GNU General Public License
   as published by the Free Software Foundation.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License (version 2 or later) for more details.

   You should have received a copy of the GNU General Public License (version 2)
   along with this program; if not, write to the Free Software Foundation,
   Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

 */

/**
 * The number of harmonics of additive synth
 * This must be smaller than OSCIL_SIZE/2
 */
// todo: oscil_size in cfg should make sure it's minimum 2x this size.
enum MAX_AD_HARMONICS = 128;

/**
 * The number of harmonics of substractive
 */
enum MAX_SUB_HARMONICS = 64;

/*
 * The maximum number of samples that are used for 1 PADsynth instrument(or item)
 */
enum PAD_MAX_SAMPLES = 64;

/*
 * Number of parts
 */
enum NUM_MIDI_PARTS = 16;

/*
 * Number of Midi channes
 */
enum NUM_MIDI_CHANNELS = 16;

/*
 * The number of voices of additive synth for a single note
 */
enum NUM_VOICES = 8;

/*
 * The poliphony (notes)
 */
enum POLIPHONY = 60;

/*
 * Number of system effects
 */
enum NUM_SYS_EFX = 4;

/*
 * Number of insertion effects
 */
enum NUM_INS_EFX = 8;

/*
 * Number of part's insertion effects
 */
enum NUM_PART_EFX = 3;

/*
 * Maximum number of the instrument on a part
 */
enum NUM_KIT_ITEMS = 16;

/*
 * How is applied the velocity sensing
 */
enum VELOCITY_MAX_SCALE = 8.0f;

/*
 * The maximum length of instrument's name
 */
enum PART_MAX_NAME_LEN = 30;

/*
 * The maximum number of bands of the equaliser
 */
enum MAX_EQ_BANDS = 8;
static assert(MAX_EQ_BANDS < 20, "Too many EQ bands in zynd.globals");

/*
 * Maximum filter stages
 */
enum MAX_FILTER_STAGES = 5;

/*
 * Formant filter (FF) limits
 */
enum FF_MAX_VOWELS   = 6;
enum FF_MAX_FORMANTS = 12;

enum FF_MAX_SEQUENCE = 8;
enum LOG_2  = 0.693147181f;
enum LOG_10 = 2.302585093f;

/*
 * The threshold for the amplitude interpolation used if the amplitude
 * is changed (by LFO's or Envelope's). If the change of the amplitude
 * is below this, the amplitude is not interpolated
 */
enum AMPLITUDE_INTERPOLATION_THRESHOLD = 0.0001f;

/*
 * How the amplitude threshold is computed
 */
float ABOVE_AMPLITUDE_THRESHOLD(A, B)(A a, B b)
{
    return ((2.0f * fabs((b) - (a)) / (fabs((b) + (a) + 0.0000000001f))) > AMPLITUDE_INTERPOLATION_THRESHOLD);
}

/*
 * Interpolate Amplitude
 */
float INTERPOLATE_AMPLITUDE(A, B, X, SIZE) (A a, B b, X x, SIZE size)
{
    return ((a) + ((b) - (a)) * cast(float)(x) / cast(float)(size));
}

/*
 * dB
 */
float dB2rap(DB) (DB dB)    {
    return (exp((dB) * LOG_10 / 20.0f));
}
float rap2dB(RAP) (RAP rap) {
    return (20 * logf(rap) / LOG_10);
}

// todo: remove, we can use arr[] = 0.
void ZERO(DATA, SIZE)(ref DATA data, SIZE size)
{
    byte* data_ = cast(byte*)data;

    for (int i = 0; i < size; i++)
        data_[i] = 0;
}

// todo: remove, we can use arr[] = 0.0
void ZERO_float(DATA, SIZE)(ref DATA data, SIZE size)
{
    float* data_ = cast(float*)data;

    for (int i = 0; i < size; i++)
        data_[i] = 0.0f;
}

enum ONOFFTYPE
{
    OFF,
    ON,
}


enum MidiControllers
{
    C_bankselectmsb,
    C_pitchwheel    = 1000,
    C_NULL          = 1001,
    C_expression    = 11,
    C_panning       = 10,
    C_bankselectlsb = 32,
    C_filtercutoff  = 74,
    C_filterq       = 71,
    C_bandwidth     = 75,
    C_modwheel      = 1,
    C_fmamp         = 76,
    C_volume        = 7,
    C_sustain       = 64,
    C_allnotesoff   = 123,
    C_allsoundsoff  = 120,
    C_resetallcontrollers,
    C_portamento          = 65,
    C_resonance_center    = 77,
    C_resonance_bandwidth = 78,
    C_dataentryhi         = 6,
    C_dataentrylo         = 38,
    C_nrpnhi              = 99,
    C_nrpnlo              = 98,
}


enum LegatoMsg
{
    LM_Norm,
    LM_FadeIn,
    LM_FadeOut,
    LM_CatchUp,
    LM_ToNorm,
}


// is like i=(int)(floor(f))
// todo: see if we can use inline asm
version (none)
{
    /+ #ifdef ASM_F2I_YES
       #define F2I(f, \
                i) __asm__ __volatile__ ("fistpl %0" : "=m" (i) : "t" (f \
                                                                       - \
                                                                       0.49999999f) \
                                         : "st"); +/
}
else
{
    void F2I(F, I)(ref F f, ref I i)
    {
        i = ((f > 0) ? (cast(int)(f)) : (cast(int)(f - 1.0f)));
    }
}

enum O_BINARY = 0;

// temporary include for synth->{samplerate/buffersize} members
class SYNTH_T
{
    this()
    {
        alias_();
    }

    /**Sampling rate*/
    uint samplerate = 44100;

    /**
     * The size of a sound buffer (or the granularity)
     * All internal transfer of sound data use buffer of this size
     * All parameters are constant during this period of time, exception
     * some parameters(like amplitudes) which are linear interpolated.
     * If you increase this you'll ecounter big latencies, but if you
     * decrease this the CPU requirements gets high.
     */
    // todo: was int, check if calling code has issues with size_t
    size_t buffersize = 256;

    /**
     * The size of ADnote Oscillator
     * Decrease this => poor quality
     * Increase this => CPU requirements gets high (only at start of the note)
     */
    // todo: was int, check if calling code has issues with size_t
    size_t oscilsize = 1024;

    // Alias for above terms
    // todo: remove, it's unecessary bookkeeping, use casts in client code instead
    sizef_t samplerate_f;
    sizef_t halfsamplerate_f;
    sizef_t buffersize_f;
    sizef_t oscilsize_f;

    // todo: was int, check if calling code has issues with size_t
    size_t bufferbytes;

    void alias_()
    {
        halfsamplerate_f = (samplerate_f = samplerate) / 2.0f;
        buffersize_f     = buffersize;
        bufferbytes      = buffersize * float.sizeof;
        oscilsize_f      = oscilsize;
    }

    // todo: see if this is extern
    //~ float numRandom() const;  // defined in Util.cpp for now
    float numRandom() { return uniform(0.0, 1.0); }
}


// todo: was extern, and pointer
export SYNTH_T synth;
