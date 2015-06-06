enum FM_OSCILLATOR = true;

/*
   members are:

   float phase;
   int TableSize;
   float sampleRate;

   float *table, dtable0, dtable1, dtable2, dtable3;

   ->these should be filled as folows... (remember to wrap around)
   table[i] = the wave-shape
   dtable0[i] = table[i+1] - table[i];
   dtable1[i] = (3.f*(table[i]-table[i+1])-table[i-1]+table[i+2])/2.f
   dtable2[i] = 2.f*table[i+1]+table[i-1]-(5.f*table[i]+table[i+2])/2.f
   dtable3[i] = (table[i+1]-table[i-1])/2.f
 */

float UpdateWithoutInterpolation(float frequency)
{
    int i = cast(int)phase;

    phase += (sampleRate / (float TableSize) / frequency;
    
    if (phase >= cast(float)TableSize)
        phase -= cast(float)TableSize;

    static if (FM_OSCILLATOR)
    {
        if (phase < 0.f)
            phase += cast(float)TableSize;
    }

    return table[i];
}

float UpdateWithLinearInterpolation(float frequency)
{
    int i = cast(int)phase;
    float alpha = phase - cast(float)i;

    phase += (sampleRate / cast(float)TableSize) / frequency;

    if (phase >= cast(float)TableSize)
      phase -= cast(float)TableSize;

    static if (FM_OSCILLATOR)
    {    
        if (phase < 0.f)
            phase += cast(float)TableSize;
    }

    /*
     dtable0[i] = table[i+1] - table[i]; //remember to wrap around!!!
    */

    return table[i] + dtable0[i] * alpha;
}

float UpdateWithCubicInterpolation(float frequency)
{
    int i = cast(int)phase;
    float alpha = phase - cast(float)i;

    phase += (sampleRate / cast(float)TableSize) / frequency;

    if (phase >= cast(float)TableSize)
      phase -= cast(float)TableSize;

    static if (FM_OSCILLATOR)
    {    
        if (phase < 0.f)
            phase += cast(float)TableSize;
    }

    /* //remember to wrap around
     dtable1[i] = (3.f*(table[i]-table[i+1])-table[i-1]+table[i+2])/2.f
     dtable2[i] = 2.f*table[i+1]+table[i-1]-(5.f*table[i]+table[i+2])/2.f
     dtable3[i] = (table[i+1]-table[i-1])/2.f
    */

    return ((dtable1[i] * alpha + dtable2[i]) * alpha + dtable3[i]) * alpha + table[i];
}
