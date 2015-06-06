/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/

module portaudio.exception;

import std.exception;
import std.conv : to;

import portaudio.portaudio;

/+ 
 + Exception which retrieves an error message when throw.
 + 
 + Usage:
 + auto error = PaFunction();
 + enforce(error >= PaErrorCode.paNoError, new PortaudioException(error));
 +/
class PortaudioException : Exception
{
    this(int error)
    {
        super(to!string(Pa_GetErrorText(error)));
    }
    
    this(string msg)
    {
        super(msg);
    }
}
