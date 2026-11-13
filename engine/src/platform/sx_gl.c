/* Retro renderer: palette-indexed textures, vertex snapping, fog, ordered
 * dither, a low-res target scaled up with nearest filtering.
 * One code path for OpenGL 3.3 core and WebGL2 / GLES 3.0.
 * SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sx_log.h"
#include "sx_math.h"
#include "sx_platform.h"

#ifdef __EMSCRIPTEN__
#include <GLES3/gl3.h>
#define SX_GLSL "#version 300 es\nprecision highp float;\nprecision highp int;\n"
#else
#include <SDL3/SDL_opengl.h>
#define SX_GLSL "#version 330 core\n"
#ifndef APIENTRY
#define APIENTRY
#endif
/* Every entry point (including GL 1.1) is loaded at runtime, so the binary
 * does not link libGL/opengl32 directly. */
#define SX_GL_FUNCS(X)                                                                                                 \
  X(void, glClear, (GLbitfield m))                                                                                     \
  X(void, glClearColor, (GLfloat r, GLfloat g, GLfloat b, GLfloat a))                                                  \
  X(void, glViewport, (GLint x, GLint y, GLsizei w, GLsizei h))                                                        \
  X(void, glScissor, (GLint x, GLint y, GLsizei w, GLsizei h))                                                         \
  X(void, glEnable, (GLenum c))                                                                                        \
  X(void, glDisable, (GLenum c))                                                                                       \
  X(void, glBlendFunc, (GLenum s, GLenum d))                                                                           \
  X(void, glDepthMask, (GLboolean f))                                                                                  \
  X(void, glDepthFunc, (GLenum f))                                                                                     \
  X(void, glCullFace, (GLenum f))                                                                                      \
  X(void, glDrawElements, (GLenum m, GLsizei n, GLenum t, const void *p))                                              \
  X(void, glDrawArrays, (GLenum m, GLint f, GLsizei n))                                                                \
  X(void, glReadPixels, (GLint x, GLint y, GLsizei w, GLsizei h, GLenum f, GLenum t, void *p))                         \
  X(void, glPixelStorei, (GLenum p, GLint v))                                                                          \
  X(void, glGenTextures, (GLsizei n, GLuint * t))                                                                      \
  X(void, glDeleteTextures, (GLsizei n, const GLuint *t))                                                              \
  X(void, glBindTexture, (GLenum t, GLuint n))                                                                         \
  X(void, glTexParameteri, (GLenum t, GLenum p, GLint v))                                                              \
  X(void, glTexImage2D, (GLenum t, GLint l, GLint i, GLsizei w, GLsizei h, GLint b, GLenum f, GLenum ty, const void *p)) \
  X(void, glActiveTexture, (GLenum t))                                                                                 \
  X(GLuint, glCreateShader, (GLenum t))                                                                                \
  X(void, glShaderSource, (GLuint s, GLsizei n, const GLchar *const *src, const GLint *len))                           \
  X(void, glCompileShader, (GLuint s))                                                                                 \
  X(void, glGetShaderiv, (GLuint s, GLenum p, GLint * v))                                                              \
  X(void, glGetShaderInfoLog, (GLuint s, GLsizei n, GLsizei * l, GLchar * log))                                        \
  X(void, glDeleteShader, (GLuint s))                                                                                  \
  X(GLuint, glCreateProgram, (void))                                                                                   \
  X(void, glAttachShader, (GLuint p, GLuint s))                                                                        \
  X(void, glBindAttribLocation, (GLuint p, GLuint i, const GLchar *n))                                                 \
  X(void, glLinkProgram, (GLuint p))                                                                                   \
  X(void, glGetProgramiv, (GLuint p, GLenum q, GLint * v))                                                             \
  X(void, glGetProgramInfoLog, (GLuint p, GLsizei n, GLsizei * l, GLchar * log))                                       \
  X(void, glUseProgram, (GLuint p))                                                                                    \
  X(GLint, glGetUniformLocation, (GLuint p, const GLchar *n))                                                          \
  X(void, glUniform1i, (GLint l, GLint v))                                                                             \
  X(void, glUniform1f, (GLint l, GLfloat v))                                                                           \
  X(void, glUniform2f, (GLint l, GLfloat a, GLfloat b))                                                                \
  X(void, glUniform3f, (GLint l, GLfloat a, GLfloat b, GLfloat c))                                                     \
  X(void, glUniform4f, (GLint l, GLfloat a, GLfloat b, GLfloat c, GLfloat d))                                          \
  X(void, glUniformMatrix4fv, (GLint l, GLsizei n, GLboolean t, const GLfloat *v))                                     \
  X(void, glGenBuffers, (GLsizei n, GLuint * b))                                                                       \
  X(void, glDeleteBuffers, (GLsizei n, const GLuint *b))                                                               \
  X(void, glBindBuffer, (GLenum t, GLuint b))                                                                          \
  X(void, glBufferData, (GLenum t, GLsizeiptr n, const void *d, GLenum u))                                             \
  X(void, glGenVertexArrays, (GLsizei n, GLuint * a))                                                                  \
  X(void, glDeleteVertexArrays, (GLsizei n, const GLuint *a))                                                          \
  X(void, glBindVertexArray, (GLuint a))                                                                               \
  X(void, glEnableVertexAttribArray, (GLuint i))                                                                       \
  X(void, glVertexAttribPointer, (GLuint i, GLint n, GLenum t, GLboolean norm, GLsizei s, const void *p))              \
  X(void, glGenFramebuffers, (GLsizei n, GLuint * f))                                                                  \
  X(void, glDeleteFramebuffers, (GLsizei n, const GLuint *f))                                                          \
  X(void, glBindFramebuffer, (GLenum t, GLuint f))                                                                     \
  X(void, glFramebufferTexture2D, (GLenum t, GLenum a, GLenum tt, GLuint tex, GLint l))                                \
  X(void, glFramebufferRenderbuffer, (GLenum t, GLenum a, GLenum rt, GLuint rb))                                       \
  X(GLenum, glCheckFramebufferStatus, (GLenum t))                                                                      \
  X(void, glGenRenderbuffers, (GLsizei n, GLuint * r))                                                                 \
  X(void, glDeleteRenderbuffers, (GLsizei n, const GLuint *r))                                                         \
  X(void, glBindRenderbuffer, (GLenum t, GLuint r))                                                                    \
  X(void, glRenderbufferStorage, (GLenum t, GLenum f, GLsizei w, GLsizei h))

