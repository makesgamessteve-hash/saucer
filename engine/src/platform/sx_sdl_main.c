/* Game binary: SDL3 window, GL context, input devices, fixed-step loop.
 * Windows / Linux natively; Web (WebGL2 + WebXR) through emscripten.
 * SPDX-License-Identifier: MIT */
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sx_fs.h"
#include "sx_log.h"
#include "sx_platform.h"
#include "sx_ser.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STBI_WRITE_NO_STDIO
#include "stb_image_write.h"
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include "sx_net.h"
#endif

typedef struct app {
  SDL_Window *win;
  SDL_GLContext gl;
  sx_engine *e;
  Uint64 last;
  double acc;
  double ssum, rsum, psum;       /* --frame-stats: summed ms in sx_engine_render (script + GL calls) and in present */
  double *fms, *wms;       /* total wall ms per frame, and the part that is the game's own work (sim + render) */
              /* --frame-stats: wall ms of each frame after the warm-up */
  int nfms, nframes;
  sx_pace pace;            /* --realtime: wall clock schedule of a fixed-step run */
  int running, status;
  int fixed_step;          /* one tick per frame (screenshots, slow CI GPUs) */
  int shot_done;
  char net_title[160];
  SDL_JoystickID pads[SX_MAX_PADS];
  SDL_Gamepad *pad_handles[SX_MAX_PADS];
  float safe[4]; /* add-mobile-touch-ux: safe-area insets in CSS px (left, top, right, bottom), from the page */
  float img[4];  /* where the game image sits in the window (logical px): x, y, w, h */
} app;

static app A;

/* add-mobile-touch-ux: size the low-res target to the window (--fill) and
 * fit the touch controls to the image, its safe area and the HUD. Fingers
 * held through a resize or a rotation are let go. */
static void touch_relayout(void) {
  sx_engine *e = A.e;
  sx_touch_metrics m;
  int lw, lh, tw, th;
  float s;
  if (!e) return;
  SDL_GetWindowSize(A.win, &lw, &lh);
  if (lw < 1) lw = 1;
  if (lh < 1) lh = 1;
  if (e->render.settings.fill) {
    sx_touch_fit_target(lw, lh, &tw, &th);
    e->render.settings.width = tw;
    e->render.settings.height = th;
    A.img[0] = A.img[1] = 0;
    A.img[2] = (float)lw;
    A.img[3] = (float)lh;
  } else {
    tw = e->render.settings.width;
    th = e->render.settings.height;
    s = (float)lw / (float)tw < (float)lh / (float)th ? (float)lw / (float)tw : (float)lh / (float)th;
    A.img[2] = (float)tw * s;
    A.img[3] = (float)th * s;
    A.img[0] = ((float)lw - A.img[2]) * 0.5f;
    A.img[1] = ((float)lh - A.img[3]) * 0.5f;
  }
  memset(&m, 0, sizeof m);
  m.w = A.img[2];
  m.h = A.img[3];
  m.hud_w = e->render.settings.width;
  m.hud_h = e->render.settings.height;
  m.safe[0] = A.safe[0] - A.img[0];
  m.safe[1] = A.safe[1] - A.img[1];
  m.safe[2] = A.safe[2] - ((float)lw - A.img[0] - A.img[2]);
  m.safe[3] = A.safe[3] - ((float)lh - A.img[1] - A.img[3]);
  sx_touch_layout(&e->touch, &m);
}

/* a finger's window-normalized point -> normalized over the game image */
static float touch_x(float x) {
  int lw, lh;
  SDL_GetWindowSize(A.win, &lw, &lh);
  return A.img[2] > 0 ? (x * (float)lw - A.img[0]) / A.img[2] : x;
}
static float touch_y(float y) {
  int lw, lh;
  SDL_GetWindowSize(A.win, &lw, &lh);
  return A.img[3] > 0 ? (y * (float)lh - A.img[1]) / A.img[3] : y;
}

static void png_sink(void *ctx, void *data, int size) { sx_buf_put((sx_buf *)ctx, data, (size_t)size); }

static int save_png(const char *path, int w, int h) {
  unsigned char *px = sx_gl_read_pixels(w, h);
  sx_buf b = {0};
  int ok = 0;
  if (!px) return 0;
  if (stbi_write_png_to_func(png_sink, &b, w, h, 4, px, w * 4)) {
    char *dir = sx_path_dir(path);
    sx_fs_mkdirs(dir);
    free(dir);
    ok = sx_fs_write_atomic(path, b.data, b.len);
  }
  free(px);
  sx_buf_free(&b);
  if (ok) SX_INFO("screenshot written to %s", path);
  else SX_ERROR("cannot write screenshot %s", path);
  return ok;
}

