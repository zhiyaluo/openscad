/*

Alternate version of OffscreenContextGLX.cc for getting an OpenGL context
on POSIX systems where the standard OffscreenContextGLX.cc doesn't work

See also

glxdemo.c and glxgears.c by Brian Paul from mesa-demos (mesa3d.org)
http://cgit.freedesktop.org/mesa/demos/tree/src/xdemos?id=mesa-demos-8.0.1
http://www.opengl.org/sdk/docs/man/xhtml/glXIntro.xml
http://www.mesa3d.org/brianp/sig97/offscrn.htm
http://glprogramming.com/blue/ch07.html
OffscreenContext.mm (Mac OSX version)

*/

/*
 * Some portions of the code below are:
 * Copyright (C) 1999-2001  Brian Paul   All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * BRIAN PAUL BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 * AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include "OffscreenContext.h"
#include "printutils.h"
#include "imageutils.h"
#include "system-gl.h"
#include "fbo.h"

#include <GL/gl.h>
#include <GL/glx.h>

#include <assert.h>
#include <sstream>

#include <sys/utsname.h> // for uname

using namespace std;

struct OffscreenContext
{
	GLXContext openGLContext;
	Display *xdisplay;
	Window xwindow;
	int width;
	int height;
	fbo_t *fbo;
};

#include "OffscreenContextAll.hpp"

void offscreen_context_init(OffscreenContext &ctx, int width, int height)
{
	PRINTD("offscreen ctx init");
	ctx.width = width;
	ctx.height = height;
	ctx.openGLContext = NULL;
	ctx.xdisplay = NULL;
	ctx.xwindow = (Window)NULL;
	ctx.fbo = NULL;
}

string get_os_info()
{
	struct utsname u;
	stringstream out;

	if (uname(&u) < 0)
		out << "OS info: unknown, uname() error\n";
	else {
		out << "OS info: "
		    << u.sysname << " "
		    << u.release << " "
		    << u.version << "\n";
		out << "Machine: " << u.machine;
	}
	return out.str();
}

string offscreen_context_getinfo(OffscreenContext *ctx)
{
	PRINTD("offscreen context info");
	assert(ctx);

	if (!ctx->xdisplay)
		return string("No GL Context initialized. No information to report\n");

	int major, minor;
	glXQueryVersion(ctx->xdisplay, &major, &minor);

	stringstream out;
	out << "GL context creator: GLX\n"
	    << "PNG generator: lodepng\n"
	    << "GLX version: " << major << "." << minor << "\n"
	    << get_os_info();

	return out.str();
}

static XErrorHandler original_xlib_handler = (XErrorHandler) NULL;
static bool XCreateWindow_failed = false;
static int XCreateWindow_error(Display *dpy, XErrorEvent *event)
{
	cerr << "XCreateWindow failed: XID: " << event->resourceid
	     << " request: " << (int)event->request_code
	     << " minor: " << (int)event->minor_code << "\n";
	char description[1024];
	XGetErrorText( dpy, event->error_code, description, 1023 );
	cerr << " error message: " << description << "\n";
	XCreateWindow_failed = true;
	return 0;
}

bool create_glx_dummy_window(OffscreenContext &ctx)
{
	PRINTD("create glx dummy window");
/*
   create a dummy X window without showing it. (without 'mapping' it)
   and save information to the ctx.

   This function will alter ctx.openGLContext and ctx.xwindow if successfull
 */

