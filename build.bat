@echo off
setlocal EnableDelayedExpansion

set "CAIROD_SRC=lib\cairoD\src"
set "CAIRO_IMPLIB=libcairo-2.lib"
set "CAIROD_FLAGS=-version=CAIRO_HAS_PS_SURFACE -version=CAIRO_HAS_PDF_SURFACE -version=CAIRO_HAS_SVG_SURFACE -version=CAIRO_HAS_WIN32_SURFACE -version=CAIRO_HAS_PNG_FUNCTIONS -version=CAIRO_HAS_WIN32_FONT -version=WindowsAPI"

set "PA_SRC=lib\DPortAudio"
set "PA_IMPLIB=portaudio_x86_implib.lib"

set "PM_SRC=lib\DPortMidi\src"
set "PM_IMPLIB=portmidi_implib.lib"

set "WIN_SRC=lib\WindowsAPI"
set "WIN_FLAGS=-version=Unicode -version=WindowsXP"

set "ZYND_SRC=lib\"

set "SEQ_FLAGS=-version=AudioEngine"

rdmd --build-only -I%WIN_SRC% -I%CAIROD_SRC% -d -g -w -wi -J%cd% -ofbin\sequencer.exe -I%CAIROD_SRC% %CAIRO_IMPLIB% %CAIROD_FLAGS% -I%PA_SRC% %PA_IMPLIB% -I%PM_SRC% %PM_IMPLIB% -I%WIN_SRC% %WIN_FLAGS% %SEQ_FLAGS% -I%ZYND_SRC% sequencer.d
