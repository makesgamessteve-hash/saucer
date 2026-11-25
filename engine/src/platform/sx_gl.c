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
  X(void, glRenderbufferStorage, (GLenum t, GLenum f, GLsizei w, GLsizei h))                                       \
  X(void, glDrawBuffers, (GLsizei n, const GLenum *b))                                                                 \
  X(void, glReadBuffer, (GLenum b))                                                                                    \
  X(void, glPolygonOffset, (GLfloat f, GLfloat u))                                                                     \
  X(void, glUniform1fv, (GLint l, GLsizei n, const GLfloat *v))                                                        \
  X(void, glUniform1iv, (GLint l, GLsizei n, const GLint *v))                                                          \
  X(void, glUniform4fv, (GLint l, GLsizei n, const GLfloat *v))

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
#define glDrawBuffers p_glDrawBuffers
#define glReadBuffer p_glReadBuffer
#define glPolygonOffset p_glPolygonOffset
#define glUniform1fv p_glUniform1fv
#define glUniform1iv p_glUniform1iv
#define glUniform4fv p_glUniform4fv
#endif

#ifndef GL_R8
#define GL_R8 0x8229
#endif
#ifndef GL_RED
#define GL_RED 0x1903
#endif
#ifndef GL_DEPTH_COMPONENT24
#define GL_DEPTH_COMPONENT24 0x81A6
#endif
#ifndef GL_TEXTURE_COMPARE_MODE
#define GL_TEXTURE_COMPARE_MODE 0x884C
#endif
#ifndef GL_TEXTURE_COMPARE_FUNC
#define GL_TEXTURE_COMPARE_FUNC 0x884D
#endif
#ifndef GL_COMPARE_REF_TO_TEXTURE
#define GL_COMPARE_REF_TO_TEXTURE 0x884E
#endif

/* ---------------------------------------------------------------- shaders */
/* add-material-system: a_mat is the vertex's material slot. Organic slots wobble along the normal and breathe
 * (render time u_mtime only: the sim never sees it); the view-space normal feeds the matcap lookup. */
static const char *mesh_vs =
    "in vec3 a_pos; in vec3 a_nrm; in vec2 a_uv; in vec3 a_col; in float a_emi; in float a_mat;\n"
    "uniform mat4 u_mvp; uniform mat4 u_mv; uniform mat4 u_model; uniform vec2 u_snap; uniform int u_affine;\n"
    "uniform vec4 u_mat[48]; uniform float u_mtime; uniform int u_mmode;\n"
    "out vec3 v_uv; out vec3 v_col; out float v_emi; out float v_dist; out vec3 v_nrm; out vec3 v_wpos;\n"
    "out vec3 v_vnrm; flat out int v_mat;\n"
    "void main() {\n"
    "  vec3 pos = a_pos;\n"
    "  int ms = u_mmode > 0 ? int(a_mat + 0.5) : 0;\n"
    "  if (ms > 0 && ms < 8 && u_mat[ms * 6].x > 2.5) {\n"
    "    vec4 p1 = u_mat[ms * 6 + 1]; float br = u_mat[ms * 6 + 2].w;\n"
    "    vec3 w = (u_model * vec4(a_pos, 1.0)).xyz;\n"
    "    float ph = (w.x + w.y * 0.7 + w.z * 1.3) / p1.w;\n"
    "    pos += a_nrm * (p1.y * sin(6.2831853 * u_mtime / p1.z + ph) + br * sin(6.2831853 * u_mtime / (3.0 * p1.z)));\n"
    "  }\n"
    "  v_mat = ms;\n"
    "  v_vnrm = mat3(u_mv) * a_nrm;\n"
    "  vec4 c = u_mvp * vec4(pos, 1.0);\n"
    "  if (u_snap.x > 0.0 && c.w > 0.0) c.xy = floor(c.xy / c.w * u_snap + 0.5) / u_snap * c.w;\n"
    "  gl_Position = c;\n"
    "  // affine warp: (uv * w, w) interpolates perspective-correctly to (sum l_i uv_i / s, 1 / s), whose ratio\n"
    "  // is the screen-linear uv; with the warp off the third component is 1 and the division changes nothing\n"
    "  v_uv = u_affine == 1 ? vec3(a_uv * c.w, c.w) : vec3(a_uv, 1.0);\n"
    "  v_col = a_col; v_emi = a_emi;\n"
    "  v_nrm = mat3(u_model) * a_nrm;\n"
    "  v_wpos = (u_model * vec4(pos, 1.0)).xyz;\n"
    "  v_dist = length((u_mv * vec4(pos, 1.0)).xyz);\n"
    "}\n";

/* add-realistic-lighting: u_mode 0 is the old look (one directional light + ambient, view:fog); 1 is the
 * light list: up to 16 suns / point lights / spots with inverse-square falloff and a smooth range window,
 * a tiny ambient, exposure and an exponential tonemap. Shadows come from one depth atlas (sampler2DShadow,
 * hardware 2x2 PCF): sun cascades and spots through a matrix, point lights as six cube faces in a 3x2 block
 * (the face basis matches sx_cube_face_basis). */