#define SX_GL_DECL(ret, name, args)                                                                                    \
  typedef ret(APIENTRY *PFN_sx_##name) args;                                                                           \
  static PFN_sx_##name p_##name;
SX_GL_FUNCS(SX_GL_DECL)
#undef SX_GL_DECL
#define glClear p_glClear
#define glClearColor p_glClearColor
#define glViewport p_glViewport
#define glScissor p_glScissor
#define glEnable p_glEnable
#define glDisable p_glDisable
#define glBlendFunc p_glBlendFunc
#define glDepthMask p_glDepthMask
#define glDepthFunc p_glDepthFunc
#define glCullFace p_glCullFace
#define glDrawElements p_glDrawElements
#define glDrawArrays p_glDrawArrays
#define glReadPixels p_glReadPixels
#define glPixelStorei p_glPixelStorei
#define glGenTextures p_glGenTextures
#define glDeleteTextures p_glDeleteTextures
#define glBindTexture p_glBindTexture
#define glTexParameteri p_glTexParameteri
#define glTexImage2D p_glTexImage2D
#define glActiveTexture p_glActiveTexture
#define glCreateShader p_glCreateShader
#define glShaderSource p_glShaderSource
#define glCompileShader p_glCompileShader
#define glGetShaderiv p_glGetShaderiv
#define glGetShaderInfoLog p_glGetShaderInfoLog
#define glDeleteShader p_glDeleteShader
#define glCreateProgram p_glCreateProgram
#define glAttachShader p_glAttachShader
#define glBindAttribLocation p_glBindAttribLocation
#define glLinkProgram p_glLinkProgram
#define glGetProgramiv p_glGetProgramiv
#define glGetProgramInfoLog p_glGetProgramInfoLog
#define glUseProgram p_glUseProgram
#define glGetUniformLocation p_glGetUniformLocation
#define glUniform1i p_glUniform1i
#define glUniform1f p_glUniform1f
#define glUniform2f p_glUniform2f
#define glUniform3f p_glUniform3f
#define glUniform4f p_glUniform4f
#define glUniformMatrix4fv p_glUniformMatrix4fv
#define glGenBuffers p_glGenBuffers
#define glDeleteBuffers p_glDeleteBuffers
#define glBindBuffer p_glBindBuffer
#define glBufferData p_glBufferData
#define glGenVertexArrays p_glGenVertexArrays
#define glDeleteVertexArrays p_glDeleteVertexArrays
#define glBindVertexArray p_glBindVertexArray
#define glEnableVertexAttribArray p_glEnableVertexAttribArray
#define glVertexAttribPointer p_glVertexAttribPointer
#define glGenFramebuffers p_glGenFramebuffers
#define glDeleteFramebuffers p_glDeleteFramebuffers
#define glBindFramebuffer p_glBindFramebuffer
#define glFramebufferTexture2D p_glFramebufferTexture2D
#define glFramebufferRenderbuffer p_glFramebufferRenderbuffer
#define glCheckFramebufferStatus p_glCheckFramebufferStatus
#define glGenRenderbuffers p_glGenRenderbuffers
#define glDeleteRenderbuffers p_glDeleteRenderbuffers
#define glBindRenderbuffer p_glBindRenderbuffer
#define glRenderbufferStorage p_glRenderbufferStorage
#endif

#ifndef GL_R8
#define GL_R8 0x8229
#endif
#ifndef GL_RED
#define GL_RED 0x1903
#endif

/* ---------------------------------------------------------------- shaders */
static const char *mesh_vs =
    "in vec3 a_pos; in vec3 a_nrm; in vec2 a_uv; in vec3 a_col; in float a_emi;\n"
    "uniform mat4 u_mvp; uniform mat4 u_mv; uniform mat4 u_model; uniform vec2 u_snap;\n"
    "out vec2 v_uv; out vec3 v_col; out float v_emi; out float v_dist; out vec3 v_nrm;\n"
    "void main() {\n"
    "  vec4 c = u_mvp * vec4(a_pos, 1.0);\n"
    "  if (u_snap.x > 0.0 && c.w > 0.0) c.xy = floor(c.xy / c.w * u_snap + 0.5) / u_snap * c.w;\n"
    "  gl_Position = c;\n"
    "  v_uv = a_uv; v_col = a_col; v_emi = a_emi;\n"
    "  v_nrm = mat3(u_model) * a_nrm;\n"
    "  v_dist = length((u_mv * vec4(a_pos, 1.0)).xyz);\n"
    "}\n";

static const char *mesh_fs =
    "in vec2 v_uv; in vec3 v_col; in float v_emi; in float v_dist; in vec3 v_nrm;\n"
    "uniform sampler2D u_idx; uniform sampler2D u_pal; uniform int u_palrow; uniform int u_tex;\n"
    "uniform vec4 u_tint; uniform vec3 u_light; uniform float u_ambient; uniform int u_lit;\n"
    "uniform vec3 u_fogcol; uniform float u_fog; uniform int u_dither;\n"
    "out vec4 o_col;\n"
    "const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,\n"
    "                                  3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);\n"
    "void main() {\n"
    "  vec4 base = vec4(1.0);\n"
    "  if (u_tex == 1) {\n"
    "    int i = int(texture(u_idx, v_uv).r * 255.0 + 0.5);\n"
    "    if (i == 0) discard;\n"
    "    base = texelFetch(u_pal, ivec2(i, u_palrow), 0);\n"
    "  }\n"
    "  vec3 c = base.rgb * v_col * u_tint.rgb;\n"
    "  vec3 lit = c;\n"
    "  if (u_lit == 1) {\n"
    "    float d = max(dot(normalize(v_nrm), normalize(u_light)), 0.0);\n"
    "    lit = c * (u_ambient + (1.0 - u_ambient) * d);\n"
    "  }\n"
    "  c = mix(lit, c * 1.25, clamp(v_emi, 0.0, 1.0));\n"
    "  if (u_fog > 0.0) c = mix(u_fogcol, c, exp(-u_fog * v_dist));\n"
    "  if (u_dither == 1) {\n"
    "    ivec2 p = ivec2(gl_FragCoord.xy) % 4;\n"
    "    float b = (bayer[p.y * 4 + p.x] + 0.5) / 16.0;\n"
    "    c = floor(clamp(c, 0.0, 1.0) * 31.0 + b) / 31.0;\n"
    "  }\n"
    "  float a = base.a * u_tint.a;\n"
    "  if (a < 0.01) discard;\n"
    "  o_col = vec4(c, a);\n"
    "}\n";

static const char *ui_vs =
    "in vec2 a_pos; in vec2 a_uv;\n"
    "uniform vec2 u_size;\n"
    "out vec2 v_uv;\n"
    "void main() { v_uv = a_uv; gl_Position = vec4(a_pos.x / u_size.x * 2.0 - 1.0, 1.0 - a_pos.y / u_size.y * 2.0, 0.0, 1.0); }\n";

static const char *ui_fs =
    "in vec2 v_uv;\n"
    "uniform sampler2D u_idx; uniform sampler2D u_pal; uniform int u_palrow; uniform int u_tex; uniform vec4 u_color;\n"
    "out vec4 o_col;\n"
    "void main() {\n"
    "  vec4 c = u_color;\n"
    "  if (u_tex == 1) {\n"
    "    int i = int(texture(u_idx, v_uv).r * 255.0 + 0.5);\n"
    "    if (i == 0) discard;\n"
    "    c *= texelFetch(u_pal, ivec2(i, u_palrow), 0);\n"
    "  } else if (u_tex == 2) {\n" /* font: any set texel takes the colour */
    "    if (texture(u_idx, v_uv).r < 0.002) discard;\n"
    "  } else if (u_tex == 3) {\n" /* plain RGBA texture (upscale pass) */
    "    c = texture(u_idx, v_uv);\n"
    "  }\n"
    "  o_col = c;\n"
    "}\n";

typedef struct prog {
  GLuint id;
  GLint mvp, mv, model, snap, idx, pal, palrow, tex, tint, light, ambient, lit, fogcol, fog, dither, size, color;
} prog;

static struct {
  int ok;
  prog mesh, ui;
  GLuint pal_tex;
  GLuint white_tex;
  GLuint fbo, fbo_color, fbo_depth;
  int fbo_w, fbo_h;
  GLuint stream_vao, stream_vbo;     /* billboards: mesh vertex layout */
  GLuint ui_vao, ui_vbo;             /* ui: pos2 uv2 */
  GLuint mesh_vao[SX_MAX_MESHES], mesh_vbo[SX_MAX_MESHES], mesh_ibo[SX_MAX_MESHES];
  int mesh_count[SX_MAX_MESHES];
  GLuint tex[SX_MAX_TEXTURES];
} G;

static GLuint compile(GLenum type, const char *src) {
  const char *parts[2] = {SX_GLSL, src};
  GLuint s = glCreateShader(type);
  GLint ok = 0;
  glShaderSource(s, 2, parts, NULL);
  glCompileShader(s);
  glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[2048];
    glGetShaderInfoLog(s, sizeof log, NULL, log);
    SX_ERROR("shader compile failed: %s", log);
  }
  return s;
}

static int link_prog(prog *p, const char *vs, const char *fs, int ui) {
  GLuint v = compile(GL_VERTEX_SHADER, vs), f = compile(GL_FRAGMENT_SHADER, fs);
  GLint ok = 0;
  p->id = glCreateProgram();
  glAttachShader(p->id, v);
  glAttachShader(p->id, f);
  if (ui) {
    glBindAttribLocation(p->id, 0, "a_pos");
    glBindAttribLocation(p->id, 1, "a_uv");
  } else {
    glBindAttribLocation(p->id, 0, "a_pos");
    glBindAttribLocation(p->id, 1, "a_nrm");
    glBindAttribLocation(p->id, 2, "a_uv");
    glBindAttribLocation(p->id, 3, "a_col");
    glBindAttribLocation(p->id, 4, "a_emi");
  }
  glLinkProgram(p->id);
  glDeleteShader(v);
  glDeleteShader(f);
  glGetProgramiv(p->id, GL_LINK_STATUS, &ok);
  if (!ok) {
    char log[2048];
    glGetProgramInfoLog(p->id, sizeof log, NULL, log);
    SX_ERROR("shader link failed: %s", log);
    return 0;
  }
#define U(n) p->n = glGetUniformLocation(p->id, "u_" #n)
  U(mvp); U(mv); U(model); U(snap); U(idx); U(pal); U(palrow); U(tex); U(tint); U(light); U(ambient); U(lit);
  U(fogcol); U(fog); U(dither); U(size); U(color);
#undef U
  glUseProgram(p->id);
  glUniform1i(p->idx, 0);
  glUniform1i(p->pal, 1);
  return 1;
}

static void mesh_layout(void) {
  const GLsizei st = SX_VTX_FLOATS * sizeof(float);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, st, (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, st, (void *)(3 * sizeof(float)));
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, st, (void *)(6 * sizeof(float)));
  glEnableVertexAttribArray(3);
  glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, st, (void *)(8 * sizeof(float)));
  glEnableVertexAttribArray(4);
  glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, st, (void *)(11 * sizeof(float)));
}

static void tex_params(GLint filter, GLint wrap) {
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap);
}

int sx_gl_init(void *(*get_proc)(const char *name)) {
  unsigned char white = 1;
#ifndef __EMSCRIPTEN__
  int missing = 0;
#define SX_GL_LOAD(ret, name, args)                                                                                    \
  p_##name = (PFN_sx_##name)get_proc(#name);                                                                           \
  if (!p_##name) {                                                                                                     \
    SX_ERROR("missing GL entry point %s", #name);                                                                     \
    missing = 1;                                                                                                       \
  }
  SX_GL_FUNCS(SX_GL_LOAD)
#undef SX_GL_LOAD
  if (missing) return 0;
#else
  (void)get_proc;
#endif
  memset(&G, 0, sizeof G);
  if (!link_prog(&G.mesh, mesh_vs, mesh_fs, 0) || !link_prog(&G.ui, ui_vs, ui_fs, 1)) return 0;
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glPixelStorei(GL_PACK_ALIGNMENT, 1);
  glGenTextures(1, &G.pal_tex);
  glGenTextures(1, &G.white_tex);
  glBindTexture(GL_TEXTURE_2D, G.white_tex);
  tex_params(GL_NEAREST, GL_REPEAT);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, 1, 1, 0, GL_RED, GL_UNSIGNED_BYTE, &white);
  glGenVertexArrays(1, &G.stream_vao);
  glGenBuffers(1, &G.stream_vbo);
  glBindVertexArray(G.stream_vao);
  glBindBuffer(GL_ARRAY_BUFFER, G.stream_vbo);
  mesh_layout();
  glGenVertexArrays(1, &G.ui_vao);
  glGenBuffers(1, &G.ui_vbo);
  glBindVertexArray(G.ui_vao);
  glBindBuffer(GL_ARRAY_BUFFER, G.ui_vbo);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)(2 * sizeof(float)));
  glBindVertexArray(0);
  G.ok = 1;
  return 1;
}

