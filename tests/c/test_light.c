/* add-realistic-lighting: the light list, its selection and the shadow budget (MIT). */
#include "test.h"
#include "../../engine/src/core/sx_light.h"

static void xform(const float m[16], const float p[3], float o[4]) {
  int i;
  for (i = 0; i < 4; i++) o[i] = m[i] * p[0] + m[4 + i] * p[1] + m[8 + i] * p[2] + m[12 + i];
}

static sx_light point_at(float x, float y, float z, float intensity, float range) {
  sx_light l;
  sx_light_defaults(&l, SX_LIGHT_POINT);
  l.pos[0] = x;
  l.pos[1] = y;
  l.pos[2] = z;
  l.intensity = intensity;
  l.range = range;
  l.shadow = 1;
  return l;
}

TEST(light_list_add_defaults_and_full) {
  static sx_lighting lt;
  sx_light l;
  int i;
  memset(&lt, 0, sizeof lt);
  sx_lighting_reset(&lt);
  CHECK_EQ_INT(lt.on, 0);
  CHECK_NEAR(lt.exposure, 1.0f, 1e-6f);
  sx_light_defaults(&l, SX_LIGHT_SPOT);
  CHECK_NEAR(l.dir[1], -1.0f, 1e-6f);
  CHECK_EQ_INT(l.slot, -1);
  l.range = 0.0f;           /* clamped */
  l.dir[0] = 3.0f;          /* normalised */
  l.dir[1] = 0.0f;
  l.cos_inner = 0.1f;       /* inner never wider than outer */
  l.cos_outer = 0.5f;
  CHECK_EQ_INT(sx_lighting_add(&lt, &l), 0);
  CHECK_NEAR(lt.lights[0].range, 0.1f, 1e-6f);
  CHECK_NEAR(lt.lights[0].dir[0], 1.0f, 1e-5f);
  CHECK_NEAR(lt.lights[0].cos_inner, 0.5f, 1e-6f);
  sx_light_defaults(&l, SX_LIGHT_SUN);
  l.dir[1] = 0.0f; /* a zero direction falls back to straight up */
  sx_lighting_add(&lt, &l);
  CHECK_NEAR(lt.lights[1].dir[1], 1.0f, 1e-6f);
  for (i = 2; i < SX_MAX_LIGHTS; i++) CHECK_EQ_INT(sx_lighting_add(&lt, &l), i);
  CHECK_EQ_INT(sx_lighting_add(&lt, &l), -1);
  CHECK_EQ_INT(sx_lighting_add(&lt, &l), -1);
  CHECK_EQ_INT(lt.dropped, 2);
  CHECK_EQ_INT(lt.nlights, SX_MAX_LIGHTS);
  sx_lighting_reset(&lt);
  CHECK_EQ_INT(lt.nlights, 0);
  CHECK_EQ_INT(lt.dropped, 0);
}

