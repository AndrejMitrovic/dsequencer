module test.vstseq;

import core.memory;
import core.thread;

import std.algorithm;
import std.conv;
import std.datetime;
import std.exception;
import std.math;
import std.stdint;
import std.stdio;
import std.string;
import std.traits;
import std.typetuple;
import std.random;
import std.range;

pragma(lib, "adl.lib");
import adl.string : stringize, normalize;

import libsndfile.libsndfile;
import libsndfile.exception;

import vst.minihost;
import vst.aeffect;
import vst.aeffectx;
import vst.minieditor;

import asio.asioheader;
import asio.asioloader;
import asio.generateAudioTable;

struct DriverInfo 
{ 
    long asioVersion, driverVersion; 
    string name, errorMessage; 
}

struct WorkData
{
    double nanoSeconds, samples, tcSamples;
    long callTime;
    size_t bufferSize;
    ASIOBufferInfo[] buffers;
    ASIOChannelInfo[] channels;
    bool postOutput;
    
   
    // todo: Create int32, int24, int16, double, float, dynamic arrays where only one type is allowed to be used
    // maybe implement a "selectType" type of function that's called in bufferSwitch
}

extern(C) int kbhit();
extern(C) int getch();

// ideally the work thread won't have to use locks to access driver buffers,
// maybe we should set driver as a local for the foreground thread, and set
// buffers and required stuff for the background thread as separate __gshared struct
// driver has to be global because work thread needs access to outputReady() and getSamplePosition()
__gshared AsioDrivers driver;
__gshared WorkData workData;
shared bool engineActive;
enum runTimeSeconds = 20;

//~ static this()
//~ {
    //~ echo.newlines = 1;
    
    // todo: useful options to implement
    //~ //~ echo.logfile = "out.log";
    //~ //~ echo.mode = //~ echoMode.logging;
    //~ //~ echo.step = 10;  // initialize inner counter, print on every 10th invocation
    //~ //~ echo.step;       // can call without number, will initialize to last step mode (internally step(int _step = -1))
    //~ //~ echo.nostep;     // remove skip (internally calls step = 0)
    
    //~ introduce performance functionality
    //~ perf.start
//~ }    

