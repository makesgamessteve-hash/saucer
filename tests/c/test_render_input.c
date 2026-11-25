/* render lists, matrices, input mapping — SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include "sx_fs.h"
#include "sx_rng.h"
#include "sx_input.h"
#include "sx_render.h"
#include "sx_touch.h"
#include "test.h"

static unsigned char *load(const char *p, int *len) {
  size_t n = 0;
  unsigned char *d = (unsigned char *)sx_fs_read(p, &n);
  *len = (int)n;
  return d;
}

/* add-retro-renderer-basic, "Retro effects are optional and XR-safe" */
TEST(retro_effects_xr_safe) {
  static sx_render r;
  sx_effects fx;
  sx_render_init(&r);
  /* the defaults: snapping and dithering on, the PS1 texture warp opt-in */
  fx = sx_render_effects(&r.settings, 0);
  CHECK(fx.snap == 1 && fx.dither == 1 && fx.affine == 0);
  /* each effect toggles on its own on a flat screen */
  r.settings.affine = 1;
  fx = sx_render_effects(&r.settings, 0);
  CHECK(fx.snap == 1 && fx.affine == 1 && fx.dither == 1);
  r.settings.vertex_snap = 0;
  r.settings.dither = 0;
  fx = sx_render_effects(&r.settings, 0);
  CHECK(fx.snap == 0 && fx.affine == 1 && fx.dither == 0);
  /* XR session starts with everything on: snapping and the warp are off for the headset's views, dithering stays */
  r.settings.vertex_snap = 1;
  r.settings.dither = 1;
  fx = sx_render_effects(&r.settings, 1);
  CHECK(fx.snap == 0 && fx.affine == 0 && fx.dither == 1);
  /* the flat-screen settings were never touched: they are back when the session ends */
  CHECK(r.settings.vertex_snap == 1 && r.settings.affine == 1);
  fx = sx_render_effects(&r.settings, 0);
  CHECK(fx.snap == 1 && fx.affine == 1);
}

TEST(render_resources) {
  static sx_render r;
  unsigned char *png;
  int len, i, id;
  sx_mesh m;
  sx_render_init(&r);
  CHECK(sx_render_error_texture(&r) == 1);
  CHECK(sx_render_texture_from_png(&r, "x", NULL, 0) == 1);
  CHECK(sx_render_texture_from_png(&r, "x", (const unsigned char *)"junk", 4) == 1);
  png = load("tests/fixtures/images/index_3x2.png", &len);
  id = sx_render_texture_from_png(&r, "idx", png, len);
  free(png);
  CHECK(id > 1 && r.textures[id].w == 3 && r.textures[id].index[0] == 5);
  CHECK(sx_render_find_texture(&r, "idx") == id && sx_render_find_texture(&r, "nope") == 0);
  CHECK(sx_render_texture_soft(&r, id, 1) == 1 && r.textures[id].soft == 1);
  CHECK(sx_render_texture_soft(&r, id, 0) == 1 && r.textures[id].soft == 0);
  CHECK(sx_render_texture_soft(&r, 0, 1) == 0 && sx_render_texture_soft(&r, SX_MAX_TEXTURES, 1) == 0);
  CHECK(sx_render_texture_soft(&r, SX_MAX_TEXTURES - 1, 1) == 0);
  CHECK(sx_render_texture_from_indices(&r, "bad", 0, 1, NULL) == 1);
  CHECK(sx_render_fallback_font(&r) > 1);
  CHECK(sx_render_palettes_from_png(&r, "x", NULL, 0) == -1);
  png = load("tests/fixtures/images/palette_300x70.png", &len);
  CHECK(sx_render_palettes_from_png(&r, "a_rather_long_palette_name_here", png, len) == 1);
  free(png);
  CHECK(r.npalettes == SX_MAX_PALETTES);
  CHECK(sx_render_find_palette(&r, "a_rather_long_palette_name_here") == 1);
  CHECK(sx_render_find_palette(&r, "a_rather_long_palette_name_h#1") == 2);
  CHECK(sx_render_find_palette(&r, "zzz") == -1);
  CHECK(r.palettes[1][0][3] == 0 && r.palettes[1][5][0] == 10);
  /* fill texture table */
  for (i = 0; i < SX_MAX_TEXTURES; i++) sx_render_texture_from_indices(&r, "f", 1, 1, (const unsigned char *)"\1");
  CHECK(sx_render_texture_from_indices(&r, "full", 1, 1, (const unsigned char *)"\1") == 1);
  /* meshes */
  sx_mesh_init(&m);
  id = sx_render_add_mesh(&r, &m);
  CHECK(id == 1);
  sx_render_free_mesh(&r, id);
  sx_render_free_mesh(&r, id);
  sx_render_free_mesh(&r, -1);
  for (i = 1; i < SX_MAX_MESHES; i++) {
    sx_mesh_init(&m);
    sx_render_add_mesh(&r, &m);
  }
  sx_mesh_init(&m);
  CHECK(sx_render_add_mesh(&r, &m) == 0);
  sx_render_free(&r);
}

