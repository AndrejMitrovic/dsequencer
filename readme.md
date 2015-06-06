# dsequencer

![DSequencer](https://raw.github.com/drey08/dsequencer/master/dsequencer.png)

This was an experiment implementing a simple D sequencer.

It uses: PortAudio, PortMidi, and Cairo.

**Note: Only buildable on win32.**

## Keyboard and Mouse controls

- Use the mouse Left / Right buttons to activate / deactivate each step.

- Use the `R` key to randomly generate a pattern.

- Use the `S` key to toggle the sine synth on / off.

- Use the `F` key to toggle the FM synth on / off.

- Use Up / Down to change the Filter frequency.

- Use Left / Right to change the Filter type.

## Warning

Keep your volume low and take care of your ears and your hardware.

## Disclaimer

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

## Requirements

DMD v2.066.1

Everything is included in `/bin`.

Typically you would need to install the GTK+ runtime which includes the
Cairo DLLs and a bunch of other dependencies. But it doesn't include the
PortAudio / PortMidi DLLs.

## Building and Running

Run or double-click `build.bat`.

## License

Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_1_0.txt or copy [here][BoostLicense].

[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt
