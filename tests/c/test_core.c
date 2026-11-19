/* rng, math, log, xr, touch — spec determinism / input.
 * SPDX-License-Identifier: MIT */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sx_fs.h"
#include "sx_log.h"
#include "sx_math.h"
#include "sx_rng.h"
#include "sx_touch.h"
#include "sx_xr.h"
#include "test.h"

/* Known-answer vectors are committed so every platform (gcc, clang, MSVC,
 * wasm) must reproduce the same bits. SAUCER_WRITE_KAT=1 regenerates them. */
static void kat(const char *name, const char *text) {
  char path[256];
  char *want;
  size_t n;
  snprintf(path, sizeof path, "tests/data/%s", name);
  if (getenv("SAUCER_WRITE_KAT")) sx_fs_write_atomic(path, text, strlen(text));
  want = sx_fs_read(path, &n);
  CHECK(want != NULL);
  if (want) {
    CHECK(n == strlen(text) && memcmp(want, text, n) == 0);
    free(want);
  }
}

TEST(rng_known_answers) {
  static char buf[64 * 1024];
  size_t o = 0;
  sx_pcg32 r;
  int i;
  sx_pcg32_seed(&r, 42, 54);
  for (i = 0; i < 1000; i++) o += (size_t)snprintf(buf + o, sizeof buf - o, "%08x\n", sx_pcg32_next(&r));
  kat("rng_kat.txt", buf);
}

static unsigned long long bits(double d) {
  unsigned long long u;
  memcpy(&u, &d, sizeof u);
  return u;
}

TEST(math_known_answers) {
  static char buf[512 * 1024];
  size_t o = 0;
  int i;
  for (i = 0; i < 4096; i++) {
    double x = (i - 2048) * 0.01234567;
    o += (size_t)snprintf(buf + o, sizeof buf - o, "%016llx %016llx %016llx %016llx\n", bits(sx_sin(x)), bits(sx_cos(x)),
                          bits(sx_atan2(x, 1.5 - x * 0.3)), bits(sx_sqrt(i * 0.37)));
  }
  kat("math_kat.txt", buf);
}

TEST(rng_streams) {
  sx_pcg32 a, b;
  uint64_t s = 7, s2 = 7;
  int i, seen_lo = 0, seen_hi = 0;
  CHECK(sx_splitmix64(&s) == sx_splitmix64(&s2));
  CHECK(s != 7);
  CHECK(sx_seed_child(1, "a", 0) != sx_seed_child(1, "b", 0));
  CHECK(sx_seed_child(1, "a", 0) != sx_seed_child(1, "a", 1));
  CHECK(sx_hash64_str("x") == sx_hash64("x", 1));
  sx_pcg32_seed(&a, 5, 1);
  sx_pcg32_seed(&b, 5, 1);
  for (i = 0; i < 2000; i++) {
    int64_t v = sx_pcg32_range(&a, 3, -3); /* swapped bounds */
    CHECK(v >= -3 && v <= 3);
    if (v == -3) seen_lo = 1;
    if (v == 3) seen_hi = 1;
    (void)sx_pcg32_next(&b);
  }
  CHECK(seen_lo && seen_hi);
  CHECK(sx_pcg32_bounded(&a, 0) == 0);
  CHECK(sx_pcg32_bounded(&a, 1) == 0);
  for (i = 0; i < 100; i++) {
    int64_t w = sx_pcg32_range(&a, -(1LL << 40), 1LL << 40);
    CHECK(w >= -(1LL << 40) && w <= (1LL << 40));
    CHECK(sx_pcg32_range(&a, 9, 9) == 9);
    CHECK(sx_pcg32_fixed(&a) >= 0 && sx_pcg32_fixed(&a) < 65536);
    CHECK(sx_pcg32_bounded(&a, 3000000000u) < 3000000000u);
  }
}