TEST(render_frame_lists_and_layout) {
  static sx_render r;
  int rects[4][4], i;
  sx_draw_mesh d;
  sx_draw_billboard b;
  sx_draw_ui u;
  memset(&d, 0, sizeof d);
  memset(&b, 0, sizeof b);
  memset(&u, 0, sizeof u);
  sx_viewport_layout(1, 100, 50, rects);
  CHECK(rects[0][2] == 100 && rects[0][3] == 50);
  sx_viewport_layout(2, 100, 51, rects);
  CHECK(rects[1][1] == 25 && rects[1][3] == 26);
  sx_viewport_layout(3, 101, 51, rects);
  CHECK(rects[1][0] == 50 && rects[1][2] == 51 && rects[2][1] == 25);
  sx_viewport_layout(9, 100, 50, rects);
  CHECK(rects[3][0] == 50 && rects[3][1] == 25);
  sx_render_init(&r);
  sx_render_begin_frame(&r, 0);
  CHECK(r.nviews == 1);
  sx_render_begin_frame(&r, 99);
  CHECK(r.nviews == SX_MAX_VIEWPORTS && r.views[3].player == 4);
  for (i = 0; i < 100; i++) {
    sx_view_mesh(&r.views[0], &d);
    sx_view_billboard(&r.views[0], &b);
    sx_view_ui(&r.views[0], &u);
  }
  CHECK(r.views[0].nmeshes == 100 && r.views[0].nbills == 100 && r.views[0].nui == 100);
  sx_render_begin_frame(&r, 1);
  CHECK(r.views[0].nmeshes == 0);
  sx_render_free(&r);
}

TEST(render_matrices) {
  float a[16], b[16], m[16], f[3];
  float pos[3] = {1, 2, 3}, sc[3] = {2, 2, 2};
  sx_camera c;
  memset(&c, 0, sizeof c);
  sx_mat4_identity(a);
  sx_mat4_model(b, pos, 0, sc);
  sx_mat4_mul(m, a, b);
  CHECK(m[0] == 2 && m[12] == 1 && m[14] == 3);
  sx_mat4_perspective(m, 1.5707963f, 2.0f, 1, 100);
  CHECK_NEAR(m[5], 1.0, 1e-5);
  CHECK_NEAR(m[0], 0.5, 1e-5);
  CHECK(m[11] == -1);
  sx_camera_forward(&c, f);
  CHECK_NEAR(f[2], 1, 1e-6);
  c.pos[2] = -5;
  sx_camera_view(&c, m);
  /* world origin is 5 m in front of the camera: view z = -5 */
  CHECK_NEAR(m[14], -5, 1e-5);
  c.pitch = 1.5707963f; /* straight up: degenerate right vector */
  sx_camera_view(&c, m);
  CHECK_NEAR(m[0], 1, 1e-6);
  c.pitch = 0;
  c.has_matrices = 1;
  sx_mat4_identity(c.view);
  c.yaw = 0;
  sx_camera_view(&c, m);
  CHECK_NEAR(m[14], 5, 1e-5);
}

