module zynd.dsp.filter;
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

import zynd.globals;

// todo: enable once implemented
version (none)
{
    import zynd.dsp.analogfilter;
    import zynd.dsp.formantfilter;
    import zynd.dsp.svfilter;
    import zynd.params.filterparams;
    
}

abstract class Filter
{
public:
    
    static float getrealfreq(float freqpitch)
    {
        return pow(2.0f, freqpitch + 9.96578428f); // log2(1000)=9.95748f
    }
    
    // todo: enable once zynd.dsp.* is implemented
    version(none) static Filter generate(FilterParams pars)
    {
        ubyte Ftype   = pars.Ptype;
        ubyte Fstages = pars.Pstages;

        Filter filter;

        switch (pars.Pcategory)
        {
            case 1:
                filter = new FormantFilter(pars);
                break;

            case 2:
                filter = new SVFilter(Ftype, 1000.0f, pars.getq(), Fstages);
                filter.outgain = dB2rap(pars.getgain());

                if (filter.outgain > 1.0f)
                    filter.outgain = sqrt(filter.outgain);

                break;

            default:
                filter = new AnalogFilter(Ftype, 1000.0f, pars.getq(), Fstages);

                if ((Ftype >= 6) && (Ftype <= 8))
                    filter.setgain(pars.getgain());
                else
                    filter.outgain = dB2rap(pars.getgain());

                break;
        }

        return filter;
    }

    /* virtual */ void filterout(float[] smp);
    /* virtual */ void setfreq(float frequency);
    /* virtual */ void setfreq_and_q(float frequency, float q_);
    /* virtual */ void setq(float q_);
    /* virtual */ void setgain(float dBgain);

protected:
    float outgain = 0.0;
}