void sx_gl_shutdown(void) {
  int i;
  if (!G.ok) return;
  for (i = 0; i < SX_MAX_MESHES; i++) {
    if (G.mesh_vao[i]) {
      glDeleteVertexArrays(1, &G.mesh_vao[i]);
      glDeleteBuffers(1, &G.mesh_vbo[i]);
      glDeleteBuffers(1, &G.mesh_ibo[i]);
    }
  }
  for (i = 0; i < SX_MAX_TEXTURES; i++)
    if (G.tex[i]) glDeleteTextures(1, &G.tex[i]);
  if (G.fbo) {
    glDeleteFramebuffers(1, &G.fbo);
    glDeleteTextures(1, &G.fbo_color);
    glDeleteRenderbuffers(1, &G.fbo_depth);
  }
  G.ok = 0;
}

/* ------------------------------------------------------------- resources */
static void sync(sx_render *r) {
  int i;
  if (r->palettes_dirty) {
    glBindTexture(GL_TEXTURE_2D, G.pal_tex);
    tex_params(GL_NEAREST, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, SX_PALETTE_W, SX_MAX_PALETTES, 0, GL_RGBA, GL_UNSIGNED_BYTE, r->palettes);
    r->palettes_dirty = 0;
  }
  for (i = 1; i < SX_MAX_TEXTURES; i++) {
    sx_texture *t = &r->textures[i];
    if (!t->used || !t->dirty) continue;
    if (!G.tex[i]) glGenTextures(1, &G.tex[i]);
    glBindTexture(GL_TEXTURE_2D, G.tex[i]);
    tex_params(GL_NEAREST, GL_REPEAT);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, t->w, t->h, 0, GL_RED, GL_UNSIGNED_BYTE, t->index);
    t->dirty = 0;
    t->gpu = (int)G.tex[i];
  }
  for (i = 1; i < SX_MAX_MESHES; i++) {
    sx_rmesh *m = &r->meshes[i];
    if (G.mesh_vao[i] && (!m->used || m->dirty)) {
      glDeleteVertexArrays(1, &G.mesh_vao[i]);
      glDeleteBuffers(1, &G.mesh_vbo[i]);
      glDeleteBuffers(1, &G.mesh_ibo[i]);
      G.mesh_vao[i] = G.mesh_vbo[i] = G.mesh_ibo[i] = 0;
      m->gpu = 0;
    }
    if (m->used && m->dirty) {
      glGenVertexArrays(1, &G.mesh_vao[i]);
      glGenBuffers(1, &G.mesh_vbo[i]);
      glGenBuffers(1, &G.mesh_ibo[i]);
      glBindVertexArray(G.mesh_vao[i]);
      glBindBuffer(GL_ARRAY_BUFFER, G.mesh_vbo[i]);
      glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(sizeof(float) * SX_VTX_FLOATS * (size_t)m->mesh.nv), m->mesh.v,
                   GL_STATIC_DRAW);
      glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, G.mesh_ibo[i]);
      glBufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)(sizeof(uint32_t) * (size_t)m->mesh.ni), m->mesh.idx,
                   GL_STATIC_DRAW);
      mesh_layout();
      glBindVertexArray(0);
      G.mesh_count[i] = m->mesh.ni;
      m->dirty = 0;
      m->gpu = (int)G.mesh_vao[i];
    }
  }
}