// todo: Hide all of the initialization stuff into asiodrivers class to simplify calling code
// todo: Make this a win32 app and then trap ctrl+c (control break) calls so asio doesn't get stuck.
// todo: need to refactor adl.logger.echo, it slows down compilation considerably
void initializeASIO()
{
    driver = new AsioDrivers();    
    driver.loadDriver(0);   // should be a choice, use userInput!int
    driver.initialize(null);
    scope(exit)
        driver.closeActiveDriver();
    
    auto di = DriverInfo(2, 
                        driver.getDriverVersion(), 
                        stringize(&driver.getDriverName), 
                        stringize(&driver.getErrorMessage));
    //~ echo(di);
    
    int numIn;
    int numOut;
    driver.getChannels(&numIn, &numOut);
    
    struct BufferSize { int minSize, maxSize, preferredSize, granularity; }
    BufferSize bs;
    driver.getBufferSize(&bs.minSize, &bs.maxSize, &bs.preferredSize, &bs.granularity);
    //~ echo(bs);
    
    enum mySampleRate  = 44100.0;
    enum minSampleRate = 0.0;
    enum maxSampleRate = 192000.0;
    
    double sampleRate;
    driver.getSampleRate(&sampleRate);
    
    if (sampleRate <= minSampleRate || sampleRate > maxSampleRate || sampleRate <> mySampleRate)
    {
        if (driver.canSampleRate(mySampleRate) == ASE_OK &&
            driver.setSampleRate(mySampleRate) == ASE_OK)
        {
            sampleRate = mySampleRate;
        }
        else
            throw new Exception("Couldn't find a good sample rate");
    }    
    //~ echo(sampleRate.stringof ~ ": %s", sampleRate);

    /* Create buffers and bind the callbacks */
    auto asioCallbacks = ASIOCallbacks(&bufferSwitch, &sampleRateChanged, &asioMessage, &bufferSwitchTimeInfo);
    
    enum maxInputChannels  = 16;
    enum maxOutputChannels = 16;
    
    auto numInputChannels  = min(numIn, maxInputChannels);
    auto numOutputChannels = min(numOut, maxOutputChannels);
    auto channelCount = numInputChannels + numOutputChannels;
    
    foreach (chanIndex; 0..numInputChannels)
    {
        enum isInput = true;
        workData.buffers  ~= ASIOBufferInfo(isInput, chanIndex);
        workData.channels ~= ASIOChannelInfo(chanIndex, isInput);
    }

    foreach (chanIndex; 0..numOutputChannels)
    {
        enum isInput = false;
        workData.buffers  ~= ASIOBufferInfo(isInput, chanIndex);
        workData.channels ~= ASIOChannelInfo(chanIndex, isInput);
    }
    
    //~ echo.newlines = 0;
    
    //~ //~ echo(bs.granularity);
    
    workData.bufferSize = bs.granularity * 150;
    //~ //~ echo(workData);
    
    //~ workData.bufferSize = to!size_t(bs.maxSize);
	enforce(driver.createBuffers(workData.buffers.ptr, channelCount, workData.bufferSize, &asioCallbacks) == ASE_OK,
            "Failed to create buffers.");
    
    scope(exit)
        driver.disposeBuffers();
    
    // fill channel information
    foreach (buffer, ref channel; lockstep(workData.buffers, workData.channels))
    {
        enforce(driver.getChannelInfo(&channel) == ASE_OK, "Failed to get channel info.");
        
        channel.name.normalize;
        channel.isActive = (channel.name[].strip == "Analog OUT") ? 1 : 0;
        
        struct ASIOChannelLatency { int input, output; }
        ASIOChannelLatency latencies;
        driver.getLatencies(&latencies.input, &latencies.output);
        
        //~ debug //~ echo(channel);
        //~ debug //~ echo(latencies).nl;
    }
    
    engineRun();
}

void engineRun()
{
    enum testRunTime = convert!("seconds", "hnsecs")(runTimeSeconds);
    auto startTime = Clock.currStdTime();
    auto finalTime = startTime + testRunTime;
    
    engineActive = true;
    enforce(driver.start() == ASE_OK, "Unable to start driver.");
    //~ echo("Engine started.");
    writeln("Engine started.");
    scope(exit)
    {
        driver.stop();
        //~ echo("Engine stopped.");
        writeln("Engine stopped.");
    }
    
    long currentTime;
    while (engineActive)
    {
        if (kbhit())
        {
            //~ echo("kbhit");
            writeln("kbhit");
            engineActive = false;
            break;
        }
        
        currentTime = Clock.currStdTime();
        //~ echo(currentTime.stringof ~ ": %s", convert!("hnsecs", "seconds")(currentTime - startTime));
        writefln(currentTime.stringof ~ ": %s", convert!("hnsecs", "seconds")(currentTime - startTime));
        
        if (currentTime >= finalTime)
            break;
        
        Thread.sleep( dur!("seconds")(1) );
    }
}

enum TableSize = 200;
enum StereoPhase = 2;  // each channel will have its own phase
AudioTable!(Saw, float, StereoPhase, TableSize) audioTable;
AudioTable!(Sine, float, StereoPhase, TableSize) sineTable;

