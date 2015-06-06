/**
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
module cairo.gl;

import cairo.cairo;
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
            import win32.wingdi;  // for wglCreateContext
        }
        else version (Derelict)
        {
            // Requires Derelict: http://www.dsource.org/projects/derelict
            import derelict.util.wintypes;
            import derelict.opengl.wgl;  // for wglCreateContext
        }
        else
        {
            static assert(false, "Must pass version=WindowsAPI or version=Derelict when building Cario on Windows with GL support.");
        }
    }
    else version (Posix)  // uses GLX
    {
    }
    else version (OSX)  // uses CGL
    {
    }    
    
    import cairo.c.gl;

    public class GLDevice : Device
    {
        this(HGLRC hglrc)
        {
            super(cairo_wgl_device_create(hglrc));
        }
    }
    
    /**
     * OpenGL surface support
     */
    public class GLSurface : Surface
    {
        public:
            /**
             * Create a $(D GLSurface) from an existing $(D cairo_surface_t*).
             * GLSurface is a garbage collected class. It will call $(D cairo_surface_destroy)
             * when it gets collected by the GC or when $(D dispose()) is called.
             *
             * Warning:
             * $(D ptr)'s reference count is not increased by this function!
             * Adjust reference count before calling it if necessary
             *
             * $(RED Only use this if you know what your doing!
             * This function should not be needed for standard cairoD usage.)
             */
            this(cairo_surface_t* ptr)
            {
                super(ptr);
            }

            version (Windows)
            {
                /**
                 * Params:
                 * hdc = the DC to create a surface for
                 * device = OpenGL Device
                 * width = width of the surface, in pixels
                 * height = height of the surface, in pixels
                 */            
                this(GLDevice device, HDC hdc, int width, int height)
                {
                    super(cairo_gl_surface_create_for_dc(device.nativePointer, hdc, width, height));
                }
            }
            else version (Posix)
            {
            }
            else version (OSX)
            {
            }
                
            // todo: try getdevicetype in surface
            
            version (Windows)
            {
                /**
                 * Returns the HGLRC associated with this surface, or
                 * null if none. Also returns null if the surface
                 * is not a GL surface.
                 */
                HGLRC getHGLRC()  // todo: check if correct
                {
                    scope(exit)
                        checkError();          
                    
                    auto device = getDevice();
                    return cairo_wgl_device_get_context(device.nativePointer);
                }
            }
                
            void setSize(int width, int height)
            {
                scope(exit)
                    checkError();                                
                cairo_gl_surface_set_size(this.nativePointer, width, height);
            }
            
            int getWidth()
            {
                scope(exit)
                    checkError();                
                return cairo_gl_surface_get_width(this.nativePointer);                
            }
            
            int getHeight()
            {
                scope(exit)
                    checkError();                
                return cairo_gl_surface_get_height(this.nativePointer);                
            }
            
            void swapBuffers()  // render
            {
                cairo_gl_surface_swapbuffers(this.nativePointer);
            }         
    }
}