TEST(math_functions) {
  int i;
  CHECK_NEAR(sx_sin(SX_PI / 6), 0.5, 1e-15);
  CHECK_NEAR(sx_cos(SX_PI / 3), 0.5, 1e-15);
  CHECK_NEAR(sx_sin(1e6), -0.34999350217129294, 1e-9);
  CHECK(sx_sqrt(-1) == 0 && sx_sqrt(0) == 0);
  CHECK_NEAR(sx_atan(1), SX_PI / 4, 1e-15);
  CHECK_NEAR(sx_atan(-10), -1.4711276743037347, 1e-15);
  CHECK_NEAR(sx_atan2(0, -1), SX_PI, 1e-15);
  CHECK_NEAR(sx_atan2(-1, 0), -SX_PI / 2, 1e-15);
  CHECK(sx_atan2(0, 0) == 0);
  CHECK_NEAR(sx_atan2(-1, -1), -3 * SX_PI / 4, 1e-15);
  CHECK(sx_floor(-1.5) == -2 && sx_floor(2.0) == 2);
  CHECK_NEAR(sx_wrap_angle(SX_TAU * 3 + 1), 1, 1e-12);
  CHECK_NEAR(sx_wrap_angle(-SX_PI - 0.5), SX_PI - 0.5, 1e-12);
  for (i = -50; i < 50; i++) {
    double x = i * 0.37;
    CHECK_NEAR(sx_sin(x) * sx_sin(x) + sx_cos(x) * sx_cos(x), 1.0, 1e-14);
  }
  CHECK(sx_fx_from(1.5) == 98304);
  CHECK(sx_fx_to(SX_FX_ONE) == 1.0);
  CHECK(sx_fx_mul(sx_fx_from(-2), sx_fx_from(1.5)) == sx_fx_from(-3));
  CHECK(sx_fx_div(sx_fx_from(3), sx_fx_from(2)) == sx_fx_from(1.5));
  CHECK(sx_fx_div(1, 0) > 0 && sx_fx_div(-1, 0) < 0);
}

static int sink_calls;
static void sink(sx_log_level l, const char *m, void *u) {
  (void)l;
  (void)m;
  (void)u;
  sink_calls++;
}

TEST(log_sink_counts) {
  sx_log_reset_counts();
  sx_log_set_sink(sink, NULL);
  SX_WARN("w %d", 1);
  SX_ERROR("e");
  SX_INFO("i");
  CHECK(sink_calls == 3);
  CHECK(sx_log_count(SX_LOG_WARN) == 1);
  CHECK(sx_log_count((sx_log_level)7) == 0);
  CHECK(strcmp(sx_log_last(), "i") == 0);
  sx_log_set_sink(NULL, NULL);
}

TEST(xr_controls) {
  sx_xr x;
  int16_t aim[3];
  sx_xr_init(&x);
  CHECK(sx_xr_ctl_from_name("lever_up") == SX_XR_LEVER_UP);
  CHECK(sx_xr_ctl_from_name("nope") == -1);
  CHECK(strcmp(sx_xr_ctl_name(SX_XR_A), "a") == 0);
  CHECK(strcmp(sx_xr_ctl_name(99), "?") == 0);
  CHECK(sx_xr_quantize(2, 1) == 32767 && sx_xr_quantize(-2, 1) == -32767);
  CHECK(sx_xr_quantize(0.5f, 0) == 0);
  CHECK_NEAR(sx_xr_dequantize(sx_xr_quantize(0.25f, 2), 2), 0.25f, 1e-4);
  x.head_fwd[2] = 1;
  sx_xr_aim(&x, aim);
  CHECK(aim[2] == 32767 && aim[0] == 0);
}

/* add-presentation-packaging: the comfort filter turns stick flicks into snaps */
TEST(xr_snap_filter) {
  sx_xr x;
  float out[SX_XR_COUNT];
  sx_xr_init(&x);
  CHECK(x.snap == 1 && sx_xr_ctl_from_name("snap_l") == SX_XR_SNAP_L);
  x.values[SX_XR_STICK_RX] = 0.9f;
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_SNAP_R] == 1.0f && out[SX_XR_SNAP_L] == 0.0f && out[SX_XR_STICK_RX] == 0.0f);
  sx_xr_filter(&x, out); /* still held: latched, no second snap */
  CHECK(out[SX_XR_SNAP_R] == 0.0f);
  x.values[SX_XR_STICK_RX] = 0.5f; /* between the thresholds: stays latched */
  sx_xr_filter(&x, out);
  CHECK(x.snap_latch == 1);
  x.values[SX_XR_STICK_RX] = 0.1f;
  sx_xr_filter(&x, out);
  CHECK(x.snap_latch == 0);
  x.values[SX_XR_STICK_RX] = -0.8f;
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_SNAP_L] == 1.0f);
  x.values[SX_XR_STICK_RX] = 0.0f;
  sx_xr_filter(&x, out);
  x.snap = 0; /* smooth turning: the stick passes through */
  x.values[SX_XR_STICK_RX] = 0.9f;
  x.values[SX_XR_SNAP_R] = 1.0f; /* never from the device */
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_STICK_RX] == 0.9f && out[SX_XR_SNAP_R] == 0.0f);
}

