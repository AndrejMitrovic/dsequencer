/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/

/* Converted to D from pa_asio.h by htod */
module portaudio.pa_asio;

import portaudio.portaudio;
import core.stdc.config;

extern (C):

version (PA_USE_ASIO)
{
    /** Retrieve legal native buffer sizes for the specificed device, in sample frames.

     @param device The global index of the device about which the query is being made.
     @param minBufferSizeFrames A pointer to the location which will receive the minimum buffer size value.
     @param maxBufferSizeFrames A pointer to the location which will receive the maximum buffer size value.
     @param preferredBufferSizeFrames A pointer to the location which will receive the preferred buffer size value.
     @param granularity A pointer to the location which will receive the "granularity". This value determines
     the step size used to compute the legal values between minBufferSizeFrames and maxBufferSizeFrames.
     If granularity is -1 then available buffer size values are powers of two.

     @see ASIOGetBufferSize in the ASIO SDK.

     @note: this function used to be called PaAsio_GetAvailableLatencyValues. There is a
     #define that maps PaAsio_GetAvailableLatencyValues to this function for backwards compatibility.
    */
    PaError PaAsio_GetAvailableBufferSizes( PaDeviceIndex device,
            c_long *minBufferSizeFrames, c_long *maxBufferSizeFrames, c_long *preferredBufferSizeFrames, c_long *granularity );


    /** Backwards compatibility alias for PaAsio_GetAvailableBufferSizes

     @see PaAsio_GetAvailableBufferSizes
    */
    alias PaAsio_GetAvailableLatencyValues PaAsio_GetAvailableBufferSizes;


    /** Display the ASIO control panel for the specified device.

      @param device The global index of the device whose control panel is to be displayed.
      @param systemSpecific On Windows, the calling application's main window handle,
      on Macintosh this value should be zero.
    */
    PaError PaAsio_ShowControlPanel( PaDeviceIndex device, void* systemSpecific );




    /** Retrieve a pointer to a string containing the name of the specified
     input channel. The string is valid until Pa_Terminate is called.

     The string will be no longer than 32 characters including the null terminator.
    */
    PaError PaAsio_GetInputChannelName( PaDeviceIndex device, int channelIndex,
            const char** channelName );

            
    /** Retrieve a pointer to a string containing the name of the specified
     input channel. The string is valid until Pa_Terminate is called.

     The string will be no longer than 32 characters including the null terminator.
    */
    PaError PaAsio_GetOutputChannelName( PaDeviceIndex device, int channelIndex,
            const char** channelName );


    /** Set the sample rate of an open paASIO stream.
     
     @param stream The stream to operate on.
     @param sampleRate The new sample rate. 

     Note that this function may fail if the stream is alredy running and the 
     ASIO driver does not support switching the sample rate of a running stream.

     Returns paIncompatibleStreamHostApi if stream is not a paASIO stream.
    */
    PaError PaAsio_SetStreamSampleRate( PaStream* stream, double sampleRate );

    /* Support for opening only specific channels of an ASIO device.
        If the paAsioUseChannelSelectors flag is set, channelSelectors is a
        pointer to an array of integers specifying the device channels to use.
        When used, the length of the channelSelectors array must match the
        corresponding channelCount parameter to Pa_OpenStream() otherwise a
        crash may result.
        The values in the selectors array must specify channels within the
        range of supported channels for the device or paInvalidChannelCount will
        result.
    */

    enum paAsioUseChannelSelectors = 0x01;

    struct PaAsioStreamInfo
    {
        c_ulong size = PaAsioStreamInfo.sizeof; /**< sizeof(PaAsioStreamInfo) */
        PaHostApiTypeId hostApiType;            /**< paASIO */
        c_ulong _version;                        /**< 1 */
        c_ulong flags;

        /* Support for opening only specific channels of an ASIO device.
            If the paAsioUseChannelSelectors flag is set, channelSelectors is a
            pointer to an array of integers specifying the device channels to use.
            When used, the length of the channelSelectors array must match the
            corresponding channelCount parameter to Pa_OpenStream() otherwise a
            crash may result.
            The values in the selectors array must specify channels within the
            range of supported channels for the device or paInvalidChannelCount will
            result.
        */
        int *channelSelectors;
    }
}