static int pad_slot(SDL_JoystickID id) {
  int i;
  for (i = 0; i < SX_MAX_PADS; i++)
    if (A.pad_handles[i] && A.pads[i] == id) return i;
  return -1;
}

static void handle_event(const SDL_Event *ev) {
  sx_engine *e = A.e;
  sx_raw_input *raw = &e->input.raw;
  int s;
  switch (ev->type) {
  case SDL_EVENT_QUIT: A.running = 0; break;
  case SDL_EVENT_KEY_DOWN:
  case SDL_EVENT_KEY_UP:
    if (ev->key.scancode < 512) raw->keys[ev->key.scancode] = ev->type == SDL_EVENT_KEY_DOWN;
    if (ev->type == SDL_EVENT_KEY_DOWN && ev->key.scancode == SDL_SCANCODE_ESCAPE)
      SDL_SetWindowRelativeMouseMode(A.win, false);
    if (ev->type == SDL_EVENT_KEY_DOWN && ev->key.scancode == SDL_SCANCODE_F11)
      SDL_SetWindowFullscreen(A.win, !(SDL_GetWindowFlags(A.win) & SDL_WINDOW_FULLSCREEN));
    break;
  case SDL_EVENT_MOUSE_BUTTON_DOWN:
  case SDL_EVENT_MOUSE_BUTTON_UP:
    if (ev->button.which == SDL_TOUCH_MOUSEID) break; /* touch is handled as touch */
    if (ev->button.button < 8) raw->mouse_btn[ev->button.button] = ev->type == SDL_EVENT_MOUSE_BUTTON_DOWN;
    if (ev->type == SDL_EVENT_MOUSE_BUTTON_DOWN && !e->touch.active) SDL_SetWindowRelativeMouseMode(A.win, true);
    break;
  case SDL_EVENT_MOUSE_MOTION:
    if (ev->motion.which == SDL_TOUCH_MOUSEID || !SDL_GetWindowRelativeMouseMode(A.win)) break;
    raw->mouse_axis[0] += ev->motion.xrel;
    raw->mouse_axis[1] += ev->motion.yrel;
    break;
  case SDL_EVENT_MOUSE_WHEEL: raw->mouse_axis[2] += ev->wheel.y; break;
  case SDL_EVENT_GAMEPAD_ADDED:
    if (pad_slot(ev->gdevice.which) >= 0) break;
    for (s = 0; s < SX_MAX_PADS && A.pad_handles[s]; s++) {
    }
    if (s == SX_MAX_PADS) break;
    A.pad_handles[s] = SDL_OpenGamepad(ev->gdevice.which);
    if (A.pad_handles[s]) {
      A.pads[s] = ev->gdevice.which;
      sx_input_pad_connected(&e->input, s, 1);
      SX_INFO("gamepad %d: %s", s, SDL_GetGamepadName(A.pad_handles[s]));
    }
    break;
  case SDL_EVENT_GAMEPAD_REMOVED:
    s = pad_slot(ev->gdevice.which);
    if (s < 0) break;
    SDL_CloseGamepad(A.pad_handles[s]);
    A.pad_handles[s] = NULL;
    sx_input_pad_connected(&e->input, s, 0);
    break;
  case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
  case SDL_EVENT_GAMEPAD_BUTTON_UP:
    s = pad_slot(ev->gbutton.which);
    if (s >= 0 && ev->gbutton.button < 32) raw->pad_btn[s][ev->gbutton.button] = ev->gbutton.down;
    break;
  case SDL_EVENT_GAMEPAD_AXIS_MOTION:
    s = pad_slot(ev->gaxis.which);
    if (s >= 0 && ev->gaxis.axis < 8) raw->pad_axis[s][ev->gaxis.axis] = (float)ev->gaxis.value / 32767.0f;
    break;
  case SDL_EVENT_FINGER_DOWN:
    sx_touch_down(&e->touch, (long long)ev->tfinger.fingerID, touch_x(ev->tfinger.x), touch_y(ev->tfinger.y));
#ifdef __EMSCRIPTEN__
    if (e->touch.buzz) {
      /* add-presentation-packaging: a short tick under the thumb on button presses */
      EM_ASM({ if (navigator.vibrate) navigator.vibrate(12); });
      e->touch.buzz = 0;
    }
#endif
    break;
  case SDL_EVENT_FINGER_MOTION:
    sx_touch_move(&e->touch, (long long)ev->tfinger.fingerID, touch_x(ev->tfinger.x), touch_y(ev->tfinger.y));
    break;
  case SDL_EVENT_FINGER_UP:
  case SDL_EVENT_FINGER_CANCELED: sx_touch_up(&e->touch, (long long)ev->tfinger.fingerID); break;
  case SDL_EVENT_WINDOW_RESIZED:
  case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED: touch_relayout(); break; /* rotation and resize */
  case SDL_EVENT_WINDOW_FOCUS_LOST:
    memset(raw->keys, 0, sizeof raw->keys);
    memset(raw->mouse_btn, 0, sizeof raw->mouse_btn);
    break;
  default: break;
  }
}