/* add-presentation-packaging: touch slop, held highlights, floating stick, haptics */
TEST(touch_polish) {
  sx_touch t;
  float s[4];
  int i, use = -1;
  sx_touch_init(&t, 16.0f / 9.0f);
  for (i = 0; i < t.nwidgets; i++)
    if (strcmp(t.widgets[i].name, "use") == 0) use = i;
  CHECK(use >= 0);
  CHECK(!sx_touch_stick(&t, s));
  /* just above the USE button (inside the slop) still presses it and buzzes */
  sx_touch_down(&t, 1, t.widgets[use].x + 0.01f, t.widgets[use].y - t.slop[1] * 0.5f);
  CHECK(sx_touch_held(&t, use) && t.values[SX_TOUCH_USE] == 1.0f && t.buzz == 1);
  sx_touch_up(&t, 1);
  CHECK(!sx_touch_held(&t, use));
  /* the stick reports where the thumb landed and where it is */
  sx_touch_down(&t, 2, 0.1f, 0.7f);
  sx_touch_move(&t, 2, 0.15f, 0.65f);
  CHECK(sx_touch_stick(&t, s) && s[0] == 0.1f && s[3] == 0.65f);
  CHECK(t.buzz == 1); /* sticks do not buzz */
  sx_touch_up(&t, 2);
  /* far from any button on the right half: the look area */
  sx_touch_down(&t, 3, 0.6f, 0.2f);
  CHECK(t.widgets[t.fingers[0].widget].kind == 3);
  sx_touch_up(&t, 3);
}

static int widget(const sx_touch *t, const char *name) {
  int i;
  for (i = 0; i < t->nwidgets; i++)
    if (strcmp(t->widgets[i].name, name) == 0) return i;
  return -1;
}

static void centre(const sx_touch *t, const char *name, float *x, float *y) {
  int i = widget(t, name);
  *x = t->widgets[i].x + t->widgets[i].w * 0.5f;
  *y = t->widgets[i].y + t->widgets[i].h * 0.5f;
}

