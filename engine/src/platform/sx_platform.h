/* Platform layer: SDL3 window/input/audio + OpenGL 3.3 / WebGL2 renderer.
 * Nothing in here is needed by the headless binary or the unit tests.
 * SPDX-License-Identifier: MIT */
#ifndef SX_PLATFORM_H
#define SX_PLATFORM_H
#include "sx_engine.h"

/* ---- renderer (sx_gl.c) ---- */
int sx_gl_init(void *(*get_proc)(const char *name));
void sx_gl_shutdown(void);
/* Draws all viewports into the low-res target and scales it into the window. */
void sx_gl_draw(sx_render *r, int win_w, int win_h);
/* WebXR: draws each eye straight into the XR layer framebuffer `fb`. */
void sx_gl_draw_xr(sx_render *r, unsigned int fb);
/* RGBA, top row first; caller frees. */
unsigned char *sx_gl_read_pixels(int w, int h);

/* ---- audio (sx_audio.c) ---- */
int sx_audio_init(void);
void sx_audio_shutdown(void);
/* Plays and clears the engine's queued requests (e->audio). */
void sx_audio_flush(sx_engine *e);
#endif
