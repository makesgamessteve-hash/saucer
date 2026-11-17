/* rng, math, log, xr, touch — spec determinism / input.
 * SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
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
  sx_touch_down(&t, 1, t.widgets[use].x + 0.01f, t.widgets[use].y - SX_TOUCH_SLOP * 0.5f);
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

TEST(touch_widgets) {
  sx_touch t;
  sx_raw_input raw;
  int i;
  memset(&raw, 0, sizeof raw);
  sx_touch_init(&t, 0.1f);
  CHECK(sx_touch_ctl_from_name("boost") == SX_TOUCH_BOOST);
  CHECK(sx_touch_ctl_from_name("jam") == SX_TOUCH_JAM);
  CHECK(strcmp(t.widgets[t.nwidgets - 4].name, "jam") == 0); /* the Jammer button, before the look area */
  CHECK(strcmp(t.widgets[t.nwidgets - 3].name, "map") == 0 && sx_touch_ctl_from_name("decoy") == SX_TOUCH_DECOY);
  CHECK(sx_touch_ctl_from_name("nope") == -1);
  CHECK(strcmp(sx_touch_ctl_name(SX_TOUCH_LIFT), "lift") == 0);
  CHECK(strcmp(sx_touch_ctl_name(-1), "?") == 0);
  /* lift slider: drag up = climb, release = hold altitude */
  sx_touch_down(&t, 1, 0.95f, 0.5f);
  sx_touch_move(&t, 1, 0.95f, 0.3f);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] > 0.5f);
  sx_touch_up(&t, 1);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == 0);
  /* UP and DN hold buttons climb and dive at full rate, release hovers */
  sx_touch_down(&t, 3, 0.95f, 0.10f);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == 1.0f);
  sx_touch_up(&t, 3);
  sx_touch_down(&t, 4, 0.95f, 0.85f);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == -1.0f);
  sx_touch_up(&t, 4);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LIFT] == 0);
  /* look area accumulates drags into look_x/look_y */
  sx_touch_down(&t, 2, 0.6f, 0.3f);
  sx_touch_down(&t, 2, 0.6f, 0.3f); /* duplicate id ignored */
  sx_touch_move(&t, 2, 0.7f, 0.25f);
  sx_touch_apply(&t, &raw);
  CHECK(raw.touch[SX_TOUCH_LOOK_X] > 0 && raw.touch[SX_TOUCH_LOOK_Y] < 0);
  sx_touch_up(&t, 2);
  sx_touch_move(&t, 99, 0, 0);
  sx_touch_up(&t, 99);
  /* finger on nothing, then too many fingers */
  for (i = 0; i < SX_TOUCH_MAX_FINGERS + 2; i++) sx_touch_down(&t, 100 + i, 0.4f, 0.05f);
  CHECK(t.nfingers == SX_TOUCH_MAX_FINGERS);
  sx_touch_move(&t, 100, 0.41f, 0.06f);
}