static const char *mesh_fs =
    "in vec3 v_uv; in vec3 v_col; in float v_emi; in float v_dist; in vec3 v_nrm; in vec3 v_wpos;\n"
    "in vec3 v_vnrm; flat in int v_mat;\n"
    "uniform vec4 u_mat[48]; uniform float u_mtime; uniform int u_mmode; uniform sampler2D u_matcap; uniform int u_envmap;\n"
    "uniform sampler2D u_idx; uniform sampler2D u_pal; uniform int u_palrow; uniform int u_tex;\n"
    "uniform vec4 u_tint; uniform vec3 u_light; uniform float u_ambient; uniform int u_lit;\n"
    "uniform vec3 u_fogcol; uniform float u_fog; uniform int u_dither;\n"
    "uniform int u_mode; uniform int u_nl; uniform vec3 u_amb; uniform float u_expo;\n"
    "uniform vec4 u_lpos[16]; uniform vec4 u_lcol[16]; uniform vec4 u_ldir[16]; uniform vec4 u_lpar[16];\n"
    "uniform highp sampler2DShadow u_shadow; uniform mat4 u_shmat[4]; uniform vec4 u_shrect[7]; uniform float u_shbias[7];\n"
    "uniform int u_ncasc; uniform float u_shtexel; uniform int u_lidx[16];\n"
    "uniform vec3 u_eye; uniform int u_nhz; uniform int u_hzsteps; uniform int u_sky;\n"
    "uniform vec4 u_hzpos[4]; uniform vec4 u_hzcol[4]; uniform vec4 u_hzdir[4];\n"
    "out vec4 o_col;\n"
    "const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,\n"
    "                                  3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);\n"
    "const vec3 FR[6] = vec3[6](vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0), vec3(1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0),\n"
    "                           vec3(-1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0));\n"
    "const vec3 FU[6] = vec3[6](vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0),\n"
    "                           vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0));\n"
    "float tap(vec4 rect, vec2 uv, float z) {\n"
    "  vec2 m = vec2(u_shtexel) / rect.zw;\n"
    "  return texture(u_shadow, vec3(rect.xy + clamp(uv, m, 1.0 - m) * rect.zw, z));\n"
    "}\n"
    "float proj_tap(int m, int r, vec3 p) {\n"
    "  vec4 c = u_shmat[m] * vec4(p, 1.0);\n"
    "  vec3 q = c.xyz / c.w;\n"
    "  if (abs(q.x) > 1.0 || abs(q.y) > 1.0 || q.z > 1.0) return 1.0;\n"
    "  return tap(u_shrect[r], q.xy * 0.5 + 0.5, q.z * 0.5 + 0.5);\n"
    "}\n"
    "float shadow_of(int slot, vec4 lp, vec4 lc, vec3 p, vec3 n) {\n"
    "  if (slot < 2) {\n"
    "    for (int c = 0; c < 2; c++) {\n"
    "      if (c >= u_ncasc) break;\n"
    "      vec3 q = p + n * u_shbias[c];\n"
    "      vec4 k = u_shmat[c] * vec4(q, 1.0);\n"
    "      if (abs(k.x) < 0.97 && abs(k.y) < 0.97 && k.z < 1.0) return tap(u_shrect[c], k.xy * 0.5 + 0.5, k.z * 0.5 + 0.5);\n"
    "    }\n"
    "    return 1.0;\n"
    "  }\n"
    "  float dl = length(lp.xyz - p);\n"
    "  vec3 q = p + n * (u_shbias[slot] * dl + 0.02);\n"
    "  if (slot < 4) return proj_tap(slot, slot, q);\n"
    "  vec3 d = q - lp.xyz; vec3 a = abs(d);\n"
    "  int f; float ma;\n"
    "  if (a.x >= a.y && a.x >= a.z) { f = d.x > 0.0 ? 0 : 1; ma = a.x; }\n"
    "  else if (a.y >= a.z) { f = d.y > 0.0 ? 2 : 3; ma = a.y; }\n"
    "  else { f = d.z > 0.0 ? 4 : 5; ma = a.z; }\n"
    "  vec2 uv = vec2(dot(d, FR[f]), dot(d, FU[f])) / ma * 0.5 + 0.5;\n"
    "  float zn = 0.1, zf = lc.w;\n"
    "  float z = ((zf + zn) / (zf - zn) - 2.0 * zf * zn / ((zf - zn) * ma)) * 0.5 + 0.5;\n"
    "  vec4 b = u_shrect[slot];\n"
    "  vec4 r = vec4(b.x + float(f - (f / 3) * 3) * b.z / 3.0, b.y + float(f / 3) * b.w * 0.5, b.z / 3.0, b.w * 0.5);\n"
    "  return tap(r, uv, z);\n"
    "}\n"
    "// add-lighting-mood: light scattered by the air between the eye and this pixel. A point light's glow is\n"
    "// the closed-form integral of I / (d^2 + s^2) along the ray; a spot's beam is a few jittered samples\n"
    "// through its cone. Unshadowed: the ray ends at the surface, so a wall still cuts the beam.\n"
    "vec3 haze(vec3 wp, float jit) {\n"
    "  vec3 rd; float T;\n"
    "  if (u_sky == 1) { rd = normalize(wp); T = 400.0; }\n"
    "  else { vec3 dv = wp - u_eye; T = length(dv); rd = dv / max(T, 1e-4); }\n"
    "  vec3 acc = vec3(0.0);\n"
    "  for (int k = 0; k < 4; k++) {\n"
    "    if (k >= u_nhz) break;\n"
    "    vec4 lp = u_hzpos[k]; vec4 lc = u_hzcol[k]; vec4 ld = u_hzdir[k];\n"
    "    float R = lp.w; vec3 o = lp.xyz - u_eye; float b = dot(o, rd);\n"
    "    float t0 = max(b - R, 0.0), t1 = min(b + R, T);\n"
    "    if (t1 <= t0) continue;\n"
    "    float s2 = 0.0625 * R * R;\n"
    "    if (ld.w < -1.5) {\n"
    "      float H = sqrt(max(dot(o, o) - b * b, 0.0) + s2);\n"
    "      acc += lc.rgb * ((atan((t1 - b) / H) - atan((t0 - b) / H)) / H);\n"
    "    } else {\n"
    "      float dt = (t1 - t0) / float(u_hzsteps);\n"
    "      for (int i = 0; i < 8; i++) {\n"
    "        if (i >= u_hzsteps) break;\n"
    "        vec3 dv = u_eye + rd * (t0 + (float(i) + jit) * dt) - lp.xyz; float d2 = dot(dv, dv);\n"
    "        float x = d2 / (R * R);\n"
    "        if (x >= 1.0) continue;\n"
    "        float w = 1.0 - x * x;\n"
    "        float cone = smoothstep(ld.w, lc.w, dot(dv * inversesqrt(max(d2, 1e-6)), ld.xyz));\n"
    "        acc += lc.rgb * (w * w * cone / (d2 + s2) * dt);\n"
    "      }\n"
    "    }\n"
    "  }\n"
    "  return acc;\n"
    "}\n"
    "void main() {\n"
    "  vec4 base = vec4(1.0);\n"
    "  if (u_tex == 1) {\n"
    "    int i = int(texture(u_idx, v_uv.xy / v_uv.z).r * 255.0 + 0.5);\n"
    "    if (i == 0) discard;\n"
    "    base = texelFetch(u_pal, ivec2(i, u_palrow), 0);\n"
    "  }\n"
    "  if (u_tex == 2) {\n"
    "    // a soft glow: a smooth falloff in the tint's colour, no palette texels (they read as dark blocks)\n"
    "    vec2 q = v_uv.xy / v_uv.z * 2.0 - 1.0; float r2 = dot(q, q);\n"
    "    if (r2 >= 1.0) discard;\n"
    "    float f = 1.0 - r2; base = vec4(1.0, 1.0, 1.0, f * f * (u_fog > 0.0 ? exp(-u_fog * v_dist) : 1.0));\n"
    "  }\n"
    "  vec3 c = base.rgb * v_col * u_tint.rgb;\n"
    "  vec3 lit = c;\n"
    "  if (u_lit == 1 && u_mode == 0) {\n"
    "    float d = max(dot(normalize(v_nrm), normalize(u_light)), 0.0);\n"
    "    lit = c * (u_ambient + (1.0 - u_ambient) * d);\n"
    "  } else if (u_lit == 1) {\n"
    "    vec3 n = normalize(v_nrm);\n"
    "    vec3 acc = u_amb;\n"
    "    // add-material-system: the slot's kind (0 plain = the old path, bit for bit)\n"
    "    int mk = v_mat > 0 ? int(u_mat[v_mat * 6].x + 0.5) : 0;\n"
    "    vec4 m0 = u_mat[v_mat * 6], m1 = u_mat[v_mat * 6 + 1], m2 = u_mat[v_mat * 6 + 2];\n"
    "    vec4 m3 = u_mat[v_mat * 6 + 3], m4 = u_mat[v_mat * 6 + 4], m5 = u_mat[v_mat * 6 + 5];\n"
    "    vec3 V = normalize(u_eye - v_wpos); vec3 macc = vec3(0.0), sacc = vec3(0.0);\n"
    "    // add-material-system 5.2: liquid metal ripples its normal; brushed metal stretches its highlight across\n"
    "    // the brushing (a tangent round world up)\n"
    "    vec3 rip = vec3(0.0);\n"
    "    if (mk == 1 && m5.z > 0.0) {\n"
    "      rip = m5.z * vec3(sin(v_wpos.z * 1.3 + u_mtime * 2.1) + 0.5 * sin(v_wpos.y * 2.3 - u_mtime * 1.3), 0.0,\n"
    "                        cos(v_wpos.x * 1.1 - u_mtime * 1.7) + 0.5 * cos(v_wpos.y * 1.9 + u_mtime * 1.1));\n"
    "      n = normalize(n + rip);\n"
    "    }\n"
    "    vec3 tb = cross(n, vec3(0.0, 1.0, 0.0)); tb = dot(tb, tb) > 1e-4 ? normalize(tb) : vec3(1.0, 0.0, 0.0);\n"
    "    for (int j = 0; j < 16; j++) {\n"
    "      if (j >= u_nl) break;\n"
    "      int i = u_lidx[j];\n"
    "      vec4 lp = u_lpos[i]; vec4 lc = u_lcol[i];\n"
    "      vec3 L; float att = 1.0;\n"
    "      if (lp.w < 0.5) { L = lp.xyz; }\n"
    "      else {\n"
    "        vec3 dv = lp.xyz - v_wpos; float d2 = dot(dv, dv);\n"
    "        float x = d2 / (lc.w * lc.w);\n"
    "        if (x >= 1.0) continue;\n"
    "        L = dv * inversesqrt(max(d2, 1e-6));\n"
    "        float w = 1.0 - x * x;\n"
    "        att = w * w / (d2 + 0.0625 * lc.w * lc.w);\n"
    "        if (lp.w > 1.5) att *= smoothstep(u_ldir[i].w, u_lpar[i].x, dot(-L, u_ldir[i].xyz));\n"
    "      }\n"
    "      float ndl = dot(n, L);\n"
    "      float dif = mk == 3 ? (ndl + m4.w) / (1.0 + m4.w) : ndl;\n"
    "      if (att <= 0.0 || (dif <= 0.0 && mk != 3)) continue;\n"
    "      int slot = int(u_lpar[i].y);\n"
    "      float sh = slot >= 0 ? shadow_of(slot, lp, lc, v_wpos, n) : 1.0;\n"
    "      acc += lc.rgb * (max(dif, 0.0) * att * sh);\n"
    "      if (mk > 0) {\n"
    "        vec3 H = normalize(L + V); float sp = pow(max(dot(n, H), 0.0), m0.z);\n"
    "        if (m5.y > 0.0) { float th = dot(tb, H); sp = mix(sp, 0.7 * pow(sqrt(max(1.0 - th * th, 0.0)), m0.z * 0.5), m5.y); }\n"
    "        macc += lc.rgb * (att * sh * sp);\n"
    "        if (mk == 3) sacc += lc.rgb * (att * sh * (max(0.0, 1.0 - abs(ndl) * 3.0) + max(0.0, -ndl) * 0.6));\n"
    "      }\n"
    "    }\n"
    "    lit = vec3(1.0) - exp(-c * acc * u_expo);\n"
    "    if (mk > 0) {\n"
    "      // one matcap fetch: metals look along the view normal (reflection), crystals through it (refraction)\n"
    "      vec3 vn = normalize(v_vnrm + rip * 0.5);\n"
    "      vec2 mc = mk == 2 ? refract(vec3(0.0, 0.0, -1.0), vn, 0.66).xy : vn.xy;\n"
    "      float env;\n"
    "      if (u_envmap == 1) {\n"
    "        // add-material-system 5.3: outside, the sector's sky (equirectangular, world directions), still one fetch\n"
    "        vec3 R = mk == 2 ? refract(-V, n, 0.66) : reflect(-V, n);\n"
    "        env = texture(u_matcap, vec2(atan(R.z, R.x) / 6.2831853 + 0.5, acos(clamp(R.y, -1.0, 1.0)) / 3.1415927)).r;\n"
    "      } else {\n"
    "        env = texture(u_matcap, mc * 0.48 + 0.5).r;\n"
    "      }\n"
    "      float fres = m0.w + (1.0 - m0.w) * pow(1.0 - max(dot(n, V), 0.0), 5.0);\n"
    "      float lv = clamp(dot(acc, vec3(0.3, 0.5, 0.2)) * u_expo, 0.0, 1.5);\n"
    "      vec3 spec = vec3(1.0) - exp(-macc * u_expo * (0.6 + fres));\n"
    "      if (mk == 1) {\n"
    "        // metal: the reflection's brightness indexes the ramp in 8 bands, plus specular\n"
    "        float l = clamp(env * m0.y * (0.35 + 0.65 * lv) + (1.0 - m0.y) * lv * 0.5 + fres * 0.4 * (0.3 + lv), 0.0, 1.0);\n"
    "        l = floor(l * 7.0 + 0.5) / 7.0;\n"
    "        lit = mix(lit, mix(m2.rgb, m3.rgb, l), m0.y) + spec * 1.6;\n"
    "      } else if (mk == 2) {\n"
    "        // crystal: faceted body through the ramp, the lamps seen through it, a rim and its own glow\n"
    "        float l = clamp(env * m0.y + lv * 0.5, 0.0, 1.0);\n"
    "        l = floor(l * 7.0 + 0.5) / 7.0;\n"
    "        float glow = m1.x * (0.7 + 0.3 * sin(6.2831853 * u_mtime * max(m3.w, 0.05)));\n"
    "        lit = mix(lit, mix(m2.rgb, m3.rgb, l), 0.6) + m4.rgb * (fres * 1.1) + m3.rgb * glow * (0.8 + 0.7 * env) + spec * 1.3;\n"
    "        if (m5.x > 0.0) {\n"
    "          // sparkle: a few facet cells catch the light and twinkle (render time only)\n"
    "          vec3 cell = floor(v_wpos * 3.0);\n"
    "          float hsh = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);\n"
    "          float tw = max(0.0, sin(u_mtime * (2.0 + 3.0 * hsh) + hsh * 40.0));\n"
    "          lit += m4.rgb * (step(0.93, hsh) * tw * tw * m5.x * (0.4 + lv) * 2.0);\n"
    "        }\n"
    "      } else {\n"
    "        // organic: wrap light, the subsurface tint in the terminator and behind, wet sheen, vein pulse\n"
    "        float vein = 1.0 - smoothstep(0.0, 0.09, abs(sin(dot(v_wpos, vec3(0.21, 0.37, 0.27)) + 2.0 * sin(v_wpos.y * 0.11 + v_wpos.x * 0.07))));\n"
    "        float pulse = m3.w > 0.0 ? 0.5 + 0.5 * sin(6.2831853 * m3.w * u_mtime) : 0.0;\n"
    "        lit += (vec3(1.0) - exp(-m4.rgb * sacc * u_expo * 1.6)) + spec * 0.6 * m0.y + m4.rgb * (vein * m1.x * (m3.w > 0.0 ? 0.25 + pulse : 0.0) * 1.6);\n"
    "      }\n"
    "    }\n"
    "  }\n"
    "  c = mix(lit, c * 1.25, clamp(v_emi, 0.0, 1.0));\n"
    "  if (u_fog > 0.0 && u_tex != 2) c = mix(u_fogcol, c, exp(-u_fog * v_dist));\n"
    "  ivec2 p = ivec2(gl_FragCoord.xy) % 4;\n"
    "  float b = (bayer[p.y * 4 + p.x] + 0.5) / 16.0;\n"
    "  if (u_nhz > 0) c += vec3(1.0) - exp(-haze(v_wpos, b) * u_expo);\n"
    "  if (u_dither == 1) {\n"
    "    c = floor(clamp(c, 0.0, 1.0) * 31.0 + b) / 31.0;\n"
    "  }\n"
    "  float a = base.a * u_tint.a;\n"
    "  if (u_tex == 2 && u_dither == 1) a = floor(a * 15.0 + b) / 15.0;\n"
    "  if (a < 0.01) discard;\n"
    "  o_col = vec4(c, a);\n"
    "}\n";

