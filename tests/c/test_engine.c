/* engine lifecycle, options, runners — SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include "lauxlib.h"
#include "lualib.h"
#include "sx_engine.h"
#include "sx_fs.h"
#include "sx_log.h"
#include "test.h"

#define USER "build/test-tmp/user"

static void opts(sx_options *o) {
  sx_options_default(o);
  strcpy(o->user_dir, USER);
  o->headless = 1;
  o->test_mode = 1;
  o->quiet = 1;
}

static int parse(sx_options *o, int argc, char **argv) {
  char err[256];
  sx_options_default(o);
  return sx_options_parse(o, argc, argv, err, sizeof err);
}

TEST(options_parse_all) {
  sx_options o;
  char *all[] = {"x", "--root", "r", "--user-dir", "u", "--mods", "a,b", "--mods-dir", "m", "--seed", "9",
                 "--headless", "--script", "s.lua", "--test-lua", "t", "--filter", "f", "--coverage", "--ticks", "5",
                 "--local-players", "2", "--viewports", "2", "--record", "r.srep", "--play", "p.srep",
                 "--restore-every-tick", "--screenshot", "a.png", "--screenshot-tick", "3", "--width", "640",
                 "--height", "360", "--coop", "--test", "--quiet", "--help",
                 "--split-keyboard", "--split", "horizontal"};
  char *one[] = {"x", "--seed"};
  char *unk[] = {"x", "--what"};
  char *lp[] = {"x", "--local-players", "5"};
  char *vp[] = {"x", "--viewports", "0"};
  char *h[] = {"x", "-h", "--root", "rr"};
  char *win[] = {"x", "--script", "s.lua", "--windowed"};
  CHECK(parse(&o, (int)(sizeof all / sizeof *all), all));
  CHECK(o.seed == 9 && o.local_players == 2 && o.coop && o.show_help && o.max_ticks == 5 && o.width == 640);
  CHECK(o.screenshot_tick == 3 && o.restore_every_tick && o.coverage && o.height == 360);
  CHECK(o.split_keyboard && o.split_horizontal);
  CHECK_STR(o.mods_dir, "m");
  CHECK(!parse(&o, 2, one) && !parse(&o, 2, unk) && !parse(&o, 3, lp) && !parse(&o, 3, vp));
  CHECK(parse(&o, 4, h) && strcmp(o.user_dir, "rr/.saucer-user") == 0);
  sx_options_default(&o);
  CHECK(parse(&o, 4, win) && o.windowed && !o.headless && o.test_mode);
  CHECK(strstr(sx_usage(), "--seed") != NULL);
}

TEST(ticks_for_frame) {
  double acc = 0;
  CHECK(sx_ticks_for_frame(&acc, 1.0 / 60) == 1);
  CHECK(sx_ticks_for_frame(&acc, 0.5 / 60) == 0);
  CHECK(sx_ticks_for_frame(&acc, 0.5 / 60) == 1);
  CHECK(sx_ticks_for_frame(&acc, -1) == 0);
  CHECK(sx_ticks_for_frame(&acc, 5) == SX_MAX_TICKS_PER_FRAME && acc == 0);
}

TEST(engine_lifecycle) {
  sx_options o;
  sx_engine *e;
  unsigned char *snap;
  size_t len;
  uint64_t h;
  int i;
  opts(&o);
  o.viewports = 2;
  e = sx_engine_create(&o);
  CHECK(e != NULL);
  if (!e) return;
  for (i = 0; i < 70; i++) CHECK(sx_engine_tick(e));
  sx_engine_render(e, 0.5);
  h = sx_engine_state_hash(e);
  snap = sx_engine_snapshot(e, &len);
  CHECK(snap != NULL);
  sx_engine_tick(e);
  CHECK(sx_engine_restore(e, snap, len));
  free(snap);
  CHECK(e->tick == 71);
  (void)h;
  CHECK(!sx_engine_restore(e, (const unsigned char *)"junk", 4));
  /* XR stereo render path */
  e->xr.session = 1;
  e->xr.nviews = 2;
  sx_engine_render(e, 1.0);
  CHECK(e->render.xr && e->render.views[1].cam.has_matrices);
  e->xr.session = 0;
  /* bindings persist per player */
  CHECK(sx_engine_save_bindings(e, 1));
  CHECK(!sx_engine_save_bindings(e, 0));
  CHECK(sx_engine_load_bindings(e, 1));
  CHECK(!sx_engine_load_bindings(e, 3));
  sx_fs_write_atomic(USER "/bindings_p2.txt", "nonsense\nlift key:Q\nlift key:E\nunknown key:W", 43);
  CHECK(sx_engine_load_bindings(e, 2));
  CHECK(e->input.players[1].nbindings[sx_input_find_action(&e->input, "lift")] == 2);
  /* snapshot of a state holding a function fails cleanly */
  lua_rawgeti(e->L, LUA_REGISTRYINDEX, e->state_ref);
  lua_pushcfunction(e->L, luaopen_base);
  lua_setfield(e->L, -2, "bad");
  lua_pop(e->L, 1);
  CHECK(sx_engine_snapshot(e, &len) == NULL);
  CHECK(sx_engine_finish(e) == 0);
  sx_engine_destroy(e);
  sx_engine_destroy(NULL);
}

