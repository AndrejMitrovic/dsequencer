/**
 *
 * License:
 * $(BOOKTABLE ,
 *   $(TR $(TD cairoD wrapper/bindings)
 *     $(TD $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)))
 *   $(TR $(TD $(LINK2 http://cgit.freedesktop.org/cairo/tree/COPYING, _cairo))
 *     $(TD $(LINK2 http://cgit.freedesktop.org/cairo/tree/COPYING-LGPL-2.1, LGPL 2.1) /
 *     $(LINK2 http://cgit.freedesktop.org/cairo/plain/COPYING-MPL-1.1, MPL 1.1)))
 * )
 * Authors:
 * $(BOOKTABLE ,
 *   $(TR $(TD Johannes Pfau) $(TD cairoD))
 *   $(TR $(TD Andrej Mitrovic) $(TD cairoD))
 *   $(TR $(TD $(LINK2 http://cairographics.org, _cairo team)) $(TD _cairo))
 * )
 */
/*
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module cairo.c.gl;

import cairo.c.cairo;

version(CAIRO_HAS_GL_SURFACE)
{
    version (Windows)    // uses WGL
    {
        // WindowsAPI and Derelict type definitions might be incompatible with each other.
        version (WindowsAPI)
        {
            // Requires WindowsAPI: http://www.dsource.org/projects/bindings/wiki/WindowsApi
            import win32.windef;
        }
        else version (Derelict)
        {
            // Requires Derelict: http://www.dsource.org/projects/derelict
            import derelict.util.wintypes;
        }
        else
        {
            static assert(false, "Must pass version=WindowsAPI or version=Derelict when building Cario on Windows with GL support.");
        }

        extern (C):
        
        cairo_device_t* cairo_wgl_device_create(HGLRC rc);
        HGLRC cairo_wgl_device_get_context(cairo_device_t* device);
        cairo_surface_t* cairo_gl_surface_create_for_dc(cairo_device_t* device, HDC dc, int width, int height);   
    }
    else version (Posix)  // uses GLX
    {
    }
    else version (OSX)  // uses CGL
    {
    }

    extern (C):

    // Note: I haven't managed to get these two to work, and they're lacking any documentation to figure
    // out how to use them
    
    // cairo_surface_t* cairo_gl_surface_create(cairo_device_t* device,
                                             //~ cairo_content_t content,
                                             //~ int width, 
                                             //~ int height);

    // cairo_surface_t* cairo_gl_surface_create_for_texture(cairo_device_t* abstract_device,
                                                         //~ cairo_content_t content,
                                                         //~ uint tex,
                                                         //~ int width, 
                                                         //~ int height);

    void cairo_gl_surface_set_size(cairo_surface_t* surface, int width, int height);
    int cairo_gl_surface_get_width(cairo_surface_t* abstract_surface);
    int cairo_gl_surface_get_height(cairo_surface_t* abstract_surface);
    void cairo_gl_surface_swapbuffers(cairo_surface_t* surface);
}
