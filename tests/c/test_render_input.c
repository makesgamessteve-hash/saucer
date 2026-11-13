/* render lists, matrices, input mapping — SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include "sx_fs.h"
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
  for (i = 0; i < 4; i++) sx_input_bind(&in, 1, fire, "key:F1");
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
  CHECK(n == 2 && sx_input_owner(&in, SX_DEV_PAD0 + 1) == 2 && in.nplayers == 2);
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