TEST(input_names_and_bindings) {
  sx_binding b;
  char buf[64];
  static const char *ok[] = {"key:W", "key:w", "key:1", "key:0", "key:Space", "key:F12", "mouse:left", "mouse:dx:0.5",
                             "pad:a", "pad:leftx:-1", "touch:lift", "xr:trigger_r", NULL};
  static const char *bad[] = {"key", "key:", "key:Nope", "key:@", "mouse:side", "pad:paddle", "touch:x", "xr:zz",
                              "joy:a", "key:" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", NULL};
  int i;
  for (i = 0; ok[i]; i++) {
    sx_binding c;
    CHECK(sx_binding_parse(ok[i], &b));
    sx_binding_format(&b, buf, sizeof buf);
    CHECK(sx_binding_parse(buf, &c) && c.src == b.src && c.code == b.code && c.scale == b.scale);
  }
  for (i = 0; bad[i]; i++) CHECK(!sx_binding_parse(bad[i], &b));
  CHECK(!sx_binding_parse(NULL, &b));
  b.src = SX_SRC_NONE;
  b.scale = 1;
  sx_binding_format(&b, buf, sizeof buf);
  CHECK_STR(buf, "?:?");
  CHECK_STR(sx_key_name(39), "0");
  CHECK_STR(sx_key_name(30), "1");
  CHECK_STR(sx_key_name(40), "Return");
  CHECK_STR(sx_key_name(500), "?");
  CHECK(sx_key_from_name(NULL) == -1);
  {
    volatile float z = 0;
    CHECK(sx_quantize_axis(z / z) == 0);
  }
  CHECK(sx_quantize_axis(2) == SX_AXIS_MAX && sx_quantize_axis(-2) == -SX_AXIS_MAX);
  CHECK(sx_quantize_axis(-0.5f) == -16384);
}

TEST(input_actions_claims_pads) {
  static sx_input in;
  sx_cmd cmds[SX_MAX_PLAYERS];
  int n, fire, mx, lift, i;
  char name[40];
  sx_input_init(&in, 0);
  CHECK(in.nplayers == 1);
  sx_input_init(&in, 9);
  CHECK(in.nplayers == SX_MAX_PLAYERS);
  sx_input_init(&in, 1);
  fire = sx_input_define_action(&in, "fire", SX_ACT_BUTTON);
  mx = sx_input_define_action(&in, "move_x", SX_ACT_AXIS);
  lift = sx_input_define_action(&in, "lift", SX_ACT_AXIS);
  CHECK(sx_input_define_action(&in, "fire", SX_ACT_BUTTON) == fire);
  CHECK(sx_input_define_action(&in, "fire", SX_ACT_AXIS) == -1);
  CHECK(sx_input_define_action(&in, "weird", (sx_action_kind)5) == -1);
  CHECK(sx_input_define_action(&in, "a_name_that_is_much_too_long_for_the_slot", SX_ACT_BUTTON) == -1);
  for (i = 0; i < 10; i++) {
    snprintf(name, sizeof name, "ax%d", i);
    sx_input_define_action(&in, name, SX_ACT_AXIS);
  }
  CHECK(in.naxes == SX_NUM_AXES);
  for (i = 0; i < 40; i++) {
    snprintf(name, sizeof name, "b%d", i);
    sx_input_define_action(&in, name, SX_ACT_BUTTON);
  }
  CHECK(in.nbuttons == SX_MAX_BUTTON_ACTIONS);
  CHECK(sx_input_define_action(&in, "more", SX_ACT_AXIS) == -1);
  CHECK(sx_input_bind(&in, 1, fire, "key:Space") && sx_input_bind(&in, 1, fire, "mouse:left"));
  CHECK(sx_input_bind(&in, 1, fire, "pad:a") && sx_input_bind(&in, 1, fire, "touch:tractor"));
  CHECK(sx_input_bind(&in, 1, fire, "xr:trigger_r"));
  CHECK(sx_input_bind(&in, 1, mx, "key:D:1") && sx_input_bind(&in, 1, mx, "pad:leftx"));
  CHECK(sx_input_bind(&in, 1, mx, "mouse:dx:0.1") && sx_input_bind(&in, 1, mx, "pad:dpright:1"));
  CHECK(sx_input_bind(&in, 1, mx, "mouse:right:0.5"));
  CHECK(sx_input_bind(&in, 1, lift, "touch:lift") && sx_input_bind(&in, 1, lift, "xr:stick_ry"));
  CHECK(!sx_input_bind(&in, 0, fire, "key:A") && !sx_input_bind(&in, 1, 999, "key:A"));
  CHECK(!sx_input_bind(&in, 1, fire, "key:Nope"));
  for (i = 0; i < 7; i++) sx_input_bind(&in, 1, fire, "key:F1");
  CHECK(!sx_input_bind(&in, 1, fire, "key:F2"));
  sx_input_clear_bindings(&in, 1, 999);
  sx_input_clear_bindings(&in, 1, fire);
  sx_input_bind(&in, 1, fire, "key:Space");
  sx_input_bind(&in, 1, fire, "mouse:left");
  sx_input_bind(&in, 1, fire, "pad:a");
  sx_input_bind(&in, 1, fire, "touch:tractor");
  sx_input_bind(&in, 1, fire, "xr:trigger_r");

  /* keyboard */
  in.raw.keys[44] = 1;
  in.raw.keys[sx_key_from_name("D")] = 1;
  sx_input_build(&in, 1, cmds, &n);
  CHECK(n == 1 && (cmds[0].buttons & 1) && (cmds[0].edges & 1) && cmds[0].axes[0] == SX_AXIS_MAX);
  CHECK_STR(sx_input_device_mode(&in, 1), "kbm");
  sx_input_build(&in, 2, cmds, &n);
  CHECK(cmds[0].edges == 0);
  memset(&in.raw, 0, sizeof in.raw);
  in.raw.mouse_btn[1] = 1;
  in.raw.mouse_btn[3] = 1;
  in.raw.mouse_axis[0] = 2;
  sx_input_build(&in, 3, cmds, &n);
  CHECK(cmds[0].buttons & 1);
  CHECK(cmds[0].axes[0] > 0);
  CHECK(in.raw.mouse_axis[0] == 0);
  memset(&in.raw, 0, sizeof in.raw);
  /* touch & xr */
  in.raw.touch[SX_TOUCH_TRACTOR] = 1;
  in.raw.touch[SX_TOUCH_LIFT] = 0.5f;
  sx_input_build(&in, 4, cmds, &n);
  CHECK((cmds[0].buttons & 1) && cmds[0].axes[in.actions[lift].slot] == 16384);
  CHECK_STR(sx_input_device_mode(&in, 1), "touch");
  memset(&in.raw, 0, sizeof in.raw);
  in.raw.xr[0] = 1;
  in.raw.aim[2] = 77;
  sx_input_build(&in, 5, cmds, &n);
  CHECK((cmds[0].buttons & 1) && cmds[0].aim[2] == 77);
  CHECK_STR(sx_input_device_mode(&in, 1), "xr");
  memset(&in.raw, 0, sizeof in.raw);

  /* pads: first pad auto-claims for P1, second is offered */
  sx_input_pad_connected(&in, -1, 1);
  sx_input_pad_connected(&in, 0, 1);
  CHECK(sx_input_owner(&in, SX_DEV_PAD0) == 1);
  in.raw.pad_btn[0][0] = 1;
  in.raw.pad_axis[0][0] = 0.1f; /* dead zone */
  in.raw.pad_btn[0][14] = 1;   /* dpright */
  sx_input_build(&in, 6, cmds, &n);
  CHECK((cmds[0].buttons & 1) && cmds[0].axes[0] == SX_AXIS_MAX);
  CHECK_STR(sx_input_device_mode(&in, 1), "pad");
  sx_input_pad_connected(&in, 1, 1);
  CHECK(in.join_offer[SX_DEV_PAD0 + 1] && sx_input_owner(&in, SX_DEV_PAD0 + 1) == 0);
  in.raw.pad_btn[1][0] = 1;
  sx_input_build(&in, 7, cmds, &n);
  CHECK(n == 1); /* co-op off: no join */
  in.coop_enabled = 1;
  sx_input_build(&in, 8, cmds, &n);
  /* co-op on: a frame for every slot, empty ones zeroed */
  CHECK(n == SX_MAX_PLAYERS && sx_input_owner(&in, SX_DEV_PAD0 + 1) == 2 && in.nplayers == 2);
  CHECK(cmds[2].player == 3 && cmds[2].buttons == 0);
  sx_input_pad_connected(&in, 1, 0);
  CHECK(sx_input_owner(&in, SX_DEV_PAD0 + 1) == 0 && in.raw.pad_btn[1][0] == 0);
  sx_input_pad_connected(&in, 2, 1); /* P1 already has a pad: offer */
  CHECK(in.join_offer[SX_DEV_PAD0 + 2]);
  CHECK(!sx_input_claim(&in, 0, 0) && !sx_input_claim(&in, 1, 99));
  CHECK(sx_input_owner(&in, -1) == 0);
  sx_input_release(&in, -1);
  CHECK_STR(sx_input_device_mode(&in, 0), "kbm");
  CHECK_STR(sx_input_device_mode(&in, 2), "kbm");
}

/* add-wider-dark: a split keyboard, F2 joins, XR refuses joins, side-by-side split */
TEST(split_keyboard_and_coop_layout) {
  static sx_input in;
  sx_cmd cmds[SX_MAX_PLAYERS];
  sx_binding b;
  char buf[64];
  int n, use, mx, rects[SX_MAX_VIEWPORTS][4];
  sx_input_init(&in, 1);
  use = sx_input_define_action(&in, "use", SX_ACT_BUTTON);
  mx = sx_input_define_action(&in, "move_x", SX_ACT_AXIS);
  for (n = 1; n <= SX_MAX_PLAYERS; n++) {
    CHECK(sx_input_bind(&in, n, use, "key:Return") && sx_input_bind(&in, n, use, "key:G"));
    CHECK(sx_input_bind(&in, n, use, "key2:Return") && sx_input_bind(&in, n, mx, "key2:L:1"));
  }
  CHECK(sx_binding_parse("key2:Semicolon", &b) && b.src == SX_SRC_KEY2 && b.code == 51);
  sx_binding_format(&b, buf, sizeof buf);
  CHECK_STR(buf, "key2:Semicolon");
  CHECK(!sx_binding_parse("key2:Nope", &b));
  /* without co-op F2 does nothing; with an XR session it is refused */
  in.raw.keys[SX_KEY_JOIN2] = 1;
  sx_input_build(&in, 1, cmds, &n);
  CHECK(n == 1 && sx_input_owner(&in, SX_DEV_KEYS2) == 0);
  in.raw.keys[SX_KEY_JOIN2] = 0;
  sx_input_build(&in, 2, cmds, &n);
  in.coop_enabled = 1;
  in.xr_active = 1;
  in.raw.keys[SX_KEY_JOIN2] = 1;
  sx_input_build(&in, 3, cmds, &n);
  CHECK(n == SX_MAX_PLAYERS && sx_input_owner(&in, SX_DEV_KEYS2) == 0);
  in.raw.keys[SX_KEY_JOIN2] = 0;
  sx_input_build(&in, 4, cmds, &n);
  in.xr_active = 0;
  in.raw.keys[SX_KEY_JOIN2] = 1;
  sx_input_build(&in, 5, cmds, &n);
  CHECK(sx_input_owner(&in, SX_DEV_KEYS2) == 2 && in.nplayers == 2);
  /* Return is the right half's now: P1 keeps G only */
  in.raw.keys[40] = 1; /* Return */
  sx_input_build(&in, 6, cmds, &n);
  CHECK(!(cmds[0].buttons & (1u << use)) && (cmds[1].buttons & (1u << use)));
  in.raw.keys[40] = 0;
  in.raw.keys[10] = 1;  /* G */
  in.raw.keys[15] = 1;  /* L */
  sx_input_build(&in, 7, cmds, &n);
  CHECK((cmds[0].buttons & (1u << use)) && !(cmds[1].buttons & (1u << use)) && cmds[1].axes[0] > 0);
  CHECK(sx_input_split_keyboard(&in, 2) && !sx_input_split_keyboard(&in, 3));
  CHECK_STR(sx_input_device_mode(&in, 2), "keys2");
  /* two players side by side, or stacked */
  sx_viewport_layout_split(2, 100, 50, 1, rects);
  CHECK(rects[0][2] == 50 && rects[1][0] == 50 && rects[1][3] == 50);
  sx_viewport_layout_split(2, 100, 50, 0, rects);
  CHECK(rects[1][1] == 25 && rects[1][2] == 100);
  sx_viewport_layout_split(4, 100, 50, 1, rects);
  CHECK(rects[3][0] == 50 && rects[3][1] == 25);
}

/* add-material-system, "Slot round trip": a two-material part carries each part's slot in the 13th float */
TEST(material_slot_round_trip) {
  sx_mesh m;
  sx_part_style a, b;
  float mn[3] = {0, 0, 0}, mx[3] = {1, 1, 1}, mn2[3] = {2, 0, 0}, mx2[3] = {3, 1, 1};
  int i, na;
  CHECK(SX_VTX_FLOATS == 13);
  sx_mesh_init(&m);
  sx_style_default(&a);
  CHECK(a.material == 0.0f);
  sx_style_default(&b);
  a.material = 3.0f;
  b.material = 5.0f;
  sx_mesh_box(&m, mn, mx, &a);
  na = m.nv;
  sx_mesh_box(&m, mn2, mx2, &b);
  CHECK(na > 0 && m.nv == 2 * na);
  for (i = 0; i < m.nv; i++) CHECK(m.v[i * SX_VTX_FLOATS + 12] == (i < na ? 3.0f : 5.0f));
  /* the emissive float is untouched next to it */
  CHECK(m.v[11] == 0.0f);
  sx_mesh_free(&m);
}

TEST(material_pack_modes) {
  static sx_materials ms;
  float out[SX_MAT_SLOTS * SX_MAT_VEC4 * 4];
  sx_material *c, *o, *g;
  sx_materials_reset(&ms);
  /* nothing submitted: every slot packs plain */
  CHECK(sx_materials_pack(&ms, SX_MATERIALS_FULL, out) == 0 && out[0] == 0.0f);
  ms.on = 1;
  c = &ms.slot[1];
  c->kind = SX_MAT_METAL;
  c->reflect = 0.9f;
  c->spec = 64.0f;
  c->ramp_hi[0] = 0.8f;
  g = &ms.slot[2];
  g->kind = SX_MAT_CRYSTAL;
  g->reflect = 0.7f;
  g->emit = 0.5f;
  o = &ms.slot[3];
  o->kind = SX_MAT_ORGANIC;
  o->wobble[0] = 0.2f;
  o->wobble[1] = 0.0f; /* clamped to 0.5 s */
  o->wobble[2] = 0.0f; /* clamped to 0.1 m */
  o->breath = 0.6f;
  o->pulse = 1.5f;
  o->wrap = 0.4f;
  o->sss[0] = 0.9f;
  ms.slot[4].kind = 9; /* a bad kind packs plain */
  ms.slot[0].kind = SX_MAT_METAL; /* slot 0 is always plain */
  c->brushed = 0.6f;
  c->ripple = 0.2f;
  g->sparkle = 0.8f;
  o->sparkle = 0.5f; /* sparkle is a crystal's, brushing and ripples a metal's */
  o->brushed = 0.5f;
#define P(slot, i) out[(slot) * SX_MAT_VEC4 * 4 + (i)]
  CHECK(sx_materials_pack(&ms, SX_MATERIALS_FULL, out) == 3);
  CHECK(out[0] == 0.0f);
  CHECK(P(1, 0) == 1.0f && P(1, 1) == 0.9f && P(1, 2) == 64.0f && P(1, 12) == 0.8f);
  CHECK(P(2, 0) == 2.0f && P(2, 1) == 0.7f && P(2, 4) == 0.5f);
  CHECK(P(3, 0) == 3.0f && P(3, 5) == 0.2f && P(3, 6) == 0.5f && P(3, 7) == 0.1f && P(3, 11) == 0.6f);
  CHECK(P(3, 15) == 1.5f && P(3, 19) == 0.4f && P(3, 16) == 0.9f);
  CHECK(P(4, 0) == 0.0f);
  CHECK(P(1, 21) == 0.6f && P(1, 22) == 0.2f && P(1, 20) == 0.0f);
  CHECK(P(2, 20) == 0.8f && P(2, 21) == 0.0f && P(3, 20) == 0.0f && P(3, 21) == 0.0f);
  /* lite: no refraction, no ripples, half the breathing, no sparkle, half a liquid metal's ripple */
  CHECK(sx_materials_pack(&ms, SX_MATERIALS_LITE, out) == 3);
  CHECK(P(2, 1) == 0.0f && P(1, 1) == 0.9f && P(3, 5) == 0.0f && P(3, 11) == 0.3f);
  CHECK(P(2, 20) == 0.0f && P(1, 22) == 0.1f && P(1, 21) == 0.6f);
  /* off: every slot plain, so the shader takes the old path */
  CHECK(sx_materials_pack(&ms, SX_MATERIALS_OFF, out) == 0 && P(1, 0) == 0.0f && P(3, 0) == 0.0f && P(1, 21) == 0.0f);
#undef P
  CHECK(sx_materials_mode_from_name("full") == SX_MATERIALS_FULL && sx_materials_mode_from_name("lite") == 1);
  CHECK(sx_materials_mode_from_name("off") == 0 && sx_materials_mode_from_name("ultra") == -1);
  CHECK(sx_materials_mode_from_name(NULL) == -1);
  CHECK(strcmp(sx_materials_mode_name(SX_MATERIALS_LITE), "lite") == 0 && strcmp(sx_materials_mode_name(7), "?") == 0);
  CHECK(sx_material_kind_from_name("organic") == SX_MAT_ORGANIC && sx_material_kind_from_name("glass") == -1);
  CHECK(sx_material_kind_from_name(NULL) == -1 && sx_material_kind_from_name("plain") == 0);
}

TEST(matcap_bake) {
  static unsigned char a[SX_MATCAP_SIZE * SX_MATCAP_SIZE], b[SX_MATCAP_SIZE * SX_MATCAP_SIZE];
  float key[5][4] = {{0.5f, 0.6f, 0.6f, 1.2f}, {-0.6f, 0.2f, 0.5f, 0.5f}, {0, 0, 0, 1}, {0, -1, 0.2f, 0.3f},
                     {1, 0, 0, 9}};
  int i, lo = 255, hi = 0, n = 0, seen[256] = {0};
  sx_matcap_bake(a, (const float(*)[4])key, 5, 0.06f); /* the fifth light is ignored */
  sx_matcap_bake(b, (const float(*)[4])key, 4, 0.06f);
  CHECK(memcmp(a, b, sizeof a) == 0);
  for (i = 0; i < SX_MATCAP_SIZE * SX_MATCAP_SIZE; i++) {
    if (a[i] < lo) lo = a[i];
    if (a[i] > hi) hi = a[i];
    if (!seen[a[i]]) n++;
    seen[a[i]] = 1;
  }
  /* never 0 (transparent in an index texture), a real highlight, and banded into at most 16 levels */
  CHECK(lo >= 1 && hi == 255 && n <= 16 && n >= 4);
  /* the highlight sits toward the key light (upper right), not the lower left */
  CHECK(a[16 * SX_MATCAP_SIZE + 44] > a[48 * SX_MATCAP_SIZE + 16]);
  /* no lights: ambient and the rim only */
  sx_matcap_bake(b, (const float(*)[4])key, -1, 0.0f);
  CHECK(b[32 * SX_MATCAP_SIZE + 32] == 1 && b[0] > 1);
}

TEST(material_wobble_bound) {
  sx_material m;
  float p[3] = {3, 4, 5}, t;
  sx_material_default(&m);
  CHECK(sx_material_wobble(&m, p, 1.0f) == 0.0f);
  m.wobble[0] = 0.3f;
  m.wobble[1] = 0.1f; /* clamped period */
  m.wobble[2] = 0.0f; /* clamped scale */
  m.breath = 0.2f;
  for (t = 0; t < 20; t += 0.37f) {
    float w = sx_material_wobble(&m, p, t);
    CHECK(w <= 0.5f + 1e-5f && w >= -0.5f - 1e-5f);
  }
}

/* add-relic-stations: the pillow patch the relic skins are made of */
TEST(mesh_patch) {
  sx_mesh m;
  sx_part_style s;
  float c[3] = {0, 0, 0}, u[3] = {4, 0, 0}, v[3] = {0, 0, -4}, z[3] = {0, 0, 0};
  int i, mid;
  sx_mesh_init(&m);
  sx_style_default(&s);
  s.material = 2.0f;
  /* u x v = (0, 16, 0): the normal is +y; h = 1 swells the middle up by 1 */
  sx_mesh_patch(&m, c, u, v, 1.0f, 4, 2, &s);
  CHECK(m.nv == 5 * 3 && m.ni == 4 * 2 * 6);
  mid = 1 * 5 + 2; /* row 1 of 0..2, column 2 of 0..4: the centre */
  CHECK(m.v[SX_VTX_FLOATS * mid + 1] > 0.999f && m.v[SX_VTX_FLOATS * mid + 4] > 0.999f);
  for (i = 0; i < m.nv; i++) {
    const float *p = m.v + SX_VTX_FLOATS * i;
    CHECK(p[1] >= -1e-6f && p[1] <= 1.0001f); /* never below the base plane */
    CHECK(p[12] == 2.0f);
  }
  /* the corners stay on the base plane; an edge vertex leans outward */
  CHECK(m.v[1] == 0.0f && m.v[4] == 1.0f && m.v[SX_VTX_FLOATS * 5 + 3] < 0.0f);
  sx_mesh_free(&m);
  /* clamps, a dent, and nothing for a degenerate patch */
  sx_mesh_init(&m);
  sx_mesh_patch(&m, c, u, v, -0.5f, 0, 200, &s);
  CHECK(m.nv == 2 * 65);
  sx_mesh_free(&m);
  sx_mesh_init(&m);
  sx_mesh_patch(&m, c, u, v, -0.5f, 100, 2, &s);
  CHECK(m.nv == 65 * 3 && m.v[SX_VTX_FLOATS * (65 + 32) + 1] < -0.49f);
  sx_mesh_free(&m);
  sx_mesh_init(&m);
  sx_mesh_patch(&m, c, u, z, 1.0f, 4, 4, &s);
  CHECK(m.nv == 0);
  sx_mesh_free(&m);
}

/* add-material-system: a mesh without materials hashes as it did before the 13th vertex float */
TEST(mesh_hash_material) {
  sx_mesh a, b;
  sx_part_style s;
  float mn[3] = {0, 0, 0}, mx[3] = {1, 2, 3};
  uint64_t h0, h1;
  sx_mesh_init(&a);
  sx_mesh_init(&b);
  sx_style_default(&s);
  sx_mesh_box(&a, mn, mx, &s);
  s.material = 3.0f;
  sx_mesh_box(&b, mn, mx, &s);
  h0 = sx_mesh_hash(&a);
  h1 = sx_mesh_hash(&b);
  CHECK(h0 != h1);
  {
    /* the old hash: the 12 floats per vertex as one stream, then the indices */
    float buf[12 * 64];
    int i, k;
    CHECK(a.nv <= 64);
    for (i = 0; i < a.nv; i++)
      for (k = 0; k < 12; k++) buf[12 * i + k] = a.v[SX_VTX_FLOATS * i + k];
    CHECK(h0 == sx_hash64_combine(sx_hash64(buf, sizeof(float) * 12 * (size_t)a.nv),
                                  sx_hash64(a.idx, sizeof(uint32_t) * (size_t)a.ni)));
  }
  sx_mesh_free(&a);
  sx_mesh_free(&b);
  sx_mesh_init(&a);
  CHECK(sx_mesh_hash(&a) == sx_mesh_hash(&a));
  sx_mesh_free(&a);
}