// todo: try using dsimcha's new stackAlloc, 
// use perfCounter or stopWatch and see if it makes any difference
void processInt32(int halfIndex)
{
    static float[] inputBuffer;
    if (!inputBuffer.length || inputBuffer.length != workData.bufferSize)
    {
        inputBuffer = new float[](workData.bufferSize);
    }
    inputBuffer[] = 0.0;
    
    // todo: wrap channel info and add the isOutput flag
	foreach (chanIndex, channel, ref buffer; lockstep(workData.channels, workData.buffers))
    if (channel.isActive && !channel.isInput &&
       (channel.channel == 0 || channel.channel == 1))
	{
        int index;
        //~ foreach (ref sample; inputBuffer)  // fill input buffer
        //~ {            
            //~ if (channel.channel == 0)  // left chan
            //~ {                
                //~ sample = audioTable.table[audioTable.phase[0] += 1];
            //~ }
            //~ else if (channel.channel == 1)  // right chan
            //~ {
                //~ sample = audioTable.table[audioTable.phase[1] += 1];             
            //~ }
        //~ }
        
        int[] output = (cast(int*)buffer.buffers[halfIndex])[0..workData.bufferSize];
        
        try
        {
            foreach (inSample, ref outSample; lockstep(inputBuffer, output))
            {
                outSample = to!int((inSample * 0x7FFF_0000) - 0.5f);
            }
        }
        catch (Throwable thr)
        {
            engineActive = false;   // safe exit for floating point exceptions, avoids locking asio drivers
        }
    } 
}

// callback
extern(C) ASIOTime* bufferSwitchTimeInfo(ASIOTime* timeInfo, int halfIndex, ASIOBool processNow)
{	
    if (!engineActive)
        return null;
    
    //~ static int processedSamples = 0;
    
	if (timeInfo.timeInfo.flags & AsioTimeInfoFlags.kSystemTimeValid)
		workData.nanoSeconds = ASIO64toDouble(timeInfo.timeInfo.systemTime);
	else
		workData.nanoSeconds = 0;

	if (timeInfo.timeInfo.flags & AsioTimeInfoFlags.kSamplePositionValid)
		workData.samples = ASIO64toDouble(timeInfo.timeInfo.samplePosition);
	else
		workData.samples = 0;

	if (timeInfo.timeCode.flags & ASIOTimeCodeFlags.kTcValid)
		workData.tcSamples = ASIO64toDouble(timeInfo.timeCode.timeCodeSamples);
	else
		workData.tcSamples = 0;

    // see what we need this for
	//~ workData.callTime = Clock.currStdTime();

	// perform the processing
    
    //~ //~ echo( workData.channels[0].type );
    
    processInt32(halfIndex);
    
    driver.outputReady();
	//~ foreach (ref buffer, channel; lockstep(workData.buffers, workData.channels))
	//~ {
		//~ if (!buffer.isInput)
		//~ {
			//~ switch (channel.type)
			//~ {
                //~ case ASIOSTInt16LSB:
                    //~ break;
                //~ case ASIOSTInt24LSB:		// used for 20 bits as well
                    //~ break;
                //~ case ASIOSTInt32LSB:
                //~ {
                    //~ processInt32(buffer);
                    //~ break;
                //~ }
                //~ case ASIOSTFloat32LSB:		// IEEE 754 32 bit float, as found on Intel x86 architecture
                    //~ //~ echo("float 32bit");
                    //~ break;
                //~ case ASIOSTFloat64LSB: 		// IEEE 754 64 bit double float, as found on Intel x86 architecture
                    //~ //~ echo("double 64bit");
                
                    //~ (cast(double*)(buffer[halfIndex]))[0..bufferSize];
                    //~ break;

                    //~ // these are used for 32 bit data buffer, with different alignment of the data inside
                    //~ // 32 bit PCI bus systems can be more easily used with these
                //~ case ASIOSTInt32LSB16:		// 32 bit data with 18 bit alignment
                //~ case ASIOSTInt32LSB18:		// 32 bit data with 18 bit alignment
                //~ case ASIOSTInt32LSB20:		// 32 bit data with 20 bit alignment
                //~ case ASIOSTInt32LSB24:		// 32 bit data with 24 bit alignment
                    //~ break;

                //~ case ASIOSTInt16MSB:
                    //~ break;
                //~ case ASIOSTInt24MSB:		// used for 20 bits as well
                    //~ break;
                //~ case ASIOSTInt32MSB:
                    //~ break;
                //~ case ASIOSTFloat32MSB:		// IEEE 754 32 bit float, as found on Intel x86 architecture
                    //~ break;
                //~ case ASIOSTFloat64MSB: 		// IEEE 754 64 bit double float, as found on Intel x86 architecture
                    //~ break;

                    //~ // these are used for 32 bit data buffer, with different alignment of the data inside.
                    //~ // 32 bit PCI bus systems can be more easily used with these
                //~ case ASIOSTInt32MSB16:		// 32 bit data with 18 bit alignment
                //~ case ASIOSTInt32MSB18:		// 32 bit data with 18 bit alignment
                //~ case ASIOSTInt32MSB20:		// 32 bit data with 20 bit alignment
                //~ case ASIOSTInt32MSB24:		// 32 bit data with 24 bit alignment
                    //~ break;
                //~ default:
                    //~ break;
			//~ }
		//~ }
	//~ }

    //~ processedSamples += workData.bufferSize;
    //~ //~ echo.log(processedSamples);
    
	return null;
}