TEST(touch_widgets) {
  sx_touch t;
  sx_raw_input raw;
  int i;
  float x, y;
  memset(&raw, 0, sizeof raw);
  sx_touch_init(&t, 0.1f); /* clamped to a very tall portrait screen */
  CHECK(t.portrait && t.nwidgets == 15);
  CHECK(sx_touch_ctl_from_name("boost") == SX_TOUCH_BOOST);
  CHECK(sx_touch_ctl_from_name("jam") == SX_TOUCH_JAM && widget(&t, "jam") > 0);
  CHECK(widget(&t, "map") > 0 && sx_touch_ctl_from_name("decoy") == SX_TOUCH_DECOY && widget(&t, "decoy") > 0);
  /* add-playtest-recs: the grapple has its own button; the look area is last */
  CHECK(widget(&t, "grapple") > 0 && sx_touch_ctl_from_name("grapple") == SX_TOUCH_GRAPPLE);
  CHECK(strcmp(t.widgets[t.nwidgets - 1].name, "look") == 0);
  CHECK(strcmp(sx_touch_ctl_name(SX_TOUCH_GRAPPLE), "grapple") == 0);
  CHECK(sx_touch_ctl_from_name("nope") == -1);
  CHECK(strcmp(sx_touch_ctl_name(SX_TOUCH_LIFT), "lift") == 0);
  CHECK(strcmp(sx_touch_ctl_name(-1), "?") == 0);
  /* lift slider: drag up = climb, release = hold altitude */
  centre(&t, "lift", &x, &y);
  sx_touch_down(&t, 1, x, y);
  sx_touch_move(&t, 1, x, t.widgets[widget(&t, "lift")].y + 0.001f);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] > 0.9f);
  /* one thumb per slider: a second finger there looks around instead */
  sx_touch_down(&t, 5, x, y);
  CHECK(t.widgets[t.fingers[1].widget].kind == SX_TOUCH_KIND_LOOK);
  sx_touch_up(&t, 5);
  sx_touch_up(&t, 1);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == 0);
  /* UP and DN hold buttons climb and dive at full rate, release hovers */
  centre(&t, "up", &x, &y);
  sx_touch_down(&t, 3, x, y);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == 1.0f);
  sx_touch_up(&t, 3);
  centre(&t, "dn", &x, &y);
  sx_touch_down(&t, 4, x, y);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == -1.0f);
  sx_touch_up(&t, 4);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == 0);
  /* look area accumulates drags into look_x/look_y, the same gain on both axes */
  sx_touch_init(&t, 16.0f / 9.0f);
  sx_touch_down(&t, 2, 0.5f, 0.2f);
  sx_touch_down(&t, 2, 0.5f, 0.2f); /* duplicate id ignored */
  CHECK(t.nfingers == 1 && t.widgets[t.fingers[0].widget].kind == SX_TOUCH_KIND_LOOK);
  sx_touch_move(&t, 2, 0.5f + 12.0f / t.m.w, 0.2f - 12.0f / t.m.h); /* 12 CSS px right and up */
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LOOK_X] > 0 && raw.touch[SX_TOUCH_LOOK_Y] < 0);
  CHECK(fabsf(raw.touch[SX_TOUCH_LOOK_X] + raw.touch[SX_TOUCH_LOOK_Y]) < 1e-4f);
  CHECK(fabsf(raw.touch[SX_TOUCH_LOOK_X] - 12.0f * SX_TOUCH_LOOK_GAIN) < 1e-4f);
  sx_touch_up(&t, 2);
  sx_touch_move(&t, 99, 0, 0);
  sx_touch_up(&t, 99);
  /* finger on nothing (outside the image), then too many fingers */
  sx_touch_down(&t, 50, -0.5f, -0.5f);
  CHECK(t.fingers[0].widget == -1);
  sx_touch_move(&t, 50, -0.4f, -0.4f);
  sx_touch_up(&t, 50);
  for (i = 0; i < SX_TOUCH_MAX_FINGERS + 2; i++) sx_touch_down(&t, 100 + i, 0.5f, 0.2f);
  CHECK(t.nfingers == SX_TOUCH_MAX_FINGERS);
  sx_touch_move(&t, 100, 0.51f, 0.21f);
}

/* add-mobile-touch-ux: the stick is round in CSS px, has a radial deadzone
 * and its base follows the thumb past the rim */
TEST(touch_stick_deadzone_and_follow) {
  sx_touch t;
  sx_raw_input raw;
  float s[4], rx, ry, x0, y0;
  memset(&raw, 0, sizeof raw);
  sx_touch_init(&t, 16.0f / 9.0f);
  rx = t.stick_r / t.m.w;
  ry = t.stick_r / t.m.h;
  x0 = t.home.x + t.home.w * 0.5f;
  y0 = t.home.y + t.home.h * 0.5f;
  sx_touch_down(&t, 1, x0, y0);
  sx_touch_move(&t, 1, x0 + rx * SX_TOUCH_DEADZONE * 0.5f, y0);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_STICK_X] == 0 && raw.touch[SX_TOUCH_STICK_Y] == 0); /* inside the deadzone */
  sx_touch_move(&t, 1, x0 + rx * 0.5f, y0);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_STICK_X] > 0.4f && raw.touch[SX_TOUCH_STICK_X] < 0.5f);
  /* the same CSS distance up gives the same deflection */
  sx_touch_move(&t, 1, x0, y0 - ry * 0.5f);
  sx_touch_apply(&t, &raw);
  CHECK(fabsf(raw.touch[SX_TOUCH_STICK_Y] + 0.38f / 0.88f) < 0.01f && fabsf(raw.touch[SX_TOUCH_STICK_X]) < 1e-6f);
  /* past the rim: full deflection and the base is dragged along */
  sx_touch_move(&t, 1, x0 + rx * 3.0f, y0);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_STICK_X] > 0.999f && sx_touch_stick(&t, s));
  CHECK(fabsf(s[0] - (x0 + rx * 2.0f)) < 1e-4f && fabsf(s[1] - y0) < 1e-4f);
  /* coming back a little now steers left at once */
  sx_touch_move(&t, 1, x0 + rx * 1.5f, y0);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_STICK_X] < 0);
  /* a second finger in the stick zone looks instead of fighting the first */
  sx_touch_down(&t, 2, x0, y0);
  CHECK(t.widgets[t.fingers[1].widget].kind == SX_TOUCH_KIND_LOOK);
  sx_touch_up(&t, 2);
  sx_touch_up(&t, 1);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_STICK_X] == 0 && raw.touch[SX_TOUCH_STICK_Y] == 0);
}