static void present(void) {
  sx_engine *e = A.e;
  int w, h;
  SDL_GetWindowSizeInPixels(A.win, &w, &h);
  sx_gl_draw(&e->render, w, h);
  if (e->opt.screenshot[0] && !A.shot_done && e->tick >= e->opt.screenshot_tick) {
    A.shot_done = 1;
    if (!save_png(e->opt.screenshot, w, h)) A.status = 1;
    A.running = 0; /* --screenshot is for automated captures: exit afterwards */
  }
  if (e->shot_pending) {
    e->shot_pending = 0;
    save_png(e->shot_path, w, h);
  }
#if !defined(__EMSCRIPTEN__)
  /* add-home-among-stars: a network game says where it stands in the title
   * (the web shell shows it in its own status bar) */
  if (e->net_on && strcmp(A.net_title, e->net.status) != 0) {
    char t[200];
    snprintf(A.net_title, sizeof A.net_title, "%s", e->net.status);
    snprintf(t, sizeof t, "Saucer - %s - network %s", e->net.role == SX_NET_HOST ? "host" : "guest", e->net.status);
    SDL_SetWindowTitle(A.win, t);
  }
#endif
  SDL_GL_SwapWindow(A.win);
}

/* --realtime: a fixed-step scripted run sleeps off the rest of each frame's
 * n/60 s, so a recording plays at the speed of the game, not of the GPU. */
#define FRAME_WARMUP 30 /* --frame-stats skips start-up and the first generation */
#define FRAME_STATS_MAX 200000

static void pace_frame(int ticks) {
  double wait;
  if (!A.fixed_step || !A.e->opt.realtime) return;
  wait = sx_pace_wait(&A.pace, (double)SDL_GetPerformanceCounter() / (double)SDL_GetPerformanceFrequency(), ticks);
  if (wait > 0) SDL_DelayNS((Uint64)(wait * 1e9));
}

static void frame(void) {
  sx_engine *e = A.e;
  SDL_Event ev;
  Uint64 now, tr0, tr1;
  int n, i, ran = 0;
  while (SDL_PollEvent(&ev)) handle_event(&ev);
  if (e->xr.session && !e->xr.mocked) return; /* the XR frame loop drives the game while immersive */
  now = SDL_GetPerformanceCounter();
  /* playtest-1: long windowed playtests draw one frame every few ticks; a
   * screenshot a script asks for is still taken right after its tick */
  n = A.fixed_step ? (e->opt.ticks_per_frame > 1 ? e->opt.ticks_per_frame : 1) : sx_ticks_for_frame(&A.acc, (double)(now - A.last) / (double)SDL_GetPerformanceFrequency());
  A.last = now;
  for (i = 0; i < n; i++) {
    if (i > 0 && (e->shot_pending || e->test_done || e->failed)) break;
    sx_engine_tick(e);
    ran++;
  }
  tr0 = SDL_GetPerformanceCounter();
  sx_engine_render(e, A.fixed_step ? 1.0 : A.acc * SX_TICK_HZ);
  tr1 = SDL_GetPerformanceCounter();
  sx_audio_flush(e);
  present();
  if (e->opt.frame_stats) {
    Uint64 t1 = SDL_GetPerformanceCounter();
    if (++A.nframes > FRAME_WARMUP && A.nfms < FRAME_STATS_MAX) {
      if (!A.fms) A.fms = (double *)malloc(sizeof(double) * FRAME_STATS_MAX);
      A.ssum += (double)(tr0 - now) * 1000.0 / (double)SDL_GetPerformanceFrequency();
      A.rsum += (double)(tr1 - tr0) * 1000.0 / (double)SDL_GetPerformanceFrequency();
      A.psum += (double)(t1 - tr1) * 1000.0 / (double)SDL_GetPerformanceFrequency();
      if (!A.wms) A.wms = (double *)malloc(sizeof(double) * FRAME_STATS_MAX);
      if (A.fms && A.wms) A.wms[A.nfms] = (double)(tr1 - now) * 1000.0 / (double)SDL_GetPerformanceFrequency();
      if (A.fms && A.wms) A.fms[A.nfms++] = (double)(t1 - now) * 1000.0 / (double)SDL_GetPerformanceFrequency();
    }
  }
  pace_frame(ran);
  if (e->opt.max_ticks > 0 && e->tick >= e->opt.max_ticks) A.running = 0;
  if (e->playing && e->tick >= e->play.end_tick && !e->opt.screenshot[0]) A.running = 0;
  if (e->failed && e->playing) A.running = 0;
  if (e->opt.script[0] && (e->test_done || e->failed)) {
    if (e->failed) A.status = 1;
    A.running = 0;
  }
}