static void ensure_fbo(int w, int h) {
  if (G.fbo && G.fbo_w == w && G.fbo_h == h) return;
  if (G.fbo) {
    glDeleteFramebuffers(1, &G.fbo);
    glDeleteTextures(1, &G.fbo_color);
    glDeleteRenderbuffers(1, &G.fbo_depth);
  }
  glGenFramebuffers(1, &G.fbo);
  glGenTextures(1, &G.fbo_color);
  glGenRenderbuffers(1, &G.fbo_depth);
  glBindTexture(GL_TEXTURE_2D, G.fbo_color);
  tex_params(GL_NEAREST, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glBindRenderbuffer(GL_RENDERBUFFER, G.fbo_depth);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
  glBindFramebuffer(GL_FRAMEBUFFER, G.fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, G.fbo_color, 0);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, G.fbo_depth);
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) SX_ERROR("low-res framebuffer incomplete");
  G.fbo_w = w;
  G.fbo_h = h;
}

/* --------------------------------------------------------------- drawing */
static void bind_tex(const sx_render *r, int tex) {
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, (tex > 0 && tex < SX_MAX_TEXTURES && r->textures[tex].used && G.tex[tex]) ? G.tex[tex]
                                                                                                       : G.white_tex);
}

static int pal_row(const sx_render *r, int p) { return (p >= 0 && p < r->npalettes) ? p : 0; }

typedef struct frame_mats {
  float view[16], proj[16], vp[16];
  float right[3], up[3];
} frame_mats;

static void set_common(const sx_viewport *v, const sx_render *r, int snap_ok) {
  glUniform3f(G.mesh.light, v->light_dir[0], v->light_dir[1], v->light_dir[2]);
  glUniform1f(G.mesh.ambient, v->ambient);
  glUniform3f(G.mesh.fogcol, v->fog_color[0], v->fog_color[1], v->fog_color[2]);
  glUniform1i(G.mesh.dither, r->settings.dither ? 1 : 0);
  if (snap_ok && r->settings.vertex_snap) glUniform2f(G.mesh.snap, (float)v->w * 0.5f, (float)v->h * 0.5f);
  else glUniform2f(G.mesh.snap, 0, 0);
}

static void draw_mesh(const sx_render *r, const sx_viewport *v, const frame_mats *fm, const sx_draw_mesh *d) {
  float mv[16], mvp[16], model[16];
  if (d->mesh <= 0 || d->mesh >= SX_MAX_MESHES || !G.mesh_vao[d->mesh]) return;
  memcpy(model, d->model, sizeof model);
  if (d->flags & SX_DRAW_SKY) {
    /* sky: follows the camera, drawn behind everything */
    float view[16];
    memcpy(view, fm->view, sizeof view);
    view[12] = view[13] = view[14] = 0;
    model[12] = model[13] = model[14] = 0;
    sx_mat4_mul(mv, view, model);
  } else {
    sx_mat4_mul(mv, fm->view, model);
  }
  sx_mat4_mul(mvp, fm->proj, mv);
  glUniformMatrix4fv(G.mesh.mvp, 1, GL_FALSE, mvp);
  glUniformMatrix4fv(G.mesh.mv, 1, GL_FALSE, mv);
  glUniformMatrix4fv(G.mesh.model, 1, GL_FALSE, model);
  glUniform1i(G.mesh.tex, d->tex > 0 ? 1 : 0);
  glUniform1i(G.mesh.palrow, pal_row(r, d->palette));
  glUniform1i(G.mesh.lit, (d->flags & SX_DRAW_UNLIT) ? 0 : 1);
  glUniform1f(G.mesh.fog, (d->flags & SX_DRAW_NOFOG) ? 0.0f : v->fog_density);
  if (d->flags & SX_DRAW_GHOST) glUniform4f(G.mesh.tint, d->tint[0] * 0.6f, d->tint[1] * 0.85f, d->tint[2], d->tint[3] * 0.35f);
  else glUniform4f(G.mesh.tint, d->tint[0], d->tint[1], d->tint[2], d->tint[3]);
  bind_tex(r, d->tex);
  glBindVertexArray(G.mesh_vao[d->mesh]);
  glDrawElements(GL_TRIANGLES, G.mesh_count[d->mesh], GL_UNSIGNED_INT, (void *)0);
}

