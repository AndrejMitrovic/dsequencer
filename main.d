/*
 *             Copyright Andrej Mitrovic 2018.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module main;

version (Windows)
    import winmain;
else version (Linux)
    import linuxmain;
