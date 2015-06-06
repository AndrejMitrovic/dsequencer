module zynd.dsp.svfilter;

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
import std.exception;
import std.string;

import zynd.globals;
import zynd.dsp.filter;
import zynd.misc.array;

class SVFilter : Filter
{
public:

    this(ubyte Ftype, float Ffreq, float Fq, ubyte Fstages)
    {
        type = Ftype;
        freq = Ffreq;
        q = Fq;
        stages = min(MAX_FILTER_STAGES, Fstages);
        needsinterpolation = false;
        firsttime = true;

        outgain = 1.0f;
        cleanup();
        setfreq_and_q(Ffreq, Fq);
    }

    override void filterout(float[] smp)
    {
        foreach (ref stage; st)
            singlefilterout(smp, stage, par);

        if (needsinterpolation)
        {
            auto tmp = regionInitArray!(float[])(smp, smp.length);
            auto ismp = tmp.arr;

            for (int i = 0; i < stages + 1; ++i)
                singlefilterout(ismp, st[i], ipar);

            for (int i = 0; i < synth.buffersize; ++i)
            {
                float x = i / synth.buffersize_f;
                smp[i] = ismp[i] * (1.0f - x) + smp[i] * x;
            }

            needsinterpolation = false;
        }

        foreach (ref sample; smp)
            sample *= outgain;
    }

    float getfreq()
    {
        return freq;
    }

    override void setfreq(float frequency)
    {
        frequency = max(0.1f, frequency);
        float rap = freq / frequency;

        if (rap < 1.0f)
            rap = 1.0f / rap;

        oldabovenq = abovenq;
        abovenq    = frequency > (synth.samplerate_f / 2 - 500.0f);

        bool nyquistthresh = (abovenq ^ oldabovenq);

        // todo: verify that our allocators work ok under pressure when interpolating
        // if the frequency is changed fast, it needs interpolation
        if ((rap > 3.0f) || nyquistthresh)   // (now, filter and coeficients backup)
        {
            if (!firsttime)
                needsinterpolation = true;

            ipar = par;
        }

        freq = frequency;
        computefiltercoefs();
        firsttime = false;
    }

    override void setfreq_and_q(float frequency, float q_)
    {
        q = q_;
        setfreq(frequency);
    }

    override void setq(float q_)
    {
        q = q_;
        computefiltercoefs();
    }

    override void setgain(float dBgain)
    {
        gain = dB2rap(dBgain);
        computefiltercoefs();
    }

    int gettype()
    {
        return type;
    }

    void settype(int type_)
    {
        type = type_;
        computefiltercoefs();
    }

    void setstages(int stages_)
    {
        if (stages_ >= MAX_FILTER_STAGES)
            stages_ = MAX_FILTER_STAGES - 1;

        stages = stages_;
        cleanup();
        computefiltercoefs();
    }

    void cleanup()
    {
        foreach (ref stage; st)
        {
            stage.low = 0.0;
            stage.high = 0.0;
            stage.band = 0.0;
            stage.notch = 0.0;
        }

        oldabovenq = false;
        abovenq    = false;
    }

private:

    struct fstage
    {
        float low   = 0.0;
        float high  = 0.0;
        float band  = 0.0;
        float notch = 0.0;
    }

    fstage[MAX_FILTER_STAGES + 1] st;

    struct parameters
    {
        float f, q, q_sqrt;
    }

    parameters par;
    parameters ipar;

    void singlefilterout(float[] smp, ref fstage x, ref parameters par)
    {
        float* _out;  // todo perf: init with void

        switch (type)
        {
            case 0:
                _out = &x.low;
                break;

            case 1:
                _out = &x.high;
                break;

            case 2:
                _out = &x.band;
                break;

            case 3:
                _out = &x.notch;
                break;

            default:
                enforce(0, format("Impossible SVFilter type encountered [%s]", type));
        }

        assert(smp.length >= synth.buffersize);

        foreach (i; 0 .. synth.buffersize)
        {
            x.low   = x.low + par.f * x.band;
            x.high  = par.q_sqrt * smp[i] - x.low - par.q * x.band;
            x.band  = par.f * x.high + x.band;
            x.notch = x.high + x.low;
            smp[i]  = *_out;
        }
    }

    void computefiltercoefs()
    {
        par.f      = min(0.99999f, freq / synth.samplerate_f * 4.0f);
        par.q      = 1.0f - atan(sqrt(q)) * 2.0f / PI;
        par.q      = pow(par.q, 1.0f / (stages + 1));
        par.q_sqrt = sqrt(par.q);
    }

    // todo: replace with enum, replace switches with final switches
    int type;          // The type of the filter (LPF1,HPF1,LPF2,HPF2...)

    int stages;        // how many times the filter is applied (0->1,1->2,etc.)
    float freq = 0.0;  // Frequency given in Hz
    float q = 0.0;     // Q factor (resonance or Q factor)
    float gain = 1.0;  // the gain of the filter (if are shelf/peak) filters

    bool abovenq;   // if the frequency is above the nyquist
    bool oldabovenq;
    bool needsinterpolation, firsttime;
}