TEST(light_quality_names_and_budgets) {
  sx_shadow_budget b;
  CHECK_EQ_INT(sx_shadow_quality_from_name("off"), SX_SHADOWS_OFF);
  CHECK_EQ_INT(sx_shadow_quality_from_name("low"), SX_SHADOWS_LOW);
  CHECK_EQ_INT(sx_shadow_quality_from_name("high"), SX_SHADOWS_HIGH);
  CHECK_EQ_INT(sx_shadow_quality_from_name("ultra"), -1);
  CHECK_EQ_INT(sx_shadow_quality_from_name(NULL), -1);
  CHECK_STR(sx_shadow_quality_name(SX_SHADOWS_HIGH), "high");
  CHECK_STR(sx_shadow_quality_name(SX_SHADOWS_LOW), "low");
  CHECK_STR(sx_shadow_quality_name(SX_SHADOWS_OFF), "off");
  b = sx_shadow_budget_for(SX_SHADOWS_HIGH, 1);
  CHECK_EQ_INT(b.atlas, 1024);
  CHECK_EQ_INT(b.cascades, 2);
  CHECK_EQ_INT(b.spots, 2);
  CHECK_EQ_INT(b.omni, 3);
  CHECK_EQ_INT(b.max_lights, SX_MAX_ACTIVE_LIGHTS);
  b = sx_shadow_budget_for(SX_SHADOWS_HIGH, 2);
  CHECK_EQ_INT(b.omni, 2);
  CHECK_EQ_INT(b.cascades, 2);
  b = sx_shadow_budget_for(SX_SHADOWS_HIGH, 4); /* a four-way split screen gets the minimum */
  CHECK_EQ_INT(b.cascades, 1);
  CHECK_EQ_INT(b.spots, 1);
  CHECK_EQ_INT(b.omni, 0);
  CHECK_EQ_INT(b.atlas, 512);
  CHECK_EQ_INT(b.max_lights, 8);
  CHECK_NEAR(b.radius[0], 60.0f, 1e-6f);
  b = sx_shadow_budget_for(SX_SHADOWS_LOW, 1);
  CHECK_EQ_INT(b.atlas, 512);
  CHECK_EQ_INT(b.cascades, 1);
  CHECK_EQ_INT(b.max_lights, 8);
  b = sx_shadow_budget_for(SX_SHADOWS_OFF, 3);
  CHECK_EQ_INT(b.atlas, 0);
  CHECK_EQ_INT(b.cascades, 0);
  CHECK_EQ_INT(b.omni, 0);
}

TEST(light_reach_inverse_square_and_range) {
  sx_light l = point_at(0, 0, 0, 100.0f, 40.0f), s;
  float p1[3] = {2, 0, 0}, p2[3] = {4, 0, 0}, far[3] = {41, 0, 0};
  float a = sx_light_reach(&l, p1), b = sx_light_reach(&l, p2);
  CHECK(a > b);
  CHECK(b > 0.0f);
  /* inverse square with a soft source a quarter of the range across, in a smooth range window */
  {
    float q[3] = {0, 10, 0}, x = 100.0f / 1600.0f, w = 1.0f - x * x;
    CHECK_NEAR(sx_light_reach(&l, q), 100.0f * w * w / (100.0f + SX_LIGHT_SOFT * 1600.0f), 1e-5f);
  }
  l.range = 40.0f;
  CHECK_NEAR(sx_light_reach(&l, far), 0.0f, 1e-9f);
  sx_light_defaults(&s, SX_LIGHT_SUN);
  s.intensity = 2.5f;
  CHECK_NEAR(sx_light_reach(&s, far), 2.5f, 1e-6f);
}