static void shutdown_app(void) {
  int i;
  if (A.fms) {
    sx_frame_summary fs, ws;
    const char *csv = getenv("SAUCER_FRAME_CSV"); /* every frame's ms in order, for tracing a hitch */
    if (csv && csv[0]) {
      FILE *f = fopen(csv, "w");
      if (f) {
        for (i = 0; i < A.nfms; i++) fprintf(f, "%d,%.3f\n", i, A.fms[i]);
        fclose(f);
      }
    }
    sx_frame_summarize(A.fms, A.nfms, &fs);
    sx_frame_summarize(A.wms, A.wms ? A.nfms : 0, &ws);
    printf("frame-stats: frames=%d avg=%.2f p50=%.2f p95=%.2f max=%.2f ms (sim %.2f, render %.2f, present %.2f) work(sim+render): avg=%.2f p95=%.2f max=%.2f\n", fs.n, fs.avg, fs.p50, fs.p95, fs.max,
           fs.n ? A.ssum / fs.n : 0.0, fs.n ? A.rsum / fs.n : 0.0, fs.n ? A.psum / fs.n : 0.0, ws.avg, ws.p95, ws.max);
    free(A.wms);
    A.wms = NULL;
    fflush(stdout);
    free(A.fms);
    A.fms = NULL;
  }
  if (A.e) {
    if (sx_engine_finish(A.e)) A.status = 1;
    sx_engine_destroy(A.e);
    A.e = NULL;
  }
  sx_audio_shutdown();
  sx_gl_shutdown();
  for (i = 0; i < SX_MAX_PADS; i++)
    if (A.pad_handles[i]) SDL_CloseGamepad(A.pad_handles[i]);
  if (A.gl) SDL_GL_DestroyContext(A.gl);
  if (A.win) SDL_DestroyWindow(A.win);
  SDL_Quit();
}

#ifdef __EMSCRIPTEN__
static void em_frame(void) {
  frame();
  if (!A.running) {
    emscripten_cancel_main_loop();
    shutdown_app();
  }
}

extern void saucer_web_xr_probe(void);

/* ---- networked co-op over a WebRTC data channel (web/saucer_net.js) ---- */
EM_JS(int, saucer_web_net_send, (const unsigned char *buf, int len), {
  return Module.saucerNetSend ? Module.saucerNetSend(HEAPU8.slice(buf, buf + len)) : -1;
});
static int web_net_send(const unsigned char *buf, int len) { return saucer_web_net_send(buf, len); }
/* the page pushes every datagram from the data channel in here */
EMSCRIPTEN_KEEPALIVE int saucer_net_push(const unsigned char *buf, int len) { return sx_net_web_push(buf, len); }
/* add-mobile-touch-ux: the page reports env(safe-area-inset-*) in CSS px on
 * start, resize and rotation */
EMSCRIPTEN_KEEPALIVE void saucer_set_safe_area(float l, float t, float r, float b) {
  A.safe[0] = l;
  A.safe[1] = t;
  A.safe[2] = r;
  A.safe[3] = b;
  touch_relayout();
}
/* what the page shows while the session runs */
EMSCRIPTEN_KEEPALIVE const char *saucer_net_status(void) {
  return A.e && A.e->net_on ? A.e->net.status : "";
}