/*	int attributes[] = {
		GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT | GLX_PIXMAP_BIT | GLX_PBUFFER_BIT, //support all 3, for OpenCSG
		GLX_RENDER_TYPE,   GLX_RGBA_BIT,
		GLX_RED_SIZE, 8,
		GLX_GREEN_SIZE, 8,
		GLX_BLUE_SIZE, 8,
		GLX_ALPHA_SIZE, 8,
		GLX_DEPTH_SIZE, 24, // depth-stencil for OpenCSG
		GLX_STENCIL_SIZE, 8,
		GLX_DOUBLEBUFFER, True,
		None
	};

*/


	int attribs[64];
	int i=0;
   /* Singleton attributes. */
   attribs[i++] = GLX_RGBA;
   attribs[i++] = GLX_DOUBLEBUFFER;

   /* Key/value attributes. */
   attribs[i++] = GLX_RED_SIZE;
   attribs[i++] = 1;
   attribs[i++] = GLX_GREEN_SIZE;
   attribs[i++] = 1;
   attribs[i++] = GLX_BLUE_SIZE;
   attribs[i++] = 1;
   attribs[i++] = GLX_DEPTH_SIZE;
   attribs[i++] = 1;

   attribs[i++] = None;



	int scrnum;
	XSetWindowAttributes attr;
	unsigned long mask;
	Window root;
	Window xWin;
	XVisualInfo *visinfo;
	Display *dpy = ctx.xdisplay;

	scrnum = DefaultScreen( dpy );
	root = RootWindow( dpy, scrnum );
	PRINTDB("dpy %i",dpy);
	PRINTDB("defaultscreen %i",scrnum);
	PRINTDB("rootwindow %i",root);

	int width = ctx.width;
	int height = ctx.height;

	visinfo = glXChooseVisual( dpy, scrnum, attribs );
	if (!visinfo) {
		cerr << "Error: couldn't get an RGB, Double-buffered visual\n";
		return false;
	}
	
	/* window attributes */
	attr.background_pixel = 0;
	attr.border_pixel = 0;
	attr.colormap = XCreateColormap( dpy, root, visinfo->visual, AllocNone);
	attr.event_mask = StructureNotifyMask | ExposureMask;
	mask = CWBackPixel | CWBorderPixel | CWColormap | CWEventMask;

	original_xlib_handler = XSetErrorHandler( XCreateWindow_error );

	xWin = XCreateWindow( dpy, root, 0, 0, width, height,
                        0, visinfo->depth, InputOutput,
                        visinfo->visual, mask, &attr );

	XSync( dpy, false );
	if ( XCreateWindow_failed ) {
		XFree( visinfo );
		return false;
	}
	XSetErrorHandler( original_xlib_handler );

	GLXContext context = glXCreateContext( dpy, visinfo, NULL, True );
	if ( context == NULL ) {
		cerr << "Error: glXCreateContext failed\n";
		XDestroyWindow( dpy, xWin );
		XFree( visinfo );
		return false;
	}

	// leave out to make offscreen window
 	PRINTD("xmapwindow");
	XMapWindow( dpy, xWin );

	PRINTD("glxmakecurrent");
	if (!glXMakeCurrent( dpy, xWin, context )) {
		cerr << "Error: glXMakeCurrent failed\n";
		glXDestroyContext( dpy, context );
		XDestroyWindow( dpy, xWin );
		XFree( visinfo );
		return false;
	}

	ctx.openGLContext = context;
	ctx.xwindow = xWin;

	XFree( visinfo );

	return true;
}

Bool create_glx_dummy_context(OffscreenContext &ctx);

OffscreenContext *create_offscreen_context(int w, int h)
{
	PRINTD("create offscreen context");
	OffscreenContext *ctx = new OffscreenContext;
	offscreen_context_init( *ctx, w, h );

	// before an FBO can be setup, a GLX context must be created
	// this call alters ctx->xDisplay and ctx->openGLContext 
	//  and ctx->xwindow if successfull
	if (!create_glx_dummy_context( *ctx )) {
		delete ctx;
		return NULL;
	}

	return create_offscreen_context_common( ctx );
}

bool teardown_offscreen_context(OffscreenContext *ctx)
{
	PRINTD("teardown offscreen context");
	if (ctx) {
		fbo_unbind(ctx->fbo);
		fbo_delete(ctx->fbo);
		XDestroyWindow( ctx->xdisplay, ctx->xwindow );
		glXDestroyContext( ctx->xdisplay, ctx->openGLContext );
		XCloseDisplay( ctx->xdisplay );
		return true;
	}
	return false;
}

bool save_framebuffer(OffscreenContext *ctx, std::ostream &output)
{
	PRINTD("save_framebuffer");
	glXSwapBuffers(ctx->xdisplay, ctx->xwindow);
	return save_framebuffer_common(ctx, output);
}

#pragma GCC diagnostic ignored "-Waddress"
Bool create_glx_dummy_context(OffscreenContext &ctx)
{
	PRINTD("create_glx_dummy_context");
	// This will alter ctx.openGLContext and ctx.xdisplay and ctx.xwindow if successfull
	int major;
	int minor;
	Bool result = False;

	PRINTD("xopendisplay");
	ctx.xdisplay = XOpenDisplay( NULL );

	if ( ctx.xdisplay == NULL ) {
		cerr << "Unable to open a connection to the X server\n";
		return False;
	}

	result = create_glx_dummy_window( ctx );

	if (!result) XCloseDisplay( ctx.xdisplay );

	return result;
}