static void draw_billboards(const sx_render *r, const sx_viewport *v, const frame_mats *fm) {
  int i, k;
  float ident[16];
  if (!v->nbills) return;
  sx_mat4_identity(ident);
  glUniformMatrix4fv(G.mesh.mvp, 1, GL_FALSE, fm->vp);
  glUniformMatrix4fv(G.mesh.mv, 1, GL_FALSE, fm->view);
  glUniformMatrix4fv(G.mesh.model, 1, GL_FALSE, ident);
  glUniform1i(G.mesh.lit, 0);
  glUniform1f(G.mesh.fog, v->fog_density);
  glUniform1i(G.mesh.tex, 1);
  glBindVertexArray(G.stream_vao);
  glBindBuffer(GL_ARRAY_BUFFER, G.stream_vbo);
  for (i = 0; i < v->nbills; i++) {
    const sx_draw_billboard *b = &v->bills[i];
    float vtx[6][SX_VTX_FLOATS], rt[3], up[3];
    static const float corner[6][2] = {{-1, -1}, {1, -1}, {1, 1}, {-1, -1}, {1, 1}, {-1, 1}};
    if (b->yaxis) {
      float l = (float)sx_sqrt((double)(fm->right[0] * fm->right[0] + fm->right[2] * fm->right[2]));
      rt[0] = l > 1e-6f ? fm->right[0] / l : 1;
      rt[1] = 0;
      rt[2] = l > 1e-6f ? fm->right[2] / l : 0;
      up[0] = 0;
      up[1] = 1;
      up[2] = 0;
    } else {
      memcpy(rt, fm->right, sizeof rt);
      memcpy(up, fm->up, sizeof up);
    }
    for (k = 0; k < 6; k++) {
      float hx = corner[k][0] * b->size[0] * 0.5f, hy = corner[k][1] * b->size[1] * 0.5f;
      float *p = vtx[k];
      p[0] = b->pos[0] + rt[0] * hx + up[0] * hy;
      p[1] = b->pos[1] + rt[1] * hx + up[1] * hy;
      p[2] = b->pos[2] + rt[2] * hx + up[2] * hy;
      p[3] = 0;
      p[4] = 1;
      p[5] = 0;
      p[6] = (corner[k][0] + 1) * 0.5f;
      p[7] = 1.0f - (corner[k][1] + 1) * 0.5f;
      p[8] = p[9] = p[10] = 1;
      p[11] = 0;
    }
    glUniform4f(G.mesh.tint, b->tint[0], b->tint[1], b->tint[2], b->tint[3]);
    glUniform1i(G.mesh.palrow, pal_row(r, b->palette));
    bind_tex(r, b->tex);
    glBufferData(GL_ARRAY_BUFFER, sizeof vtx, vtx, GL_STREAM_DRAW);
    glDrawArrays(GL_TRIANGLES, 0, 6);
  }
}

static void ui_quad(float x, float y, float w, float h, float u0, float v0, float u1, float v1) {
  float q[6][4] = {{x, y, u0, v0},         {x + w, y, u1, v0}, {x + w, y + h, u1, v1},
                   {x, y, u0, v0},         {x + w, y + h, u1, v1}, {x, y + h, u0, v1}};
  glBufferData(GL_ARRAY_BUFFER, sizeof q, q, GL_STREAM_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, 6);
}

static void draw_ui(const sx_render *r, const sx_viewport *v) {
  int i;
  if (!v->nui) return;
  glUseProgram(G.ui.id);
  glUniform2f(G.ui.size, (float)v->w, (float)v->h);
  glBindVertexArray(G.ui_vao);
  glBindBuffer(GL_ARRAY_BUFFER, G.ui_vbo);
  glDisable(GL_DEPTH_TEST);
  for (i = 0; i < v->nui; i++) {
    const sx_draw_ui *u = &v->ui[i];
    glUniform4f(G.ui.color, u->color[0], u->color[1], u->color[2], u->color[3]);
    if (u->kind == 0) {
      glUniform1i(G.ui.tex, 0);
      ui_quad(u->x, u->y, u->w, u->h, 0, 0, 1, 1);
    } else if (u->kind == 1) {
      const char *s;
      float x = u->x, sc = (float)(u->scale > 0 ? u->scale : 1);
      glUniform1i(G.ui.tex, 2);
      bind_tex(r, r->font_tex);
      for (s = u->text; *s; s++) {
        int c = (unsigned char)*s & 127;
        float gx = (float)(c % 16) * 8.0f / 128.0f, gy = (float)(c / 16) * 8.0f / 64.0f;
        if (c != ' ') ui_quad(x, u->y, 8 * sc, 8 * sc, gx, gy, gx + 8.0f / 128.0f, gy + 8.0f / 64.0f);
        x += 8 * sc;
      }
    } else {
      glUniform1i(G.ui.tex, 1);
      glUniform1i(G.ui.palrow, pal_row(r, u->palette));
      bind_tex(r, u->tex);
      ui_quad(u->x, u->y, u->w, u->h, 0, 0, 1, 1);
    }
  }
}