/* add-realistic-lighting: the shadow pass writes depth only */
static const char *depth_vs =
    "in vec3 a_pos; in vec3 a_nrm; in vec2 a_uv; in vec3 a_col; in float a_emi;\n"
    "uniform mat4 u_mvp;\n"
    "void main() { gl_Position = u_mvp * vec4(a_pos, 1.0); }\n";
static const char *depth_fs = "void main() {}\n";

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
    "  } else if (u_tex == 4) {\n" /* comfort vignette: dark rim, clear centre */
    "    float d = length(v_uv - vec2(0.5)) * 2.0;\n"
    "    c = vec4(0.0, 0.0, 0.0, smoothstep(1.0 - 0.7 * u_color.a, 1.15, d) * min(1.0, u_color.a * 1.6));\n"
    "  }\n"
    "  o_col = c;\n"
    "}\n";

typedef struct prog {
  GLuint id;
  GLint mvp, mv, model, snap, affine, idx, pal, palrow, tex, tint, light, ambient, lit, fogcol, fog, dither, size, color;
  GLint mode, nl, amb, expo, lpos, lcol, ldir, lpar, shadow, shmat, shrect, shbias, ncasc, shtexel, lidx;
  GLint eye, nhz, hzsteps, sky, hzpos, hzcol, hzdir;
  GLint mat, mtime, mmode, matcap, envmap; /* add-material-system */
} prog;