TEST(light_select_sun_first_then_brightest) {
  static sx_lighting lt;
  sx_shadow_budget b = sx_shadow_budget_for(SX_SHADOWS_HIGH, 1);
  float cam[3] = {0, 0, 0}, fwd[3] = {0, 0, 1};
  sx_light sun, dim = point_at(30, 0, 0, 50.0f, 60.0f), bright = point_at(3, 0, 0, 400.0f, 30.0f);
  sx_light gone = point_at(1000, 0, 0, 1e6f, 20.0f), spot;
  memset(&lt, 0, sizeof lt);
  sx_lighting_reset(&lt);
  sx_light_defaults(&sun, SX_LIGHT_SUN);
  sun.intensity = 0.001f; /* even a faint sun comes first */
  sun.shadow = 1;
  sun.dir[0] = 0.3f;
  sx_lighting_add(&lt, &dim);
  sx_lighting_add(&lt, &bright);
  sx_lighting_add(&lt, &gone);
  sx_lighting_add(&lt, &sun);
  sx_light_defaults(&spot, SX_LIGHT_SPOT);
  spot.pos[1] = 2.0f;
  spot.intensity = 100.0f;
  spot.range = 50.0f;
  spot.shadow = 1;
  spot.cos_outer = 0.9f;
  sx_lighting_add(&lt, &spot);
  sx_lighting_select(&lt, &b, cam, fwd);
  CHECK_EQ_INT(lt.nactive, 4); /* the far one is out of reach */
  CHECK_EQ_INT(lt.active[0], 3);
  CHECK_EQ_INT(lt.active[1], 1);
  CHECK_EQ_INT(lt.lights[3].slot, 0);
  CHECK_EQ_INT(lt.cascades, 2);
  CHECK_EQ_INT(lt.spots, 1);
  CHECK_EQ_INT(lt.omni, 2);
  CHECK_EQ_INT(lt.atlas, 1024);
  CHECK_EQ_INT(lt.lights[4].slot, SX_SHADOW_CASCADES);
  CHECK(lt.lights[1].slot >= SX_SHADOW_CASCADES + SX_SHADOW_SPOTS);
  CHECK_NEAR(lt.casc_radius[0], 24.0f, 1e-6f);
  CHECK_NEAR(lt.shadow_rect[1][0], 0.5f, 1e-6f);
  CHECK_NEAR(lt.shadow_rect[SX_SHADOW_CASCADES + 1][0], 0.25f, 1e-6f);
  CHECK_NEAR(lt.shadow_rect[SX_SHADOW_CASCADES + SX_SHADOW_SPOTS + 2][1], 0.75f, 1e-6f);
  /* the light budget caps the list; shadows off casts nothing */
  b = sx_shadow_budget_for(SX_SHADOWS_OFF, 1);
  b.max_lights = 2;
  sx_lighting_select(&lt, &b, cam, fwd);
  CHECK_EQ_INT(lt.nactive, 2);
  CHECK_EQ_INT(lt.cascades + lt.spots + lt.omni, 0);
  CHECK_EQ_INT(lt.lights[3].slot, -1);
  /* a focus point (the saucer, not the eye) scores the lights */
  {
    float before = lt.lights[0].score;
    lt.has_focus = 1;
  lt.focus[0] = 30;
  lt.focus[1] = 0;
  lt.focus[2] = 0;
    b.max_lights = 3;
    sx_lighting_select(&lt, &b, cam, fwd);
    CHECK(lt.lights[0].score > before);
  }
}

TEST(light_select_sticky_omni_and_shared_headlights) {
  static sx_lighting lt;
  sx_shadow_budget b = sx_shadow_budget_for(SX_SHADOWS_HIGH, 1);
  float cam[3] = {0, 0, 0}, fwd[3] = {1, 0, 0};
  sx_light a = point_at(5, 0, 0, 300.0f, 30.0f), c = point_at(0, 0, 5, 200.0f, 30.0f);
  sx_light h1, h2, other;
  int slot_c;
  memset(&lt, 0, sizeof lt);
  sx_lighting_reset(&lt);
  sx_lighting_add(&lt, &a);
  sx_lighting_add(&lt, &c);
  sx_lighting_select(&lt, &b, cam, fwd);
  slot_c = lt.lights[1].slot;
  CHECK(slot_c >= 0);
  /* next frame the brighter light is gone: the other keeps its block */
  sx_lighting_reset(&lt);
  sx_lighting_add(&lt, &c);
  sx_lighting_select(&lt, &b, cam, fwd);
  CHECK_EQ_INT(lt.lights[0].slot, slot_c);
  CHECK_NEAR(lt.omni_key[slot_c - SX_SHADOW_CASCADES - SX_SHADOW_SPOTS][2], 5.0f, 1e-6f);
  /* a saucer's two headlights share one map; a third owner's spot gets the second */
  sx_lighting_reset(&lt);
  sx_light_defaults(&h1, SX_LIGHT_SPOT);
  h1.dir[0] = 1;
  h1.dir[1] = 0;
  h1.intensity = 2600;
  h1.range = 150;
  h1.shadow = 1;
  h1.owner = 1001;
  h1.pos[2] = -3.2f;
  h2 = h1;
  h2.pos[2] = 3.2f;
  other = h1;
  other.owner = 1002;
  other.pos[1] = 20.0f;
  sx_lighting_add(&lt, &h1);
  sx_lighting_add(&lt, &h2);
  sx_lighting_add(&lt, &other);
  sx_lighting_select(&lt, &b, cam, fwd);
  CHECK_EQ_INT(lt.lights[0].slot, lt.lights[1].slot);
  CHECK(lt.lights[2].slot != lt.lights[0].slot && lt.lights[2].slot >= 0);
  CHECK_EQ_INT(lt.spots, 2);
}

