module zynd.dsp.unison;

/*
   ZynAddSubFX - a software synthesizer

   Filter.h - Filters, uses analog,formant,etc. filters
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

import std.math;
import std.algorithm;
import std.range;

// todo: remove once RND implemented
import std.random;

import zynd.globals;
import zynd.misc.array;

// how much the unison frequencies varies (always >= 1.0)
enum UNISON_FREQ_SPAN = 2.0f;

class Unison
{
public:

    this(int update_period_samples_, float max_delay_sec_)
    {
        update_period_samples = update_period_samples_;
        max_delay    = max(10, cast(int)(synth.samplerate_f * max_delay_sec_) + 1);
        delay_buffer = initializedArray!(float[])(0.0f, max_delay);
        setSize(1);
    }

    void setSize(size_t new_size)
    {
        new_size    = max(1, new_size);
        unison_size = new_size;
        voices      = new UnisonVoice[unison_size];
        first_time  = true; // todo: verify semantics
        updateParameters();
    }

    // todo: replace with property
    void setBaseFrequency(float freq)
    {
        base_freq = freq;
        updateParameters();
    }

    // todo: replace with property
    void setBandwidth(float bandwidth)
    {
        bandwidth = max(0.0f, min(1200.0f, bandwidth));

        //~ #warning : todo: if bandwidth is too small the audio will be self canceled (because of the sign change of the outputs)
        unison_bandwidth_cents = bandwidth;
        updateParameters();
    }

    void process(int bufsize, float[] inbuf, float[] outbuf = null)
    {
        if (!voices.length)  // todo: return possibly unsafe
            return;

        if (outbuf is null)  // todo: check semantics
            outbuf = inbuf;

        float volume    = 1.0f / sqrt(cast(float)unison_size);
        float xpos_step = 1.0f / cast(float)update_period_samples;
        float xpos      = cast(float)update_period_sample_k * xpos_step;

        foreach (index, inSample, ref outSample; lockstep(inbuf, outbuf))
        {
            if (update_period_sample_k++ >= update_period_samples)
            {
                updateUnisonData();
                update_period_sample_k = 0;
                xpos = 0.0f;
            }

            xpos += xpos_step;
            float _out = 0.0f;
            float sign = 1.0f;

            foreach (voice; voices)
            {
                float vpos = voice.realpos1 * (1.0f - xpos) + voice.realpos2 * xpos;  // optimize
                float pos  = cast(float)(delay_k + max_delay) - vpos - 1.0f;
                int posi;
                F2I(pos, posi);  // optimize!

                if (posi >= max_delay)
                    posi -= max_delay;

                float posf = pos - floor(pos);
                _out +=
                    ((1.0f
                      - posf) * delay_buffer[posi] + posf
                     * delay_buffer[posi + 1]) * sign;
                sign = -sign;
            }

            outSample = _out * volume;

            //~ writefln("%s %s", index, outSample);
            delay_buffer[delay_k] = inSample;
            delay_k = (++delay_k < max_delay) ? delay_k : 0;
        }
    }

private:

    void updateParameters()
    {
        if (!voices.length)  // todo: return possibly unsafe
            return;

        float increments_per_second = synth.samplerate_f / cast(float)update_period_samples;

        //~ writefln("#%s, %s", increments_per_second, base_freq);
        foreach (ref voice; voices)
        {
            float base = pow(UNISON_FREQ_SPAN, synth.numRandom() * 2.0f - 1.0f);
            voice.relative_amplitude = base;
            float period = base / base_freq;
            float m      = 4.0f / (period * increments_per_second);

            if (synth.numRandom() < 0.5f)
                m = -m;

            voice.step = m;

            //~ writefln("%s %s", voice.relative_amplitude, period);
        }

        float max_speed = pow(2.0f, unison_bandwidth_cents / 1200.0f);
        unison_amplitude_samples = 0.125f * (max_speed - 1.0f)
                                   * synth.samplerate_f / base_freq;

        //~ #warning todo: test if unison_amplitude_samples is too big and reallocate bigger memory

        // todo: verify semantics
        if (unison_amplitude_samples >= max_delay - 1)
            unison_amplitude_samples = max_delay - 2;

        updateUnisonData();
    }

    void updateUnisonData()
    {
        if (!voices.length)  // todo: return possibly unsafe
            return;

        foreach (ref voice; voices)
        {
            float pos  = voice.position;
            float step = voice.step;
            pos += step;

            if (pos <= -1.0f)
            {
                pos  = -1.0f;
                step = -step;
            }
            else if (pos >= 1.0f)
            {
                pos  = 1.0f;
                step = -step;
            }

            // make the vibratto lfo smoother
            float vibratto_val = (pos - 0.333333333f * pos * pos * pos) * 1.5f;

            //~ #warning I will use relative amplitude, so the delay might be bigger than the whole buffer
            //~ #warning I have to enlarge (reallocate) the buffer to make place for the whole delay
            float newval = 1.0f + 0.5f
                           * (vibratto_val + 1.0f) * unison_amplitude_samples
                           * voice.relative_amplitude;

            if (first_time)
                voice.realpos1 = voice.realpos2 = newval;
            else
            {
                voice.realpos1 = voice.realpos2;
                voice.realpos2 = newval;
            }

            voice.position = pos;
            voice.step     = step;
        }

        first_time = false;
    }

    float base_freq = 1.0;

    // todo: verify, was struct
    class UnisonVoice
    {
        float step;         // base LFO
        float position;
        float realpos1;     // the position regarding samples
        float realpos2;
        float relative_amplitude;
        float lin_fpos;
        float lin_ffreq;

        this()
        {
            // todo: use RND once implemented
            version (none)
                position = RND * 1.8f - 0.9f;
            else
                position = uniform(0.0, 1.0) * 1.8f - 0.9f;

            realpos1 = 0.0f;
            realpos2 = 0.0f;
            step     = 0.0f;
            relative_amplitude = 1.0f;
        }
    }

    UnisonVoice[] voices; // todo: verify, was struct*
    int unison_size = 0;  // todo: remove, voices has .length

    int  update_period_samples;
    int  update_period_sample_k = 0;
    int  max_delay;
    int  delay_k    = 0;
    bool first_time = false;
    float[] delay_buffer;
    float unison_amplitude_samples = 0.0;
    float unison_bandwidth_cents   = 10.0;
}