static struct {
  int ok;
  prog mesh, ui, depth;
  GLuint shadow_tex, shadow_fbo; /* add-realistic-lighting: the depth atlas */
  int shadow_size;
  float *spheres;                /* per mesh of the view being drawn: world bounding sphere (x, y, z, r) */
  float omni_key[SX_SHADOW_OMNI][4]; /* the point light whose faces each omni block holds */
  unsigned omni_turn, omni_drawn;
  float lsph[SX_MAX_ACTIVE_LIGHTS][4]; /* the view's active lights: pos + range (-1: a sun, reaches all) */
  int nview_lights, last_lmask;
  int view_hz; /* add-lighting-mood: glowing lights of the view being drawn */
  int cap_spheres;
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
    glBindAttribLocation(p->id, 5, "a_mat");
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
  U(mvp); U(mv); U(model); U(snap); U(affine); U(idx); U(pal); U(palrow); U(tex); U(tint); U(light); U(ambient); U(lit);
  U(fogcol); U(fog); U(dither); U(size); U(color);
  U(mode); U(nl); U(amb); U(expo); U(lpos); U(lcol); U(ldir); U(lpar); U(shadow); U(shmat); U(shrect); U(shbias);
  U(ncasc); U(shtexel); U(lidx);
  U(eye); U(nhz); U(hzsteps); U(sky); U(hzpos); U(hzcol); U(hzdir);
  U(mat); U(mtime); U(mmode); U(matcap); U(envmap);
#undef U
  glUseProgram(p->id);
  glUniform1i(p->idx, 0);
  glUniform1i(p->pal, 1);
  if (p->shadow >= 0) glUniform1i(p->shadow, 2);
  if (p->matcap >= 0) glUniform1i(p->matcap, 3);
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
  glEnableVertexAttribArray(5);
  glVertexAttribPointer(5, 1, GL_FLOAT, GL_FALSE, st, (void *)(12 * sizeof(float)));
}