// callback
extern(C) void bufferSwitch(int halfIndex, ASIOBool processNow)
{	
 	// processing callback.
	// Beware that this is normally in a seperate thread, hence be sure that you take care
	// about thread synchronization. This is omitted here for simplicity.

	// as this is a "back door" into the bufferSwitchTimeInfo, a timeInfo needs to be created although it will only set the timeInfo.samplePosition and timeInfo.systemTime fields and the according flags
	ASIOTime timeInfo;

	// get the time stamp of the buffer, necessary only if 
	// synchronization to other media is required
	if (driver.getSamplePosition(&timeInfo.timeInfo.samplePosition, &timeInfo.timeInfo.systemTime) == ASE_OK)
	{
		timeInfo.timeInfo.flags = AsioTimeInfoFlags.kSystemTimeValid | AsioTimeInfoFlags.kSamplePositionValid;
	}

	bufferSwitchTimeInfo(&timeInfo, halfIndex, processNow); 
}

// callback
extern(C) void sampleRateChanged(ASIOSampleRate sRate)
{
	// do whatever you need to do if the sample rate changed
	// usually this only happens during external sync.
	// Audio processing is not stopped by the driver, actual sample rate
	// might not have even changed, maybe only the sample rate status of an
	// AES/EBU or S/PDIF digital input at the audio device.
	// You might have to update time/sample related conversion routines, etc.
}

// callback
extern(C) int asioMessage(int selector, int value, void* message, double* opt)
{
 	// currently the parameters "value", "message" and "opt" are not used.
	int ret = 0;
 	switch(selector)
	{
		case kAsioSelectorSupported:
			if(value == kAsioResetRequest
			|| value == kAsioEngineVersion
			|| value == kAsioResyncRequest
			|| value == kAsioLatenciesChanged
			// the following three were added for ASIO 2.0, you don't necessarily have to support them
			|| value == kAsioSupportsTimeInfo
			|| value == kAsioSupportsTimeCode
			|| value == kAsioSupportsInputMonitor)
				ret = 1;
			break;
		case kAsioResetRequest:
			// defer the task and perform the reset of the driver during the next "safe" situation
			// You cannot reset the driver right now, as this code is called from the driver.
			// Reset the driver is done by completely destructing it, e.g. ASIOStop(), ASIODisposeBuffers(), Destruction
			// Afterwards you initialize the driver again.
			engineActive = false;  // In this sample the processing will stop
			ret = 1;
			break;
		case kAsioResyncRequest:
			// This informs the application that the driver encountered some non fatal data loss.
			// It is used for synchronization purposes of different media.
			// Added mainly to work around the Win16Mutex problems in Windows 95/98 with the
			// Windows Multimedia system, which could loose data because the Mutex was hold too int
			// by another thread.
			// However a driver can issue it in other situations.
			ret = 1;
			break;
		case kAsioLatenciesChanged:
			// This will inform the host application that the driver's latencies have changed.
			// It does not mean that the buffer sizes have changed.
			// You might need to update internal delay data.
			ret = 1;
			break;
		case kAsioEngineVersion:
			// return the supported ASIO version of the host application
			// If a host applications does not implement this selector, ASIO 1.0 is assumed
			// by the driver
			ret = 2;
			break;
		case kAsioSupportsTimeInfo:
			// informs the driver wether the asioCallbacks.bufferSwitchTimeInfo() callback
			// is supported.
			// For compatibility with ASIO 1.0 drivers the host application should always support
			// the "old" bufferSwitch method, too.
			ret = 1;
			break;
		case kAsioSupportsTimeCode:
			// informs the driver wether application is interested in time code info.
			// If an application does not need to know about time code, the driver has less work
			// to do.
			ret = 0;
			break;
		default:
			writefln("ASIOMessage switch clause for opcode %s not defined", selector);
            ret = 0;
            break;
	}
	return ret;
}