/* ---- WebXR glue called from web/saucer_xr.js ---- */
EMSCRIPTEN_KEEPALIVE void saucer_xr_set_available(int a) {
  if (A.e) A.e->xr.available = a;
}
EMSCRIPTEN_KEEPALIVE void saucer_xr_begin(int mode) {
  if (!A.e) return;
  A.e->xr.session = mode;
  A.e->xr.mocked = 0;
  A.e->xr.nviews = 2;
  memset(A.e->xr.values, 0, sizeof A.e->xr.values);
}
EMSCRIPTEN_KEEPALIVE void saucer_xr_end(void) {
  if (!A.e) return;
  A.e->xr.session = 0;
  A.e->xr.hand_ok[0] = A.e->xr.hand_ok[1] = 0;
  sx_xr_set_joints(&A.e->xr, 0, 0, NULL);
  sx_xr_set_joints(&A.e->xr, 1, 0, NULL);
  memset(A.e->xr.values, 0, sizeof A.e->xr.values);
  A.last = SDL_GetPerformanceCounter();
}
/* WebXR looks down -z; the saucer flies toward +z, so the XR reference space
 * is turned 180 degrees about Y (right-multiply by diag(-1, 1, -1, 1)). */
EMSCRIPTEN_KEEPALIVE void saucer_xr_set_view(int i, const float *view, const float *proj, int x, int y, int w, int h) {
  sx_xr_view *v;
  int k;
  if (!A.e || i < 0 || i > 1) return;
  v = &A.e->xr.views[i];
  memcpy(v->view, view, sizeof v->view);
  memcpy(v->proj, proj, sizeof v->proj);
  for (k = 0; k < 4; k++) {
    v->view[k] = -v->view[k];
    v->view[8 + k] = -v->view[8 + k];
  }
  v->x = x;
  v->y = y;
  v->w = w;
  v->h = h;
}
EMSCRIPTEN_KEEPALIVE void saucer_xr_set_head(float px, float py, float pz, float fx, float fy, float fz) {
  if (!A.e) return;
  A.e->xr.head_pos[0] = -px;
  A.e->xr.head_pos[1] = py;
  A.e->xr.head_pos[2] = -pz;
  A.e->xr.head_fwd[0] = -fx;
  A.e->xr.head_fwd[1] = fy;
  A.e->xr.head_fwd[2] = -fz;
}
/* add-presentation-packaging: controller grip poses, same flip as the head */
EMSCRIPTEN_KEEPALIVE void saucer_xr_set_hand(int i, int ok, float px, float py, float pz, float fx, float fy, float fz) {
  float *h;
  if (!A.e || i < 0 || i > 1) return;
  A.e->xr.hand_ok[i] = ok;
  h = A.e->xr.hands[i];
  h[0] = -px;
  h[1] = py;
  h[2] = -pz;
  h[3] = -fx;
  h[4] = fy;
  h[5] = -fz;
}
/* add-webxr-cockpit: hand tracking. j = wrist, thumb tip, index tip, middle tip, ring tip, pinky tip
 * (x y z each, WebXR reference space), flipped like the head and the controllers. */
EMSCRIPTEN_KEEPALIVE void saucer_xr_set_joints(int hand, int ok, const float *j) {
  float f[SX_XR_JOINTS * 3];
  int k;
  if (!A.e) return;
  if (ok && j) {
    for (k = 0; k < SX_XR_JOINTS; k++) {
      f[k * 3] = -j[k * 3];
      f[k * 3 + 1] = j[k * 3 + 1];
      f[k * 3 + 2] = -j[k * 3 + 2];
    }
  }
  sx_xr_set_joints(&A.e->xr, hand, ok && j, f);
}
/* haptic pulses the game asked for: the page polls both hands every XR frame */
static int xr_haptic_ms[2];
EMSCRIPTEN_KEEPALIVE float saucer_xr_haptic_take(int hand) {
  float s = 0.0f;
  int ms = 0;
  if (!A.e || !sx_xr_haptic_take(&A.e->xr, hand, &s, &ms)) return 0.0f;
  xr_haptic_ms[hand] = ms;
  return s;
}
EMSCRIPTEN_KEEPALIVE int saucer_xr_haptic_ms(int hand) { return hand >= 0 && hand < 2 ? xr_haptic_ms[hand] : 0; }
/* the reference space the comfort settings ask for: 1 seated, 2 standing */
EMSCRIPTEN_KEEPALIVE int saucer_xr_pref_mode(void) { return A.e ? A.e->xr.pref_mode : 2; }
EMSCRIPTEN_KEEPALIVE void saucer_xr_set_control(int ctl, float v) {
  if (A.e && ctl >= 0 && ctl < SX_XR_COUNT) A.e->xr.values[ctl] = v;
}
EMSCRIPTEN_KEEPALIVE void saucer_xr_frame(unsigned int fb, int nviews, double dt_ms) {
  sx_engine *e = A.e;
  int n, i;
  if (!e || !e->xr.session) return;
  e->xr.nviews = nviews < 1 ? 1 : (nviews > 2 ? 2 : nviews);
  n = sx_ticks_for_frame(&A.acc, dt_ms / 1000.0);
  for (i = 0; i < n; i++) sx_engine_tick(e);
  sx_engine_render(e, A.acc * SX_TICK_HZ);
  sx_audio_flush(e);
  sx_gl_draw_xr(&e->render, fb);
}
#endif