static void tex_params(GLint filter, GLint wrap) {
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap);
}

static void ensure_shadow(int size);

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
  if (!link_prog(&G.mesh, mesh_vs, mesh_fs, 0) || !link_prog(&G.ui, ui_vs, ui_fs, 1) ||
      !link_prog(&G.depth, depth_vs, depth_fs, 0))
    return 0;
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
  ensure_shadow(1);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
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
  if (G.shadow_fbo) glDeleteFramebuffers(1, &G.shadow_fbo);
  if (G.shadow_tex) glDeleteTextures(1, &G.shadow_tex);
  free(G.spheres);
  G.spheres = NULL;
  G.cap_spheres = 0;
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


/* ------------------------------------------------- add-realistic-lighting */
static void ensure_shadow(int size) {
  static const GLenum none = GL_NONE;
  if (size < 1) size = 1; /* a 1x1 map keeps the shadow sampler valid (WebGL checks it on every draw) */
  if (G.shadow_tex && G.shadow_size == size) return;
  if (!G.shadow_tex) glGenTextures(1, &G.shadow_tex);
  if (!G.shadow_fbo) glGenFramebuffers(1, &G.shadow_fbo);
  glActiveTexture(GL_TEXTURE2);
  glBindTexture(GL_TEXTURE_2D, G.shadow_tex);
  tex_params(GL_LINEAR, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, size, size, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL);
  glBindFramebuffer(GL_FRAMEBUFFER, G.shadow_fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, G.shadow_tex, 0);
  glDrawBuffers(1, &none);
  glReadBuffer(GL_NONE);
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) SX_ERROR("shadow atlas framebuffer incomplete");
  glActiveTexture(GL_TEXTURE0);
  G.shadow_size = size;
}

/* world bounding sphere of every mesh in the view (for culling shadow casters) */
static void view_spheres(const sx_render *r, const sx_viewport *v) {
  int i, k;
  if (v->nmeshes > G.cap_spheres) {
    G.cap_spheres = v->nmeshes * 2;
    G.spheres = (float *)realloc(G.spheres, sizeof(float) * 4 * (size_t)G.cap_spheres);
  }
  for (i = 0; i < v->nmeshes; i++) {
    const sx_draw_mesh *d = &v->meshes[i];
    float *o = &G.spheres[i * 4], c[3], h[3], sc = 0;
    const sx_mesh *m;
    o[3] = -1.0f; /* not a caster */
    if (d->mesh <= 0 || d->mesh >= SX_MAX_MESHES || !r->meshes[d->mesh].used) continue;
    if (d->flags & (SX_DRAW_SKY | SX_DRAW_GHOST | SX_DRAW_UNLIT | SX_DRAW_NOSHADOW)) continue;
    m = &r->meshes[d->mesh].mesh;
    for (k = 0; k < 3; k++) {
      c[k] = (m->bmin[k] + m->bmax[k]) * 0.5f;
      h[k] = (m->bmax[k] - m->bmin[k]) * 0.5f;
    }
    for (k = 0; k < 3; k++) {
      float l2 = d->model[k * 4] * d->model[k * 4] + d->model[k * 4 + 1] * d->model[k * 4 + 1] +
                 d->model[k * 4 + 2] * d->model[k * 4 + 2];
      if (l2 > sc) sc = l2;
    }
    for (k = 0; k < 3; k++) o[k] = d->model[k] * c[0] + d->model[4 + k] * c[1] + d->model[8 + k] * c[2] + d->model[12 + k];
    o[3] = (float)sx_sqrt((double)((h[0] * h[0] + h[1] * h[1] + h[2] * h[2]) * sc));
  }
}