// TODO: See if it fits this:
//~ void getNanoSeconds (ASIOTimeStamp* ts)
//~ {
	//~ double nanoSeconds = (double)((unsigned long)timeGetTime ()) * 1000000.;
	//~ ts->hi = (unsigned long)(nanoSeconds / twoRaisedTo32);
	//~ ts->lo = (unsigned long)(nanoSeconds - (ts->hi * twoRaisedTo32));
//~ }

version(X86)
{
	double twoRaisedTo32 = 4294967296.0;
	auto ASIO64toDouble(T)(T value)
	{
		return value.lo + value.hi * twoRaisedTo32;
	}
}
else version(X86_64)
{
	auto ASIO64toDouble(T)(T value)
	{
		return value;
	}
}



struct AudioBuffer
{
    float[] buffer;
    RunPhase[] phase;
    
    this(size_t bufferSize, size_t phaseCount)
    {
        buffer = new float[](bufferSize * phaseCount);
        phase.length = phaseCount;
        
        foreach (ref ph; phase)
        {
            ph = RunPhase(bufferSize);
        }
    }    
}

AudioBuffer readAudioFile(string filename)
{
    SF_INFO sfInfo;
    auto sndFile = enforce(sf_open(cast(char*)filename.toStringz, SFM_READ, &sfInfo), 
                           new sndfileException(null, filename));
    scope(exit)
        sf_close(sndFile);

    auto result = AudioBuffer(cast(size_t)sfInfo.frames, sfInfo.channels);
    
    sf_readf_float(sndFile, result.buffer.ptr, sfInfo.frames);
    
    //~ writefln("result: %s %s", result.buffer.length, result.phase.length);
    //~ writeln(result.buffer[200000]);
    
    return result;
}

// todo: we need reset methods for phases, and we also need an allPhaseReset method
// in Buffer template which will call reset on each phase. Also need lower and upper
// limits, a.k.a. loop points.
// also need to somehow deinterleave sndfile buffers. Should this be done via a range?
// maybe turn the audio buffer into a random access input range.
void run()
{
    initializeASIO();
    
    //~ string filename =  r"C:\track.wav";
    
    //~ auto audioBuffer = readAudioFile(filename);
    
    //~ audioBuffer.phase[1] += 1;  // offset right channel due to interleaving
    
    //~ auto inputBuffer = new float[](512);
    //~ bool channel;
    
    //~ while(true)
    //~ {
        //~ channel ^= 1;
        //~ foreach (index, ref sample; inputBuffer)
        //~ {
            //~ sample = audioBuffer.buffer[index];
            
            //~ sample = !channel ? audioBuffer.buffer[audioBuffer.phase[0] += 2]
                              //~ : audioBuffer.buffer[audioBuffer.phase[1] += 2];
        //~ }
        
/+         foreach (sample; inputBuffer)
        {
            writeln(sample);
        } +/
    //~ }
}
