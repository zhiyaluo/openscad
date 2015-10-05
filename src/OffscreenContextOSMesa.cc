/*

Create an OpenGL context using OSMesa library. No X11/WGL/CGL required.

See also

glxgears.c by Brian Paul from mesa-demos (mesa3d.org)
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

#include <GL/osmesa.h>
// gl_wrap.h from mesa-demos osmesa.c is essentially reproduced by system-gl.h
// except this part.
#ifndef GLAPIENTRY
#define GLAPIENTRY
#endif
// end gl_wrap.h

#include "OffscreenContext.h"
#include "printutils.h"
#include "imageutils.h"
#include "system-gl.h"
#include "fbo.h"
#include "PlatformUtils.h"

#define BYTES_PER_PIXEL 4

#include <assert.h>
#include <sstream>
#include <vector>

#include <sys/utsname.h> // for uname

struct OffscreenContext
{
	OSMesaContext osMesaContext;
	std::vector<GLubyte> pixels;
	int width;
	int height;
	fbo_t *fbo;
};

// placement of this include after the struct is very important
#include "OffscreenContextAll.hpp"

void offscreen_context_init(OffscreenContext &ctx, int width, int height)
{
	ctx.width = width;
	ctx.height = height;
	ctx.pixels.resize(width*height*BYTES_PER_PIXEL);
	ctx.osMesaContext = NULL;
	ctx.fbo = NULL;
}

std::string get_os_info()
{
	struct utsname u;
	std::stringstream out;

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

std::string offscreen_context_getinfo(OffscreenContext *ctx)
{
	assert(ctx);

	if (!ctx->osMesaContext)
		return std::string("No GL Context initialized. No information to report\n");

	std::stringstream out;
	out << "GL context creator: OSMesa "
	    << OSMESA_MAJOR_VERSION << "."
	    << OSMESA_MINOR_VERSION << "."
	    << OSMESA_PATCH_VERSION << "\n"
	    << "PNG generator: lodepng\n"
	    << get_os_info();

	return out.str();
}

OffscreenContext *create_offscreen_context(int w, int h)
{
	OffscreenContext *ctx = new OffscreenContext;
	offscreen_context_init( *ctx, w, h );

	PRINTD("Creating OSMesa GL context, before Framebuffer Object FBO");
	GLenum format = OSMESA_RGBA;
	GLint depthBits = 24; // depth-stencil for OpenCSG
	GLint stencilBits = 8;
	GLint accumBits = 8; // ??
	OSMesaContext sharelist = NULL;

	ctx->osMesaContext = OSMesaCreateContextExt( format, depthBits, stencilBits, accumBits, sharelist );
	if (!ctx->osMesaContext) {
		PRINTD("OSMesaCreateContextExt failed");
		delete ctx;
		return NULL;
	}

	GLsizei width = static_cast<GLsizei>(w);
	GLsizei height = static_cast<GLsizei>(h);
	GLenum type = GL_UNSIGNED_BYTE;
	
	if (!OSMesaMakeCurrent( ctx->osMesaContext, ctx->pixels, type, width, height )) {
		PRINTD("OSMesaMakeCurrent failed");
		delete ctx;
		return NULL;
	}

	return create_offscreen_context_common( ctx );
}

bool teardown_offscreen_context(OffscreenContext *ctx)
{
	if (ctx) {
		fbo_unbind(ctx->fbo);
		fbo_delete(ctx->fbo);
		OSMesaDestroyContext( ctx->osMesaContext );
		return true;
	}
	return false;
}

bool save_framebuffer(OffscreenContext *ctx, std::ostream &output)
{
	return save_framebuffer_common(ctx, output);
}