static int rect_inside(const sx_touch_rect *a, const sx_touch_rect *b) {
  const float e = 1e-4f;
  return a->x >= b->x - e && a->y >= b->y - e && a->x + a->w <= b->x + b->w + e && a->y + a->h <= b->y + b->h + e;
}

/* add-mobile-touch-ux: the layout at the eight reference screens (portrait
 * and landscape phones and a tablet), bare and behind a notch and a home
 * indicator: no overlaps, targets >= 44 CSS px (48 by design), gaps >= 8,
 * all inside the safe area, nothing over the HUD, clear text columns */
TEST(touch_layout_resolutions) {
  static const int sizes[8][2] = {{320, 568}, {568, 320}, {360, 640}, {640, 360},
                                  {390, 844}, {844, 390}, {768, 1024}, {1024, 768}};
  int k, notch, i, j;
  for (notch = 0; notch < 2; notch++)
    for (k = 0; k < 8; k++) {
      sx_touch t;
      sx_touch_metrics m;
      float W = (float)sizes[k][0], H = (float)sizes[k][1];
      memset(&m, 0, sizeof m);
      memset(&t, 0, sizeof t);
      m.w = W;
      m.h = H;
      if (notch && (W >= 800 || H >= 800) && W + H < 1300) { /* a notched phone: notch on the long edge, home indicator */
        if (W > H) {
          m.safe[0] = m.safe[2] = 47;
          m.safe[3] = 21;
        } else {
          m.safe[1] = 47;
          m.safe[3] = 34;
        }
      } else if (notch) { /* a tablet's home indicator, an edge-to-edge Android gesture bar */
        m.safe[1] = W + H >= 1300 ? 24.0f : 0.0f;
        m.safe[3] = W + H >= 1300 ? 20.0f : 16.0f;
      }
      sx_touch_fit_target(sizes[k][0], sizes[k][1], &m.hud_w, &m.hud_h);
      t.active = 1;
      sx_touch_layout(&t, &m);
      CHECK(t.active == 1 && t.nwidgets == 15 && t.portrait == (H > W));
      CHECK(t.unit >= 48.0f && t.unit <= 72.0f && t.gap >= SX_TOUCH_MIN_GAP);
      CHECK(m.hud_w >= 200 && m.hud_h >= 200 && H / (float)m.hud_h >= 1.33f); /* labels at 10.7 CSS px or more */
      for (i = 0; i < t.nwidgets; i++) {
        const sx_touch_widget *w = &t.widgets[i];
        sx_touch_rect r = sx_touch_visible_rect(&t, i);
        if (w->kind == SX_TOUCH_KIND_LOOK) continue;
        /* size: every target at least 44 CSS px both ways */
        CHECK(r.w * W >= SX_TOUCH_MIN_TARGET - 0.01f && r.h * H >= SX_TOUCH_MIN_TARGET - 0.01f);
        if (w->kind == SX_TOUCH_KIND_BUTTON || w->kind == SX_TOUCH_KIND_HOLD)
          CHECK(r.w * W >= 47.99f && r.h * H >= 47.99f);
        /* inside the safe area, with the margin */
        CHECK(rect_inside(&r, &t.safe));
        CHECK(r.x * W >= m.safe[0] + 15.99f && (r.x + r.w) * W <= W - m.safe[2] - 15.99f);
        CHECK((r.y + r.h) * H <= H - m.safe[3] - 15.99f);
        /* the stick zone holds its ring */
        if (w->kind == SX_TOUCH_KIND_STICK) {
          sx_touch_rect z;
          z.x = w->x;
          z.y = w->y;
          z.w = w->w;
          z.h = w->h;
          CHECK(rect_inside(&r, &z));
          CHECK(t.stick_r >= 48.0f);
        }
        /* never over the HUD (top rows, status block, crosshair) or the text column */
        for (j = 0; j < t.nhud; j++) CHECK(!sx_touch_overlap(&r, &t.hud[j]));
        CHECK(!sx_touch_overlap(&r, &t.msg));
        /* the centre span keeps clear of every control on the middle rows */
        if ((r.y + r.h) * H > H * 0.5f - 64.0f * H / (float)m.hud_h && r.y * H < H * 0.5f + 72.0f * H / (float)m.hud_h)
          CHECK(r.x + r.w <= t.cx0 + 1e-4f || r.x >= t.cx1 - 1e-4f);
        /* no two controls overlap, and they keep a gap of 8 CSS px */
        for (j = i + 1; j < t.nwidgets; j++) {
          sx_touch_rect q = sx_touch_visible_rect(&t, j), g = r;
          if (t.widgets[j].kind == SX_TOUCH_KIND_LOOK) continue;
          g.x -= (SX_TOUCH_MIN_GAP - 0.01f) / W;
          g.y -= (SX_TOUCH_MIN_GAP - 0.01f) / H;
          g.w += 2.0f * (SX_TOUCH_MIN_GAP - 0.01f) / W;
          g.h += 2.0f * (SX_TOUCH_MIN_GAP - 0.01f) / H;
          CHECK(!sx_touch_overlap(&g, &q));
          /* the stick zone (touch area) does not take any other control either */
          if (w->kind == SX_TOUCH_KIND_STICK) {
            sx_touch_rect z;
            z.x = w->x;
            z.y = w->y;
            z.w = w->w;
            z.h = w->h;
            CHECK(!sx_touch_overlap(&z, &q));
          }
        }
        /* a tap in the middle of a control lands on it */
        if (w->kind != SX_TOUCH_KIND_STICK) {
          sx_touch_down(&t, 7, w->x + w->w * 0.5f, w->y + w->h * 0.5f);
          CHECK(t.fingers[0].widget == i);
          sx_touch_up(&t, 7);
        }
      }
      /* the clear column holds two lines of the log at least, 18 columns wide or the
       * whole left side, and lies in the safe area */
      CHECK(t.msg.h * (float)m.hud_h >= 20.0f && t.msg.w * (float)m.hud_w >= 120.0f);
      CHECK(rect_inside(&t.msg, &t.safe));
      for (j = 0; j < t.nhud; j++)
        if (j != 2) CHECK(!sx_touch_overlap(&t.msg, &t.hud[j]));
      CHECK(t.cx1 - t.cx0 >= 0.25f); /* a quarter of the width at least for centred text */
      t.buzz = 0;
    }
}