/* ortho: a sun cascade of half-size ortho (m) - casters outside its box (or beyond its far end) are skipped */
static void draw_casters(const sx_viewport *v, const float vp[16], const float *ball, const float *face, int owner,
                         float ortho) {
  int i;
  for (i = 0; i < v->nmeshes; i++) {
    const sx_draw_mesh *d = &v->meshes[i];
    const float *s = &G.spheres[i * 4];
    float mvp[16];
    if (s[3] < 0.0f || (owner && d->owner == owner) || !G.mesh_vao[d->mesh]) continue;
    if (ortho > 0.0f) {
      float x = vp[0] * s[0] + vp[4] * s[1] + vp[8] * s[2] + vp[12];
      float y = vp[1] * s[0] + vp[5] * s[1] + vp[9] * s[2] + vp[13];
      float z = vp[2] * s[0] + vp[6] * s[1] + vp[10] * s[2] + vp[14];
      float m = 1.0f + s[3] / ortho;
      if (x > m || x < -m || y > m || y < -m || z > 1.0f + s[3] / 1500.0f) continue;
    }
    if (ball) {
      float dx = s[0] - ball[0], dy = s[1] - ball[1], dz = s[2] - ball[2], rr = s[3] + ball[3];
      if (dx * dx + dy * dy + dz * dz > rr * rr) continue;
      if (face) { /* outside one of the face frustum's five planes (unit normals, through the light) */
        int k;
        for (k = 0; k < 5; k++)
          if (dx * face[k * 3] + dy * face[k * 3 + 1] + dz * face[k * 3 + 2] < -s[3]) break;
        if (k < 5) continue;
      }
    }
    sx_mat4_mul(mvp, vp, d->model);
    glUniformMatrix4fv(G.depth.mvp, 1, GL_FALSE, mvp);
    glBindVertexArray(G.mesh_vao[d->mesh]);
    glDrawElements(GL_TRIANGLES, G.mesh_count[d->mesh], GL_UNSIGNED_INT, (void *)0);
  }
}

static void shadow_tile(const float rect[4], int size) {
  int x = (int)(rect[0] * (float)size + 0.5f), y = (int)(rect[1] * (float)size + 0.5f);
  int w = (int)(rect[2] * (float)size + 0.5f), h = (int)(rect[3] * (float)size + 0.5f);
  glViewport(x, y, w, h);
  glScissor(x, y, w, h);
  glClear(GL_DEPTH_BUFFER_BIT);
}

/* renders every shadow map the view's selection asked for into the atlas */
static void draw_shadows(const sx_render *r, const sx_viewport *v) {
  const sx_lighting *lt = &v->lighting;
  int k, f, size = lt->atlas, cache = r->nviews == 1, refresh;
  if (!lt->on || size <= 0 || (!lt->cascades && !lt->spots && !lt->omni)) return;
  if (G.shadow_size != size || !cache) {
    for (k = 0; k < SX_SHADOW_OMNI; k++) G.omni_key[k][3] = -1.0f;
  }
  ensure_shadow(size);
  refresh = lt->omni > 0 ? (int)(G.omni_turn++ % (unsigned)lt->omni) : -1;
  view_spheres(r, v);
  glBindFramebuffer(GL_FRAMEBUFFER, G.shadow_fbo);
  glUseProgram(G.depth.id);
  glEnable(GL_SCISSOR_TEST);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LEQUAL);
  glDepthMask(GL_TRUE);
  glDisable(GL_BLEND);
  glDisable(GL_CULL_FACE);
  glEnable(GL_POLYGON_OFFSET_FILL);
  glPolygonOffset(1.5f, 3.0f);
  for (k = 0; k < lt->nactive; k++) {
    const sx_light *l = &lt->lights[lt->active[k]];
    if (l->slot < 0) continue;
    if (l->kind == SX_LIGHT_SUN) {
      int c;
      for (c = 0; c < lt->cascades; c++) {
        shadow_tile(lt->shadow_rect[c], size);
        draw_casters(v, lt->shadow_mat[c], NULL, NULL, l->owner, lt->casc_radius[c]);
      }
    } else if (l->kind == SX_LIGHT_SPOT) {
      float ball[4];
      int j, twin = 0;
      for (j = 0; j < k; j++)
        if (lt->lights[lt->active[j]].slot == l->slot) twin = 1;
      if (twin) continue; /* a headlight pair: the first drew the map */
      ball[0] = l->pos[0];
      ball[1] = l->pos[1];
      ball[2] = l->pos[2];
      ball[3] = l->range;
      shadow_tile(lt->shadow_rect[l->slot], size);
      draw_casters(v, lt->shadow_mat[l->slot], ball, NULL, l->owner, 0.0f);
    } else {
      float ball[4], proj[16], view[16], vp[16], rect[4];
      int j = l->slot - SX_SHADOW_CASCADES - SX_SHADOW_SPOTS;
      int same = cache && G.omni_key[j][0] == l->pos[0] && G.omni_key[j][1] == l->pos[1] &&
                 G.omni_key[j][2] == l->pos[2] && G.omni_key[j][3] == l->range;
      /* a single view keeps a point light's map while the light holds its block; one block a frame is
         redrawn anyway (round robin) so moving casters catch up */
      if (same && j != refresh) continue;
      G.omni_key[j][0] = l->pos[0];
      G.omni_key[j][1] = l->pos[1];
      G.omni_key[j][2] = l->pos[2];
      G.omni_key[j][3] = l->range;
      G.omni_drawn++;
      ball[0] = l->pos[0];
      ball[1] = l->pos[1];
      ball[2] = l->pos[2];
      ball[3] = l->range;
      sx_mat4_perspective(proj, (float)(SX_PI * 0.5), 1.0f, 0.1f, l->range);
      for (f = 0; f < 6; f++) {
        float F[3], R[3], U[3], planes[15];
        int j;
        sx_cube_face_basis(f, F, R, U);
        for (j = 0; j < 3; j++) {
          planes[j] = F[j];
          planes[3 + j] = (F[j] - R[j]) * 0.70710678f;
          planes[6 + j] = (F[j] + R[j]) * 0.70710678f;
          planes[9 + j] = (F[j] - U[j]) * 0.70710678f;
          planes[12 + j] = (F[j] + U[j]) * 0.70710678f;
        }
        sx_cube_face_view(l->pos, f, view);
        sx_mat4_mul(vp, proj, view);
        sx_shadow_face_rect(lt->shadow_rect[l->slot], f, rect);
        shadow_tile(rect, size);
        draw_casters(v, vp, ball, planes, l->owner, 0.0f);
      }
    }
  }
  glDisable(GL_POLYGON_OFFSET_FILL);
  glBindVertexArray(0);
}

