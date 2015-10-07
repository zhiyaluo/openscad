#pragma once

#ifdef NULLGL
#define GLint int
#define GLuint unsigned int
inline void glColor4fv( float *c ) {}


#elif defined(OSMESA)
// we use the glew headers.... but not the glew library functions.
#include <GL/glew.h>
#define GLAPI extern
#include <GL/osmesa.h>
// note that the glu included here has to be compiled specifically for OSMESA. 
#include <GL/glu.h>
void osmesa_glew_noop() {};
#define glewInit(x) osmesa_glew_noop(); 
#define glewGetString(x) "OSMesa: glewGetString"
#define glewIsSupported(x) true


#elif !defined(OSMESA) && !defined(NULLGL)
#include <GL/glew.h>
#ifdef __APPLE__
 #include <OpenGL/OpenGL.h>
#else
 #include <GL/gl.h>
 #include <GL/glu.h>
#endif

#endif // NULLGL / OSMESA

#include <string>

std::string glew_dump();
std::string glew_extensions_dump();
bool report_glerror(const char * function);