TEST(light_cube_faces_and_matrices) {
  float f[3], r[3], u[3], m[16], o[4], rect[4], blk[4] = {0.5f, 0.5f, 0.375f, 0.25f};
  float pos[3] = {1, 2, 3}, eye[3] = {0, 0, 0}, fwd[3] = {0, -1, 0}, up[3] = {0, 1, 0};
  int face;
  for (face = 0; face < 6; face++) {
    float p[3];
    sx_cube_face_basis(face, f, r, u);
    CHECK_NEAR(f[0] * r[0] + f[1] * r[1] + f[2] * r[2], 0.0f, 1e-6f);
    CHECK_NEAR(f[0] * u[0] + f[1] * u[1] + f[2] * u[2], 0.0f, 1e-6f);
    sx_cube_face_view(pos, face, m);
    p[0] = pos[0] + f[0] * 4;
    p[1] = pos[1] + f[1] * 4;
    p[2] = pos[2] + f[2] * 4;
    xform(m, p, o); /* straight ahead of the face: on its axis, 4 m in front (-z) */
    CHECK_NEAR(o[0], 0.0f, 1e-5f);
    CHECK_NEAR(o[1], 0.0f, 1e-5f);
    CHECK_NEAR(o[2], -4.0f, 1e-5f);
  }
  sx_cube_face_basis(9, f, r, u); /* out of range: face 0 */
  CHECK_NEAR(f[0], 1.0f, 1e-6f);
  sx_shadow_face_rect(blk, 4, rect);
  CHECK_NEAR(rect[0], 0.625f, 1e-6f);
  CHECK_NEAR(rect[1], 0.625f, 1e-6f);
  CHECK_NEAR(rect[2], 0.125f, 1e-6f);
  CHECK_NEAR(rect[3], 0.125f, 1e-6f);
  /* looking along the up hint still gives a valid view */
  sx_mat4_look(m, eye, fwd, up);
  {
    float p[3] = {0, -5, 0};
    xform(m, p, o);
    CHECK_NEAR(o[2], -5.0f, 1e-5f);
  }
  fwd[0] = 1;
  fwd[1] = 0;
  up[0] = 1;
  up[1] = 0;
  sx_mat4_look(m, eye, fwd, up);
  {
    float p[3] = {7, 0, 0};
    xform(m, p, o);
    CHECK_NEAR(o[2], -7.0f, 1e-5f);
  }
  /* a sun cascade maps its centre near the middle of the map and in the depth range */
  {
    float dir[3] = {0.3f, 0.8f, 0.2f}, c[3] = {10, 0, -4};
    sx_shadow_sun_mat(dir, c, 24.0f, 1500.0f, 512, m);
    xform(m, c, o);
    CHECK(o[0] > -0.02f && o[0] < 0.02f);
    CHECK(o[1] > -0.02f && o[1] < 0.02f);
    CHECK(o[2] > -1.0f && o[2] < 1.0f);
    sx_shadow_sun_mat(dir, c, 24.0f, 1500.0f, 0, m); /* a bad resolution does not divide by zero */
    xform(m, c, o);
    CHECK(o[2] > -1.0f && o[2] < 1.0f);
  }
  /* a spot's map: a point down its axis lands in the middle */
  {
    sx_light l;
    float p[3] = {0, -10, 0};
    sx_light_defaults(&l, SX_LIGHT_SPOT);
    l.range = 50;
    sx_shadow_spot_mat(&l, m);
    xform(m, p, o);
    CHECK_NEAR(o[0] / o[3], 0.0f, 1e-4f);
    CHECK_NEAR(o[1] / o[3], 0.0f, 1e-4f);
    CHECK(o[2] / o[3] > -1.0f && o[2] / o[3] < 1.0f);
    l.cos_outer = -1.0f; /* a 180 degree cone is clamped */
    sx_shadow_spot_mat(&l, m);
    xform(m, p, o);
    CHECK(o[3] > 0.0f);
  }
}