static void *gl_proc(const char *name) { return (void *)SDL_GL_GetProcAddress(name); }

static int has_flag(int argc, char **argv, const char *flag) {
  int i;
  for (i = 1; i < argc; i++)
    if (strcmp(argv[i], flag) == 0) return 1;
  return 0;
}

int main(int argc, char **argv) {
  sx_options o;
  char err[256];
  sx_options_default(&o);
  if (!sx_options_parse(&o, argc, argv, err, sizeof err)) {
    fprintf(stderr, "%s\n%s", err, sx_usage());
    return 2;
  }
  if (o.show_help) {
    printf("%s", sx_usage());
    return 0;
  }
  if (o.quiet) sx_log_set_quiet(1);
  /* test and headless runs share the code path of saucer_headless */
  if (o.test_lua[0]) return sx_run_lua_tests(&o);
  if (o.headless) return sx_run_headless(&o);
#ifndef __EMSCRIPTEN__
  if (!has_flag(argc, argv, "--root")) {
    /* assets live beside the binary */
    const char *base = SDL_GetBasePath();
    if (base) {
      char *probe = sx_path_join(base, "data/base/mod.lua");
      if (sx_fs_is_file(probe)) SDL_strlcpy(o.root, base, sizeof o.root);
      free(probe);
    }
  }
  if (!has_flag(argc, argv, "--user-dir")) {
    char *pref = SDL_GetPrefPath("makesgames", "saucer");
    if (pref) {
      SDL_strlcpy(o.user_dir, pref, sizeof o.user_dir);
      SDL_free(pref);
    }
  }
#else
  if (!has_flag(argc, argv, "--user-dir")) SDL_strlcpy(o.user_dir, "/user", sizeof o.user_dir);
#endif
  memset(&A, 0, sizeof A);
  A.fixed_step = o.screenshot[0] != 0 || o.script[0] != 0;
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD | SDL_INIT_AUDIO)) {
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
      fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
      return 1;
    }
  }
#ifdef __EMSCRIPTEN__
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#else
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
#endif
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  A.win = SDL_CreateWindow("Saucer", o.width, o.height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE |
                                                            SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if (!A.win) {
    fprintf(stderr, "cannot create window: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }
  A.gl = SDL_GL_CreateContext(A.win);
  if (!A.gl || !sx_gl_init(gl_proc)) {
    fprintf(stderr, "cannot initialise OpenGL 3.3 / WebGL2: %s\n", SDL_GetError());
    shutdown_app();
    return 1;
  }
  SDL_GL_SetSwapInterval(A.fixed_step ? 0 : 1);
  sx_audio_init();
#ifdef __EMSCRIPTEN__
  sx_net_web_set_send(web_net_send);
#endif
  A.e = sx_engine_create(&o);
  if (!A.e) {
    fprintf(stderr, "failed to start (is data/ beside the binary? root: %s)\n", o.root);
    shutdown_app();
    return 2;
  }
  touch_relayout();
  A.running = 1;
  A.last = SDL_GetPerformanceCounter();
#ifdef __EMSCRIPTEN__
  saucer_web_xr_probe();
  emscripten_set_main_loop(em_frame, 0, 0);
  return 0;
#else
  while (A.running) frame();
  shutdown_app();
  return A.status;
#endif
}