static void draw_view(const sx_render *r, const sx_viewport *v, int fb_h, int xr) {
  frame_mats fm;
  int i, pass;
  int gy = xr ? v->y : fb_h - v->y - v->h; /* views are laid out top-down */
  glViewport(v->x, gy, v->w, v->h);
  glScissor(v->x, gy, v->w, v->h);
  glEnable(GL_SCISSOR_TEST);
  glClearColor(v->clear_color[0], v->clear_color[1], v->clear_color[2], 1);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  sx_camera_view(&v->cam, fm.view);
  if (v->cam.has_matrices) memcpy(fm.proj, v->cam.proj, sizeof fm.proj);
  else sx_mat4_perspective(fm.proj, v->cam.fov, (float)v->w / (float)(v->h > 0 ? v->h : 1), v->cam.znear, v->cam.zfar);
  sx_mat4_mul(fm.vp, fm.proj, fm.view);
  /* camera basis = rows of the view rotation */
  fm.right[0] = fm.view[0]; fm.right[1] = fm.view[4]; fm.right[2] = fm.view[8];
  fm.up[0] = fm.view[1];    fm.up[1] = fm.view[5];    fm.up[2] = fm.view[9];
  glUseProgram(G.mesh.id);
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, G.pal_tex);
  set_common(v, r, !xr);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LEQUAL);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  /* pass 0 sky, 1 opaque, 2 billboards, 3 ghosts */
  for (pass = 0; pass < 4; pass++) {
    if (pass == 0) glDepthMask(GL_FALSE);
    if (pass == 1) glDepthMask(GL_TRUE);
    if (pass == 2) {
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      draw_billboards(r, v, &fm);
      continue;
    }
    if (pass == 3) glDepthMask(GL_FALSE);
    for (i = 0; i < v->nmeshes; i++) {
      const sx_draw_mesh *d = &v->meshes[i];
      int want = (d->flags & SX_DRAW_SKY) ? 0 : (d->flags & SX_DRAW_GHOST) ? 3 : 1;
      if (want == pass) draw_mesh(r, v, &fm, d);
    }
  }
  glDepthMask(GL_TRUE);
  draw_ui(r, v);
  glDisable(GL_BLEND);
  glDisable(GL_SCISSOR_TEST);
}

void sx_gl_draw(sx_render *r, int win_w, int win_h) {
  int i, w = r->settings.width, h = r->settings.height;
  float sx, sy, s, dw, dh;
  if (!G.ok) return;
  sync(r);
  ensure_fbo(w, h);
  glBindFramebuffer(GL_FRAMEBUFFER, G.fbo);
  for (i = 0; i < r->nviews; i++) draw_view(r, &r->views[i], h, 0);
  /* nearest-neighbour upscale into the window, letterboxed */
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glViewport(0, 0, win_w, win_h);
  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  sx = (float)win_w / (float)w;
  sy = (float)win_h / (float)h;
  s = sx < sy ? sx : sy;
  dw = (float)w * s;
  dh = (float)h * s;
  glUseProgram(G.ui.id);
  glUniform2f(G.ui.size, (float)win_w, (float)win_h);
  glUniform1i(G.ui.tex, 3);
  glUniform4f(G.ui.color, 1, 1, 1, 1);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, G.fbo_color);
  glDisable(GL_DEPTH_TEST);
  glBindVertexArray(G.ui_vao);
  glBindBuffer(GL_ARRAY_BUFFER, G.ui_vbo);
  ui_quad(((float)win_w - dw) * 0.5f, ((float)win_h - dh) * 0.5f, dw, dh, 0, 1, 1, 0);
  glBindVertexArray(0);
}

void sx_gl_draw_xr(sx_render *r, unsigned int fb) {
  int i;
  if (!G.ok) return;
  sync(r);
  glBindFramebuffer(GL_FRAMEBUFFER, fb);
  for (i = 0; i < r->nviews; i++) draw_view(r, &r->views[i], 0, 1);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

unsigned char *sx_gl_read_pixels(int w, int h) {
  unsigned char *px = (unsigned char *)malloc((size_t)w * (size_t)h * 4), *row;
  int y;
  if (!px) return NULL;
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, px);
  row = (unsigned char *)malloc((size_t)w * 4);
  for (y = 0; y < h / 2; y++) {
    memcpy(row, px + (size_t)y * w * 4, (size_t)w * 4);
    memcpy(px + (size_t)y * w * 4, px + (size_t)(h - 1 - y) * w * 4, (size_t)w * 4);
    memcpy(px + (size_t)(h - 1 - y) * w * 4, row, (size_t)w * 4);
  }
  free(row);
  return px;
}
