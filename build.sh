CAIROD_SRC="lib/cairoD/src"
CAIRO_IMPLIB="libcairo-2.lib"
CAIROD_FLAGS="-version=CAIRO_HAS_PS_SURFACE -version=CAIRO_HAS_PDF_SURFACE -version=CAIRO_HAS_SVG_SURFACE -version=CAIRO_HAS_WIN32_SURFACE -version=CAIRO_HAS_PNG_FUNCTIONS -version=CAIRO_HAS_WIN32_FONT -version=WindowsAPI"

PA_SRC="lib/DPortAudio"
PA_IMPLIB="portaudio_x86_implib.lib"

PM_SRC="lib/DPortMidi/src"
PM_IMPLIB="portmidi_implib.lib"

WIN_SRC="lib/WindowsAPI"
WIN_FLAGS="-version=Unicode -version=WindowsXP"

ZYND_SRC="lib"

SEQ_FLAGS="-version=AudioEngine"

rdmd --build-only -I$WIN_SRC -I$CAIROD_SRC -d -g -w -wi -J. -ofbin/sequencer -I$CAIROD_SRC -L-l$CAIRO_IMPLIB $CAIROD_FLAGS -I$PA_SRC -L-l$PA_IMPLIB -I$PM_SRC -L-l$PM_IMPLIB $SEQ_FLAGS -I$ZYND_SRC sequencer.d