/* add-mobile-touch-ux: the target fills the window, a near miss goes to the nearest button */
TEST(touch_fit_and_slop) {
  sx_touch t;
  sx_touch_metrics m;
  int tw, th, use, scan;
  float x, y;
  sx_touch_fit_target(1280, 720, &tw, &th);
  CHECK(tw == 480 && th == 270); /* desktop 16:9 is unchanged */
  sx_touch_fit_target(320, 568, &tw, &th);
  CHECK(tw == 240 && th == 426);
  sx_touch_fit_target(1024, 768, &tw, &th);
  CHECK(tw == 480 && th == 360); /* a tablet keeps the full HUD */
  sx_touch_fit_target(100, 3000, &tw, &th);
  CHECK(tw == 200 && th == 640);
  sx_touch_fit_target(0, 0, &tw, &th);
  CHECK(tw == 200 && th == 200);
  /* degenerate metrics are clamped */
  memset(&m, 0, sizeof m);
  m.safe[0] = -5;
  sx_touch_layout(&t, &m);
  CHECK(t.m.w == 1 && t.m.h == 1 && t.m.hud_w == 1 && t.m.safe[0] == 0);
  /* slop: half a gap outside a button still presses it, the nearest one wins */
  sx_touch_init(&t, 16.0f / 9.0f);
  use = widget(&t, "use");
  scan = widget(&t, "scan");
  CHECK(fabsf(t.slop[1] * t.m.h - t.gap * 0.5f) < 1e-3f);
  centre(&t, "use", &x, &y);
  sx_touch_down(&t, 1, x, t.widgets[use].y - t.gap * 0.3f / t.m.h); /* in the gap, nearer USE */
  CHECK(t.fingers[0].widget == use && t.buzz == 1);
  sx_touch_up(&t, 1);
  sx_touch_down(&t, 1, x, t.widgets[use].y - t.gap * 0.7f / t.m.h); /* nearer SCN, above */
  CHECK(t.fingers[0].widget == scan);
  sx_touch_up(&t, 1);
}