TEST(engine_restore_every_tick) {
  sx_options o;
  sx_engine *e;
  opts(&o);
  o.restore_every_tick = 1;
  e = sx_engine_create(&o);
  CHECK(e != NULL);
  if (!e) return;
  CHECK(sx_engine_tick(e) && sx_engine_tick(e));
  sx_engine_destroy(e);
}

TEST(engine_create_failures) {
  sx_options o;
  opts(&o);
  strcpy(o.root, "tests/fixtures/roots/nobase");
  CHECK(sx_engine_create(&o) == NULL);
  strcpy(o.root, "tests/fixtures/roots/brokenbase");
  CHECK(sx_engine_create(&o) == NULL);
  opts(&o);
  strcpy(o.play, "tests/fixtures/replays/missing.srep");
  CHECK(sx_engine_create(&o) == NULL);
  CHECK(sx_run_headless(&o) == 2);
  strcpy(o.test_lua, "tests/lua");
  CHECK(sx_run_lua_tests(&o) == 2);
}

TEST(engine_runners) {
  sx_options o;
  sx_fs_mkdirs("build/test-tmp");
  opts(&o);
  strcpy(o.script, "tests/fixtures/scripts/fail.lua");
  CHECK(sx_run_headless(&o) == 1);
  strcpy(o.script, "tests/fixtures/scripts/syntax.lua");
  CHECK(sx_run_headless(&o) == 1);
  strcpy(o.script, "tests/fixtures/scripts/missing.lua");
  CHECK(sx_run_headless(&o) == 1);
  strcpy(o.script, "tests/fixtures/scripts/forever.lua");
  o.max_ticks = 30;
  CHECK(sx_run_headless(&o) == 1);
  opts(&o);
  strcpy(o.play, "tests/fixtures/replays/diverge.srep");
  CHECK(sx_run_headless(&o) == 1);
  opts(&o);
  o.max_ticks = 61;
  strcpy(o.record, "build/test-tmp/rec.srep");
  CHECK(sx_run_headless(&o) == 0);
  CHECK(sx_fs_is_file("build/test-tmp/rec.srep"));
  strcpy(o.record, "build/test-tmp/no/such/dir/rec.srep");
  CHECK(sx_run_headless(&o) == 1);
  opts(&o);
  strcpy(o.test_lua, "tests/fixtures/scripts"); /* no runner.lua */
  CHECK(sx_run_lua_tests(&o) == 1);
}

TEST(engine_main) {
  char *help[] = {"saucer", "--help"};
  char *bad[] = {"saucer", "--nope"};
  char *run[] = {"saucer", "--ticks", "3", "--quiet", "--user-dir", USER};
  char *lua[] = {"saucer", "--test-lua", "tests/fixtures/scripts", "--quiet", "--user-dir", USER};
  CHECK(sx_main(2, help) == 0);
  CHECK(sx_main(2, bad) == 2);
  CHECK(sx_main(6, run) == 0);
  CHECK(sx_main(6, lua) == 1);
  sx_log_set_quiet(1);
}
