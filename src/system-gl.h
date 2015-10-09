#pragma once

#if !defined(NULLGL) && !defined(OSMESA)
#include <GL/glew.h>
#ifdef __APPLE__
 #include <OpenGL/OpenGL.h>
#else
 #include <GL/gl.h>
 #include <GL/glu.h>
#endif


#elif defined(NULLGL)
#define GLint int
#define GLuint unsigned int
inline void glColor4fv( float *c ) {}


#elif defined(OSMESA)
// we need some functions from glext.h
#define GL_GLEXT_PROTOTYPES 
#include <GL/osmesa.h>
//#include <GL/glext.h> already included by osmesa.h
// note that the glu included here has to be compiled specifically for OSMESA. 
#include <GL/glu.h>
//#include <GL/glew.h>
#define GLEW_OK 0
#define glewInit(x) GLEW_OK
#define glewGetString(x) "OSMesa: glew not enabled"
#define glewIsSupported(x) true
#define glewGetErrorString(x) "OSMesa: glew not enabled"

#endif // NULLGL / OSMESA


#include <string>

std::string glew_dump();
std::string glew_extensions_dump();
bool report_glerror(const char * function);
