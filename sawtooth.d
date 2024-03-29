/* Bandlimited synthesis of sawtooth by
 * leaky integration of a DSF BLIT
 *
 * Emanuel Landeholm, March 2002
 * emanuel.landeholm@telia.com
 *
 * Provided \"as is\".
 * Free as in Ef Are Ee Ee.
 */
module sawtooth;

import std.math;
double twopi = 6.2831853071795864769252867665590058L;

/* Leaky integrator/first order lowpass which
 * shapes the impulse train into a nice
 * -6dB/octave spectrum
 *
 * The cutoff frequency needs to be pretty lowish
 * or the sawtooth will suffer phase distortion
 * at the low end.
 */

struct Lowpass
{
    double x1, y1;
    double a, b;
}

/* initializes a lowpass, sets cutoff/leakiness */
void init_lowpass(ref Lowpass lp, double cutoff)
{
    double Omega;

    lp.x1 = lp.y1 = 0.0;

    Omega = atan(PI * cutoff);
    lp.a = -(1.0 - Omega) / (1.0 + Omega);
    
    if (isNaN(lp.b))
        lp.b = 0.0f;
    
    lp.b = (1.0 - lp.b) / 2.0;
}

double update_lowpass(ref Lowpass lp, double x)
{
    double y;

    y = lp.b * (x + lp.x1) - lp.a * lp.y1;

    lp.x1 = x;
    lp.y1 = y;

    return y;
}

struct Blit
{
    double phase;  /* phase accumulator */
    double aNQ;    /* attenuation at nyquist */
    double curcps; /* current frequency, updated once per cycle */
    double curper; /* current period, updated once per cycle */
    Lowpass leaky; /* leaky integrator */
    double N;      /* # partials */
    double a;      /* dsf parameter which controls roll-off */
    double aN;     /* former to the N */
}

/* initializes a blit structure
 *
 * The aNQ parameter is the desired attenuation
 * at nyquist. A low value yields a duller
 * sawtooth but gets rid of annoying clicks
 * when sweeping the frequency very high. 
 * |aNQ| must be less than 1.0.
 *
 * The cutoff parameter controls the leakiness of
 * the integrator.
 */
void init_blit(ref Blit b, double aNQ, double cutoff)
{
    assert(aNQ < 1.0f);
    
    b.phase  = 0.0;
    b.aNQ    = aNQ;
    b.curcps = 0.0;
    b.curper = 0.0;
    init_lowpass(b.leaky, cutoff);
}

/* Returns a sawtooth computed from a leaky integration
 * of a DSF bandlimited impulse train.
 *
 * cps (cycles per sample) is the fundamental
 * frequency: 0 . 0.5 == 0 . nyquist
 */
double update_blit(ref Blit b, double cps)
{
    double P2, beta, Nbeta, cosbeta, n, d, blit, saw;

    if (b.phase >= 1.0 || b.curcps == 0.0)
    {
        /* New cycle, update frequency and everything
         * that depends on it
         */

        if (b.phase >= 1.0)
            b.phase -= 1.0;

        b.curcps = cps;      /* this cycle\'s frequency */
        b.curper = 1.0 / cps; /* this cycle\'s period */

        P2   = b.curper / 2.0;
        b.N = 1.0 + floor(P2); /* # of partials incl. dc */

        /* find the roll-off parameter which gives
         * the desired attenuation at nyquist
         */

        b.a  = pow(b.aNQ, 1.0 / P2);
        b.aN = pow(b.a,   b.N);
    }

    beta = twopi * b.phase;

    Nbeta   = b.N * beta;
    cosbeta = cos(beta);

    /* The dsf blit is scaled by 1 / period to give approximately the same
     * peak-to-peak over a wide range of frequencies.
     */

    n = 1.0 - b.aN * cos(Nbeta) -
        b.a * (cosbeta - b.aN * cos(Nbeta - beta));
    
    d = b.curper * (1.0 + b.a * (-2.0 * cosbeta + b.a));
    
    b.phase += b.curcps; /* update phase */
    blit = n / d - b.curcps; /* This division can only fail if |a| == 1.0
                               * Subtracting the fundamental frq rids of DC
                               */

    

    saw = update_lowpass(b.leaky, blit); /* shape blit spectrum into a saw */
    return saw;
}

static int clipped = 0;

double ADC_out(double x)
{
    if (x > 1.0)
    {
        ++clipped;
        x = 1.0;
    }
    else if (x < -1.0)
    {
        ++clipped;
        x = -1.0;
    }

    return x;
}

//~ void main()
//~ {
    //~ int i;
    //~ double cps, cm;
    //~ Blit b;

    //~ enum L = 1000;

    //~ init_blit(b, 0.5, 0.0001);

    //~ /* sweep from 40 to 20000 Hz */

    //~ cps = 40.0 / 44100.0;
    //~ cm  = pow(500.0, 1.0 / cast(double)L);

    //~ double[L] output = 1000;
    //~ foreach (index, ref sample; output)
    //~ {
        //~ output[index] = ADC_out(2.0 * update_blit(b, cps));
        //~ cps *= cm;
    //~ }

    //~ echo(output);
//~ }