/* the view's light list and shadow data into the mesh program */
static void set_lights(const sx_viewport *v) {
  const sx_lighting *lt = &v->lighting;
  float lpos[16][4], lcol[16][4], ldir[16][4], lpar[16][4], rect[SX_SHADOW_RECTS][4], bias[SX_SHADOW_RECTS];
  float mats[4][16];
  int k, n = lt->on ? lt->nactive : 0, size = lt->atlas > 0 ? lt->atlas : 1;
  glUniform1i(G.mesh.mode, lt->on ? 1 : 0);
  glUniform1i(G.mesh.nl, 0);
  G.nview_lights = n;
  G.last_lmask = -1;
  if (!lt->on) return;
  memset(lpos, 0, sizeof lpos);
  memset(ldir, 0, sizeof ldir);
  memset(lpar, 0, sizeof lpar);
  memset(lcol, 0, sizeof lcol);
  for (k = 0; k < n; k++) {
    const sx_light *l = &lt->lights[lt->active[k]];
    int j;
    for (j = 0; j < 3; j++) {
      lpos[k][j] = l->kind == SX_LIGHT_SUN ? l->dir[j] : l->pos[j];
      lcol[k][j] = l->color[j] * l->intensity;
      ldir[k][j] = l->dir[j];
    }
    lpos[k][3] = (float)l->kind;
    lcol[k][3] = l->range;
    ldir[k][3] = l->cos_outer;
    lpar[k][0] = l->cos_inner;
    lpar[k][1] = (float)l->slot;
    G.lsph[k][0] = l->pos[0];
    G.lsph[k][1] = l->pos[1];
    G.lsph[k][2] = l->pos[2];
    G.lsph[k][3] = l->kind == SX_LIGHT_SUN ? -1.0f : l->range;
  }
  glUniform4fv(G.mesh.lpos, 16, &lpos[0][0]);
  glUniform4fv(G.mesh.lcol, 16, &lcol[0][0]);
  glUniform4fv(G.mesh.ldir, 16, &ldir[0][0]);
  glUniform4fv(G.mesh.lpar, 16, &lpar[0][0]);
  glUniform3f(G.mesh.amb, lt->ambient[0], lt->ambient[1], lt->ambient[2]);
  glUniform1f(G.mesh.expo, lt->exposure);
  memcpy(rect, lt->shadow_rect, sizeof rect);
  memcpy(mats, lt->shadow_mat, sizeof mats);
  for (k = 0; k < SX_SHADOW_RECTS; k++) {
    /* normal offset: about 1.5 texels of the map (sun: metres; spots and faces: per metre of distance) */
    if (k < SX_SHADOW_CASCADES) bias[k] = 3.0f * lt->casc_radius[k] / (float)(size / 2 > 0 ? size / 2 : 1);
    else if (k < SX_SHADOW_CASCADES + SX_SHADOW_SPOTS) bias[k] = 3.0f / (float)(size / 4 > 0 ? size / 4 : 1);
    else bias[k] = 3.0f / (float)(size / 8 > 0 ? size / 8 : 1);
  }
  glUniformMatrix4fv(G.mesh.shmat, 4, GL_FALSE, &mats[0][0]);
  glUniform4fv(G.mesh.shrect, SX_SHADOW_RECTS, &rect[0][0]);
  glUniform1fv(G.mesh.shbias, SX_SHADOW_RECTS, bias);
  glUniform1i(G.mesh.ncasc, lt->cascades);
  glUniform1f(G.mesh.shtexel, 1.0f / (float)size);
  glActiveTexture(GL_TEXTURE2);
  glBindTexture(GL_TEXTURE_2D, G.shadow_tex);
  glActiveTexture(GL_TEXTURE0);
}

/* add-lighting-mood: the view's glowing lights (beams and halos) and the eye they are seen from */
static void set_haze(const sx_viewport *v, const float view[16]) {
  const sx_lighting *lt = &v->lighting;
  float hp[SX_MAX_HAZE][4], hc[SX_MAX_HAZE][4], hd[SX_MAX_HAZE][4], eye[3];
  int k, j, n = lt->on ? lt->nhz : 0;
  for (j = 0; j < 3; j++) eye[j] = -(view[j * 4] * view[12] + view[j * 4 + 1] * view[13] + view[j * 4 + 2] * view[14]);
  glUniform3f(G.mesh.eye, eye[0], eye[1], eye[2]);
  G.view_hz = n;
  glUniform1i(G.mesh.nhz, n);
  if (n <= 0) return;
  memset(hp, 0, sizeof hp);
  memset(hc, 0, sizeof hc);
  memset(hd, 0, sizeof hd);
  for (k = 0; k < n; k++) {
    const sx_light *l = &lt->lights[lt->hz[k]];
    float s = l->intensity * l->haze * lt->haze_density;
    for (j = 0; j < 3; j++) {
      hp[k][j] = l->pos[j];
      hc[k][j] = l->color[j] * s;
      hd[k][j] = l->dir[j];
    }
    hp[k][3] = l->range;
    hc[k][3] = l->cos_inner;
    hd[k][3] = l->kind == SX_LIGHT_SPOT ? l->cos_outer : -2.0f;
  }
  glUniform1i(G.mesh.hzsteps, lt->haze_steps > 0 ? lt->haze_steps : 1);
  glUniform4fv(G.mesh.hzpos, SX_MAX_HAZE, &hp[0][0]);
  glUniform4fv(G.mesh.hzcol, SX_MAX_HAZE, &hc[0][0]);
  glUniform4fv(G.mesh.hzdir, SX_MAX_HAZE, &hd[0][0]);
}

/* add-material-system: the view's material slots, render time and matcap (texture unit 3) */
static void set_materials(const sx_render *r, const sx_viewport *v) {
  float packed[SX_MAT_SLOTS * SX_MAT_VEC4 * 4];
  const sx_materials *ms = &v->materials;
  int mode = ms->on ? r->settings.materials : SX_MATERIALS_OFF;
  int n = sx_materials_pack(ms, mode, packed);
  glUniform4fv(G.mesh.mat, SX_MAT_SLOTS * SX_MAT_VEC4, packed);
  glUniform1f(G.mesh.mtime, ms->time);
  glUniform1i(G.mesh.mmode, n > 0 ? mode : 0);
  glUniform1i(G.mesh.envmap, ms->envmap ? 1 : 0);
  glActiveTexture(GL_TEXTURE3);
  glBindTexture(GL_TEXTURE_2D, (ms->matcap > 0 && ms->matcap < SX_MAX_TEXTURES && r->textures[ms->matcap].used &&
                                G.tex[ms->matcap]) ? G.tex[ms->matcap] : G.white_tex);
  glActiveTexture(GL_TEXTURE0);
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

static void set_common(const sx_viewport *v, const sx_render *r, int xr) {
  sx_effects fx = sx_render_effects(&r->settings, xr);
  glUniform3f(G.mesh.light, v->light_dir[0], v->light_dir[1], v->light_dir[2]);
  glUniform1f(G.mesh.ambient, v->ambient);
  glUniform3f(G.mesh.fogcol, v->fog_color[0], v->fog_color[1], v->fog_color[2]);
  glUniform1i(G.mesh.dither, fx.dither);
  glUniform1i(G.mesh.affine, fx.affine);
  if (fx.snap) glUniform2f(G.mesh.snap, (float)v->w * 0.5f, (float)v->h * 0.5f);
  else glUniform2f(G.mesh.snap, 0, 0);
}


/* add-realistic-lighting: only the lights whose range reaches a mesh's bounding sphere shade it */
static void mesh_lights(const sx_render *r, const sx_draw_mesh *d) {
  GLint idx[SX_MAX_ACTIVE_LIGHTS];
  float c[3], h[3], sc = 0, rad;
  const sx_mesh *m = &r->meshes[d->mesh].mesh;
  int k, n = 0, mask = 0;
  for (k = 0; k < 3; k++) {
    float l2 = d->model[k * 4] * d->model[k * 4] + d->model[k * 4 + 1] * d->model[k * 4 + 1] +
               d->model[k * 4 + 2] * d->model[k * 4 + 2];
    h[k] = (m->bmax[k] - m->bmin[k]) * 0.5f;
    if (l2 > sc) sc = l2;
  }
  for (k = 0; k < 3; k++)
    c[k] = d->model[k] * (m->bmin[0] + m->bmax[0]) * 0.5f + d->model[4 + k] * (m->bmin[1] + m->bmax[1]) * 0.5f +
           d->model[8 + k] * (m->bmin[2] + m->bmax[2]) * 0.5f + d->model[12 + k];
  rad = (float)sx_sqrt((double)((h[0] * h[0] + h[1] * h[1] + h[2] * h[2]) * sc));
  for (k = 0; k < G.nview_lights; k++) {
    const float *l = G.lsph[k];
    if (l[3] >= 0.0f) {
      float dx = c[0] - l[0], dy = c[1] - l[1], dz = c[2] - l[2], rr = rad + l[3];
      if (dx * dx + dy * dy + dz * dz > rr * rr) continue;
    }
    idx[n++] = k;
    mask |= 1 << k;
  }
  if (mask != G.last_lmask) {
    glUniform1iv(G.mesh.lidx, n > 0 ? n : 1, idx);
    G.last_lmask = mask;
  }
  glUniform1i(G.mesh.nl, n);
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
  glUniform1i(G.mesh.sky, (d->flags & SX_DRAW_SKY) ? 1 : 0);
  if (G.nview_lights > 0 && !(d->flags & (SX_DRAW_UNLIT | SX_DRAW_SKY))) mesh_lights(r, d);
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
    int soft = b->tex > 0 && b->tex < SX_MAX_TEXTURES && r->textures[b->tex].used && r->textures[b->tex].soft;
    /* a bright glow adds light (it can never darken what is behind it); a dark one (a shade) still blends */
    int add = soft && b->tint[0] + b->tint[1] + b->tint[2] > 0.36f;
    if (b->yaxis && !soft) {
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
      p[12] = 0; /* plain material */
    }
    glUniform4f(G.mesh.tint, b->tint[0], b->tint[1], b->tint[2], b->tint[3]);
    glUniform1i(G.mesh.palrow, pal_row(r, b->palette));
    glUniform1i(G.mesh.tex, soft ? 2 : 1);
    if (add) {
      glBlendFunc(GL_SRC_ALPHA, GL_ONE);
      glDepthMask(GL_FALSE);
    }
    bind_tex(r, b->tex);
    glBufferData(GL_ARRAY_BUFFER, sizeof vtx, vtx, GL_STREAM_DRAW);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    if (add) {
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glDepthMask(GL_TRUE);
    }
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
    } else if (u->kind == 3) {
      glUniform1i(G.ui.tex, 4);
      ui_quad(u->x, u->y, u->w, u->h, 0, 0, 1, 1);
    } else {
      glUniform1i(G.ui.tex, 1);
      glUniform1i(G.ui.palrow, pal_row(r, u->palette));
      bind_tex(r, u->tex);
      ui_quad(u->x, u->y, u->w, u->h, 0, 0, 1, 1);
    }
  }
}

static void draw_view(const sx_render *r, const sx_viewport *v, int fb_h, int xr, GLuint target) {
  frame_mats fm;
  int i, pass;
  int gy = xr ? v->y : fb_h - v->y - v->h; /* views are laid out top-down */
  if (v->lighting.on && v->lighting.atlas > 0 && (v->lighting.cascades || v->lighting.spots || v->lighting.omni)) {
    draw_shadows(r, v);
    glBindFramebuffer(GL_FRAMEBUFFER, target);
  }
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
  set_common(v, r, xr);
  set_lights(v);
  set_haze(v, fm.view);
  set_materials(r, v);
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
      glUniform1i(G.mesh.nhz, 0); /* a glow sprite is not lit air: it would add the haze twice */
      draw_billboards(r, v, &fm);
      glUniform1i(G.mesh.nhz, G.view_hz);
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
  for (i = 0; i < r->nviews; i++) draw_view(r, &r->views[i], h, 0, G.fbo);
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
  if (r->settings.fill) { /* add-mobile-touch-ux: the target already has the window's aspect */
    dw = (float)win_w;
    dh = (float)win_h;
  }
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
  for (i = 0; i < r->nviews; i++) draw_view(r, &r->views[i], 0, 1, (GLuint)fb);
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
