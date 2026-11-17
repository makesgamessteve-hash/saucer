/* SPDX-License-Identifier: MIT */
#include "sx_engine.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lauxlib.h"
#include "lualib.h"
#include "sx_fs.h"
#include "sx_log.h"
#include "sx_net.h"
#include "sx_rng.h"
#include "sx_ser.h"

void sx_script_push_cmds(lua_State *L, const sx_cmd *cmds, int n);
void sx_script_push_view(lua_State *L, int index);
int sx_script_new_env(lua_State *L, const char *mod_id);

static void copy_str(char *dst, size_t cap, const char *src) {
  size_t n = strlen(src);
  if (n >= cap) n = cap - 1;
  memcpy(dst, src, n);
  dst[n] = 0;
}

void sx_options_default(sx_options *o) {
  memset(o, 0, sizeof *o);
  copy_str(o->root, sizeof o->root, ".");
  o->seed = 1;
  o->local_players = 1;
  o->viewports = 1;
  o->width = 1280;
  o->height = 720;
  o->screenshot_tick = 120;
  o->net_port = 47800;
  o->net_players = 2;
  o->net_delay = 3;
}

const char *sx_usage(void) {
  return "usage: saucer [options]\n"
         "  --root DIR            folder containing data/ and mods/ (default: beside the binary)\n"
         "  --user-dir DIR        saves, bindings and logs\n"
         "  --mods a,b            enable only these mods (base is always loaded)\n"
         "  --mods-dir DIR        folder with user mods (default: <root>/mods)\n"
         "  --seed N              universe seed\n"
         "  --headless            null renderer/audio, no window\n"
         "  --script FILE         run a game test script (implies --headless --test)\n"
         "  --test-lua DIR        run Lua unit specs (implies --headless --test)\n"
         "  --filter TEXT         only spec files whose name contains TEXT\n"
         "  --coverage            collect Lua coverage with luacov (test mode)\n"
         "  --ticks N             stop after N ticks (headless)\n"
         "  --local-players N     local player slots (1-4)\n"
         "  --viewports N         viewport count (1, 2 or 4)\n"
         "  --record FILE         record a .srep replay\n"
         "  --play FILE           play back and verify a .srep replay\n"
         "  --restore-every-tick  snapshot+restore before every tick\n"
         "  --screenshot FILE     save a PNG of the frame at --screenshot-tick (windowed)\n"
         "  --screenshot-tick N   tick for --screenshot (default 120)\n"
         "  --windowed            run a --script in the game window (screenshot tours)\n"
         "  --width W --height H  window size\n"
         "  --coop                allow extra devices to join as P2-P4 (gamepad A, F2)\n"
         "  --split-keyboard      P2 plays on the right half of the keyboard\n"
         "  --split horizontal|vertical  two-player split (default vertical)\n"
         "  --host [PORT]         host a network game (UDP, default port 47800)\n"
         "  --join HOST[:PORT]    join a network game\n"
         "  --net-players N       network players the host waits for (2-4, default 2)\n"
         "  --net-delay N         lockstep input delay in ticks (1-12, default 3)\n"
         "  --net-web host|guest  network game over the web shell's WebRTC data channel\n"
         "  --hardcore            a new game starts in Hardcore\n"
         "  --test                enable test/debug checks\n"
         "  --quiet               less logging\n";
}

int sx_options_parse(sx_options *o, int argc, char **argv, char *err, int errlen) {
  int i;
  for (i = 1; i < argc; i++) {
    const char *a = argv[i];
    const char *v = i + 1 < argc ? argv[i + 1] : NULL;
#define NEEDV()                                                                                                        \
  do {                                                                                                                 \
    if (!v) {                                                                                                          \
      snprintf(err, (size_t)errlen, "%s needs a value", a);                                                            \
      return 0;                                                                                                        \
    }                                                                                                                  \
    i++;                                                                                                               \
  } while (0)
    if (strcmp(a, "--root") == 0) { NEEDV(); copy_str(o->root, sizeof o->root, v); }
    else if (strcmp(a, "--user-dir") == 0) { NEEDV(); copy_str(o->user_dir, sizeof o->user_dir, v); }
    else if (strcmp(a, "--mods") == 0) { NEEDV(); copy_str(o->mods, sizeof o->mods, v); }
    else if (strcmp(a, "--mods-dir") == 0) { NEEDV(); copy_str(o->mods_dir, sizeof o->mods_dir, v); }
    else if (strcmp(a, "--seed") == 0) { NEEDV(); o->seed = strtoull(v, NULL, 10); }
    else if (strcmp(a, "--headless") == 0) o->headless = 1;
    else if (strcmp(a, "--script") == 0) { NEEDV(); copy_str(o->script, sizeof o->script, v); o->headless = o->test_mode = 1; }
    else if (strcmp(a, "--test-lua") == 0) { NEEDV(); copy_str(o->test_lua, sizeof o->test_lua, v); o->headless = o->test_mode = 1; }
    else if (strcmp(a, "--filter") == 0) { NEEDV(); copy_str(o->filter, sizeof o->filter, v); }
    else if (strcmp(a, "--coverage") == 0) o->coverage = 1;
    else if (strcmp(a, "--ticks") == 0) { NEEDV(); o->max_ticks = atoll(v); }
    else if (strcmp(a, "--local-players") == 0) { NEEDV(); o->local_players = atoi(v); }
    else if (strcmp(a, "--viewports") == 0) { NEEDV(); o->viewports = atoi(v); }
    else if (strcmp(a, "--record") == 0) { NEEDV(); copy_str(o->record, sizeof o->record, v); }
    else if (strcmp(a, "--play") == 0) { NEEDV(); copy_str(o->play, sizeof o->play, v); }
    else if (strcmp(a, "--restore-every-tick") == 0) o->restore_every_tick = 1;
    else if (strcmp(a, "--screenshot") == 0) { NEEDV(); copy_str(o->screenshot, sizeof o->screenshot, v); }
    else if (strcmp(a, "--screenshot-tick") == 0) { NEEDV(); o->screenshot_tick = atoll(v); }
    else if (strcmp(a, "--width") == 0) { NEEDV(); o->width = atoi(v); }
    else if (strcmp(a, "--height") == 0) { NEEDV(); o->height = atoi(v); }
    else if (strcmp(a, "--coop") == 0) o->coop = 1;
    else if (strcmp(a, "--split-keyboard") == 0) o->split_keyboard = 1;
    else if (strcmp(a, "--split") == 0) { NEEDV(); o->split_horizontal = strcmp(v, "horizontal") == 0; }
    else if (strcmp(a, "--host") == 0) {
      o->net_role = SX_NET_HOST;
      if (v && v[0] >= '0' && v[0] <= '9') { o->net_port = atoi(v); i++; }
    } else if (strcmp(a, "--join") == 0) {
      char *colon;
      NEEDV();
      o->net_role = SX_NET_GUEST;
      copy_str(o->net_addr, sizeof o->net_addr, v);
      colon = strrchr(o->net_addr, ':');
      if (colon) { o->net_port = atoi(colon + 1); *colon = 0; }
    } else if (strcmp(a, "--net-players") == 0) { NEEDV(); o->net_players = atoi(v); }
    else if (strcmp(a, "--net-delay") == 0) { NEEDV(); o->net_delay = atoi(v); }
    else if (strcmp(a, "--net-web") == 0) {
      NEEDV();
      o->net_web = 1;
      o->net_role = strcmp(v, "guest") == 0 ? SX_NET_GUEST : SX_NET_HOST;
    } else if (strcmp(a, "--hardcore") == 0) o->hardcore = 1;
    else if (strcmp(a, "--test") == 0) o->test_mode = 1;
    else if (strcmp(a, "--quiet") == 0) o->quiet = 1;
    else if (strcmp(a, "--windowed") == 0) o->windowed = 1;
    else if (strcmp(a, "--help") == 0 || strcmp(a, "-h") == 0) o->show_help = 1;
    else {
      snprintf(err, (size_t)errlen, "unknown option %s", a);
      return 0;
    }
#undef NEEDV
  }
  if (o->windowed) o->headless = 0;
  if (o->local_players < 1 || o->local_players > SX_MAX_PLAYERS) {
    snprintf(err, (size_t)errlen, "--local-players must be 1-4");
    return 0;
  }
  if (o->net_role && (o->net_players < 2 || o->net_players > SX_MAX_PLAYERS || o->net_delay < 1 ||
                      o->net_delay > 12 || o->net_port <= 0 || o->net_port > 65535)) {
    snprintf(err, (size_t)errlen, "--net-players must be 2-4, --net-delay 1-12 and the port 1-65535");
    return 0;
  }
  if (o->net_role && (o->play[0] || o->local_players > 1 || o->coop)) {
    snprintf(err, (size_t)errlen, "a network game has one local player (no --play, --coop or --local-players)");
    return 0;
  }
  if (o->viewports < 1 || o->viewports > SX_MAX_VIEWPORTS) {
    snprintf(err, (size_t)errlen, "--viewports must be 1-4");
    return 0;
  }
  if (!o->user_dir[0]) {
    char *d = sx_path_join(o->root, ".saucer-user");
    copy_str(o->user_dir, sizeof o->user_dir, d);
    free(d);
  }
  return 1;
}

int sx_ticks_for_frame(double *acc, double elapsed) {
  int n;
  if (elapsed < 0) elapsed = 0;
  if (elapsed > 1.0) elapsed = 1.0;
  *acc += elapsed;
  n = (int)(*acc * SX_TICK_HZ + 1e-9);
  if (n > SX_MAX_TICKS_PER_FRAME) {
    n = SX_MAX_TICKS_PER_FRAME;
    *acc = 0; /* drop the backlog instead of spiralling */
    return n;
  }
  *acc -= (double)n / SX_TICK_HZ;
  if (*acc < 0) *acc = 0;
  return n;
}

uint64_t sx_engine_state_hash(sx_engine *e) {
  uint64_t h;
  lua_rawgeti(e->L, LUA_REGISTRYINDEX, e->state_ref);
  h = sx_ser_hash(e->L, -1);
  lua_pop(e->L, 1);
  return sx_hash64_combine(h, (uint64_t)e->tick);
}

unsigned char *sx_engine_snapshot(sx_engine *e, size_t *len) {
  sx_buf b = {0};
  char err[128];
  lua_rawgeti(e->L, LUA_REGISTRYINDEX, e->state_ref);
  if (!sx_ser_write(e->L, -1, &b, err, sizeof err)) {
    SX_ERROR("snapshot: %s", err);
    lua_pop(e->L, 1);
    sx_buf_free(&b);
    return NULL;
  }
  lua_pop(e->L, 1);
  *len = b.len;
  return b.data;
}

int sx_engine_restore(sx_engine *e, const unsigned char *data, size_t len) {
  lua_State *L = e->L;
  char err[128];
  int st;
  if (!sx_ser_read(L, data, len, err, sizeof err) || !lua_istable(L, -1)) {
    if (lua_gettop(L) && !lua_istable(L, -1)) lua_pop(L, 1);
    SX_ERROR("restore: %s", err);
    return 0;
  }
  /* replace contents in place so the state table identity is kept */
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->state_ref);
  st = lua_gettop(L);
  for (;;) {
    lua_pushnil(L);
    if (!lua_next(L, st)) break;
    lua_pop(L, 1);
    lua_pushnil(L);
    lua_rawset(L, st);
  }
  lua_pushnil(L);
  while (lua_next(L, st - 1)) {
    lua_pushvalue(L, -2);
    lua_insert(L, -2);
    lua_rawset(L, st);
  }
  lua_pop(L, 1); /* state; snapshot copy stays below */
  lua_pop(L, 1);
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->state_ref);
  sx_script_call_hook(e, "on_restore", 1, 1LL << 40);
  return 1;
}

static char *bindings_path(sx_engine *e, int player) {
  char name[64];
  snprintf(name, sizeof name, "bindings_p%d.txt", player);
  return sx_path_join(e->opt.user_dir, name);
}

int sx_engine_save_bindings(sx_engine *e, int player) {
  sx_buf b = {0};
  int a, k, ok;
  char *path;
  if (player < 1 || player > SX_MAX_PLAYERS) return 0;
  for (a = 0; a < e->input.nactions; a++) {
    for (k = 0; k < e->input.players[player - 1].nbindings[a]; k++) {
      char line[128], bind[64];
      int n;
      sx_binding_format(&e->input.players[player - 1].bindings[a][k], bind, sizeof bind);
      n = snprintf(line, sizeof line, "%s %s\n", e->input.actions[a].name, bind);
      sx_buf_put(&b, line, (size_t)n);
    }
  }
  sx_fs_mkdirs(e->opt.user_dir);
  path = bindings_path(e, player);
  ok = sx_fs_write_atomic(path, b.data ? (const void *)b.data : "", b.len);
  free(path);
  sx_buf_free(&b);
  return ok;
}

int sx_engine_load_bindings(sx_engine *e, int player) {
  char *path = bindings_path(e, player), *text, *p;
  int cleared[SX_MAX_ACTIONS] = {0};
  text = sx_fs_read(path, NULL);
  free(path);
  if (!text) return 0;
  p = text;
  while (*p) {
    char name[64], bind[64];
    char *e2 = strchr(p, '\n');
    if (e2) *e2 = 0;
    if (sscanf(p, "%63s %63s", name, bind) == 2) {
      int a = sx_input_find_action(&e->input, name);
      if (a >= 0) {
        if (!cleared[a]) {
          sx_input_clear_bindings(&e->input, player, a);
          cleared[a] = 1;
        }
        sx_input_bind(&e->input, player, a, bind);
      }
    }
    if (!e2) break;
    p = e2 + 1;
  }
  free(text);
  return 1;
}

static void fail(sx_engine *e, const char *msg) {
  if (!e->failed) {
    e->failed = 1;
    copy_str(e->fail_msg, sizeof e->fail_msg, msg);
  }
  SX_ERROR("%s", msg);
}

static int start_test_script(sx_engine *e) {
  lua_State *L = e->L, *co;
  size_t n;
  char *src = sx_fs_read(e->opt.script, &n), chunk[600];
  int env;
  if (!src) {
    fail(e, "cannot read test script");
    return 0;
  }
  co = lua_newthread(L);
  e->test_co_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  e->test_co = co;
  snprintf(chunk, sizeof chunk, "@%s", e->opt.script);
  if (luaL_loadbufferx(co, src, n, chunk, "t") != LUA_OK) {
    char m[600];
    snprintf(m, sizeof m, "test script: %s", lua_tostring(co, -1));
    free(src);
    fail(e, m);
    return 0;
  }
  free(src);
  env = sx_script_new_env(L, "test");
  lua_rawgeti(co, LUA_REGISTRYINDEX, env);
  lua_setupvalue(co, -2, 1);
  e->test_wait = 0;
  return 1;
}

static void resume_test(sx_engine *e) {
  int nres = 0, st;
  if (!e->test_co || e->test_done) return;
  e->budget_left = 1LL << 40;
  st = lua_resume(e->test_co, e->L, 0, &nres);
  if (st == LUA_OK) {
    e->test_done = 1;
  } else if (st != LUA_YIELD) {
    char m[700];
    luaL_traceback(e->L, e->test_co, lua_tostring(e->test_co, -1), 0);
    snprintf(m, sizeof m, "test failed: %s", lua_tostring(e->L, -1));
    lua_pop(e->L, 1);
    fail(e, m);
    e->test_done = 1;
  }
  if (nres) lua_pop(e->test_co, nres);
}

/* luacov must hook in before any mod code runs so module bodies count */
static void start_coverage(lua_State *L) {
  lua_getglobal(L, "require");
  lua_pushstring(L, "luacov");
  if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
    fprintf(stderr, "luacov not available: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
}

/* add-home-among-stars: open the transport; a desktop guest learns the
 * host's seed (and its slot) before the sim is built */
static int start_net(sx_engine *e) {
  char err[160] = "";
  sx_net_transport tr;
  sx_options *o = &e->opt;
  if (o->net_web) tr = sx_net_web_transport();
  else if (o->net_role == SX_NET_HOST) tr = sx_net_udp_host(o->net_port, err, sizeof err);
  else tr = sx_net_udp_join(o->net_addr, o->net_port, err, sizeof err);
  if (!tr.send) {
    SX_ERROR("network: %s", err);
    return 0;
  }
  sx_net_init(&e->net, o->net_role, tr, SX_NET_API, e->modset_hash);
  if (o->net_role == SX_NET_HOST) {
    sx_net_host_config(&e->net, o->seed, o->net_players, o->net_delay);
    SX_INFO("network: hosting on port %d for %d players (seed %llu)", o->net_port, o->net_players,
            (unsigned long long)o->seed);
  } else if (!o->net_web) {
    int64_t t0 = sx_net_clock_ms();
    SX_INFO("network: joining %s:%d", o->net_addr, o->net_port);
    while (!e->net.local_slot && e->net.state == SX_NET_WAITING && sx_net_clock_ms() - t0 < 20000) {
      sx_net_poll(&e->net, sx_net_clock_ms());
      if (!e->net.local_slot) sx_net_sleep_ms(5);
    }
    if (!e->net.local_slot) {
      SX_ERROR("network: %s", e->net.state == SX_NET_REJECTED ? e->net.status : "no answer from the host");
      sx_net_close(&e->net);
      return 0;
    }
    o->seed = e->net.seed;
    SX_INFO("network: joined as player %d (seed %llu)", e->net.local_slot, (unsigned long long)o->seed);
  } else {
    /* the web guest's seed comes with the host's offer code (--seed); the
     * WELCOME is checked against it */
    e->net.seed = o->seed;
  }
  e->net_on = 1;
  e->net_wait_since = sx_net_clock_ms();
  return 1;
}

sx_engine *sx_engine_create(const sx_options *o) {
  sx_engine *e = (sx_engine *)calloc(1, sizeof(sx_engine));
  char *base, *mods;
  int i;
  e->opt = *o;
  sx_vfs_init(&e->vfs);
  sx_modset_init(&e->mods);
  base = sx_path_join(o->root, "data/base");
  mods = o->mods_dir[0] ? sx_strdup(o->mods_dir) : sx_path_join(o->root, "mods");
  if (!sx_modset_scan(&e->mods, base, mods, o->mods[0] ? o->mods : NULL)) {
    free(base);
    free(mods);
    sx_engine_destroy(e);
    return NULL;
  }
  free(base);
  free(mods);
  sx_modset_resolve(&e->mods, SX_ENGINE_API);
  e->modset_hash = 0x5A0CE5ull;
  for (i = 0; i < e->mods.order_count; i++) {
    sx_mod *m = &e->mods.mods[e->mods.order[i]];
    sx_vfs_mount(&e->vfs, m->root, m->id);
    e->modset_hash = sx_hash64_combine(e->modset_hash, sx_hash64_str(m->id));
    e->modset_hash = sx_hash64_combine(e->modset_hash, sx_hash64_str(m->version));
  }
  /* replays dictate seed and player count */
  if (o->play[0]) {
    char err[256];
    if (!sx_replay_load(&e->play, o->play, err, sizeof err)) {
      SX_ERROR("replay: %s", err);
      sx_engine_destroy(e);
      return NULL;
    }
    e->playing = 1;
    e->opt.seed = e->play.seed;
    e->opt.local_players = e->play.players;
    if (e->play.slots > e->play.players) e->opt.coop = 1;
    if (e->play.modset_hash != e->modset_hash) SX_WARN("replay was recorded with a different mod set");
  }
  sx_input_init(&e->input, e->opt.local_players);
  e->input.coop_enabled = e->opt.coop;
  sx_touch_init(&e->touch, (float)o->width / (float)(o->height > 0 ? o->height : 1));
  sx_xr_init(&e->xr);
  sx_phys_init(&e->phys);
  sx_render_init(&e->render);
  {
    size_t n = 0;
    char *d = sx_vfs_read(&e->vfs, "authored/fonts/font8x8.png", &n);
    e->render.font_tex = d ? sx_render_texture_from_png(&e->render, "authored/fonts/font8x8.png",
                                                        (const unsigned char *)d, (int)n)
                           : sx_render_fallback_font(&e->render);
    free(d);
  }
  if (sx_script_open(e) && o->coverage) start_coverage(e->L);
  if (!e->L || !sx_script_load_mods(e)) {
    SX_ERROR("failed to start the Lua runtime / base mod");
    sx_engine_destroy(e);
    return NULL;
  }
  if (o->record[0]) {
    /* add-wider-dark: with co-op on every slot sends frames (joins replay in order) */
    sx_replay_init(&e->rec, SX_VERSION, e->opt.seed, e->modset_hash, e->opt.local_players);
    if (o->coop) e->rec.slots = SX_MAX_PLAYERS;
    e->recording = 1;
  }
  if (e->opt.net_role && !start_net(e)) {
    sx_engine_destroy(e);
    return NULL;
  }
  /* on_init(ctx) */
  lua_createtable(e->L, 0, 4);
  lua_rawgeti(e->L, LUA_REGISTRYINDEX, e->state_ref);
  lua_setfield(e->L, -2, "state");
  lua_pushinteger(e->L, (lua_Integer)e->opt.seed);
  lua_setfield(e->L, -2, "seed");
  lua_pushinteger(e->L, e->opt.local_players);
  lua_setfield(e->L, -2, "players");
  lua_pushboolean(e->L, e->opt.headless);
  lua_setfield(e->L, -2, "headless");
  lua_pushboolean(e->L, e->opt.hardcore);
  lua_setfield(e->L, -2, "hardcore");
  if (e->net_on) {
    lua_pushinteger(e->L, e->net.local_slot);
    lua_setfield(e->L, -2, "net_slot");
  }
  sx_script_call_hook(e, "on_init", 1, 1LL << 40);
  for (i = 1; i <= e->opt.local_players; i++) sx_engine_load_bindings(e, i);
  if (o->split_keyboard) sx_input_split_keyboard(&e->input, 2);
  e->render.settings.split_horizontal = o->split_horizontal;
  if (o->script[0] && start_test_script(e)) resume_test(e);
  return e;
}

void sx_engine_destroy(sx_engine *e) {
  if (!e) return;
  if (e->net_on) sx_net_close(&e->net);
  sx_script_close(e);
  sx_render_free(&e->render);
  sx_phys_free(&e->phys);
  sx_replay_free(&e->rec);
  sx_replay_free(&e->play);
  sx_modset_free(&e->mods);
  sx_vfs_free(&e->vfs);
  free(e);
}

static void apply_injection(sx_engine *e, sx_cmd *cmds, int n) {
  int i, k;
  for (i = 0; i < n; i++) {
    int p = cmds[i].player - 1;
    uint32_t b = cmds[i].buttons;
    if (p < 0 || p >= SX_MAX_PLAYERS) continue;
    for (k = 0; k < SX_MAX_BUTTON_ACTIONS; k++) {
      if (e->inject[p].buttons_ticks[k] > 0) {
        b |= 1u << k;
        e->inject[p].buttons_ticks[k]--;
      }
    }
    for (k = 0; k < SX_NUM_AXES; k++) {
      if (e->inject[p].axes_ticks[k] > 0) {
        cmds[i].axes[k] = e->inject[p].axes[k];
        e->inject[p].axes_ticks[k]--;
      }
    }
    cmds[i].buttons = b;
    cmds[i].edges = b & ~e->inject_prev[p];
    e->inject_prev[p] = b;
  }
}

static void sample_devices(sx_engine *e, sx_cmd *cmds, int *n) {
  int i;
  sx_touch_apply(&e->touch, &e->input.raw);
  {
    float xv[SX_XR_COUNT];
    sx_xr_filter(&e->xr, xv);
    for (i = 0; i < SX_XR_COUNT; i++) e->input.raw.xr[i] = xv[i];
  }
  /* the head pose only steers anything while an immersive session runs */
  if (e->xr.session) sx_xr_aim(&e->xr, e->input.raw.aim);
  else memset(e->input.raw.aim, 0, sizeof e->input.raw.aim);
  e->input.xr_active = e->xr.session != 0;
  sx_input_build(&e->input, e->tick, cmds, n);
}

/* add-home-among-stars: one lockstep tick. The local frame sampled now runs
 * `delay` ticks later on every machine; the tick waits for everyone's frame. */
static int net_tick(sx_engine *e) {
  sx_net *n = &e->net;
  sx_cmd cmds[SX_MAX_PLAYERS];
  int cnt = 0;
  int64_t now = sx_net_clock_ms();
  sx_net_poll(n, now);
  if (n->role == SX_NET_GUEST && n->local_slot && n->seed != e->opt.seed) {
    fail(e, "network: the host plays a different seed");
    return 0;
  }
  if (n->state == SX_NET_RUNNING && n->local_slot && n->upto[n->local_slot - 1] < e->tick + n->delay) {
    sx_cmd local;
    sample_devices(e, cmds, &cnt);
    if (cnt) local = cmds[0];
    else memset(&local, 0, sizeof local);
    local.player = n->local_slot;
    apply_injection(e, &local, 1);
    /* a guest's first frame presses Use: that joins its slot in the sim */
    if (n->local_slot > 1 && !e->net_joined) {
      int a = sx_input_find_action(&e->input, "use");
      if (a >= 0) {
        local.buttons |= 1u << e->input.actions[a].slot;
        local.edges |= 1u << e->input.actions[a].slot;
      }
      e->net_joined = 1;
    }
    sx_net_push_local(n, e->tick + n->delay, &local);
  }
  sx_net_flush(n);
  if (n->state == SX_NET_DESYNC) {
    if (e->opt.test_mode) {
      fail(e, n->status);
      return 0;
    }
    if (!n->abandoned) SX_WARN("network: %s - the session ends, play goes on alone", n->status);
    sx_net_abandon(n);
  }
  if (!sx_net_ready(n, e->tick)) {
    e->net_stalled = 1;
    n->stalls++;
    if (e->opt.test_mode && now - e->net_wait_since > 60000) fail(e, "network: waited 60 s for the other players");
    return !e->failed;
  }
  e->net_stalled = 0;
  e->net_wait_since = now;
  cnt = sx_net_frames(n, e->tick, cmds);
  return sx_engine_step(e, cmds, cnt);
}

int sx_engine_tick(sx_engine *e) {
  sx_cmd cmds[SX_MAX_PLAYERS];
  int n;
  if (e->net_on) return net_tick(e);
  if (e->playing) {
    n = e->play.slots > e->play.players ? e->play.slots : e->play.players;
    if (n < 1 || n > SX_MAX_PLAYERS) n = 1;
    sx_replay_frames_for(&e->play, e->tick, cmds, n);
  } else {
    sample_devices(e, cmds, &n);
    apply_injection(e, cmds, n);
  }
  return sx_engine_step(e, cmds, n);
}

int sx_engine_step(sx_engine *e, const sx_cmd *cmds, int n) {
  lua_State *L = e->L;
  int i, nev;
  if (e->opt.restore_every_tick) {
    size_t len;
    unsigned char *snap = sx_engine_snapshot(e, &len);
    if (snap) {
      sx_engine_restore(e, snap, len);
      free(snap);
    }
  }
  memcpy(e->last_cmds, cmds, sizeof(sx_cmd) * (size_t)n);
  e->nlast_cmds = n;
  if (e->recording)
    for (i = 0; i < n; i++) sx_replay_add_frame(&e->rec, &cmds[i]);
  lua_pushnumber(L, 1.0 / SX_TICK_HZ);
  sx_script_push_cmds(L, cmds, n);
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->state_ref);
  sx_script_call_hook(e, "on_tick", 3, e->budget_tick > 0 ? e->budget_tick : 20000000LL);
  e->ticks_called++;
  /* events, in emission order */
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->events_ref);
  nev = (int)lua_rawlen(L, -1);
  for (i = 1; i <= nev; i++) {
    lua_rawgeti(L, -1, i);
    lua_rawgeti(L, LUA_REGISTRYINDEX, e->state_ref);
    sx_script_call_hook(e, "on_event", 2, 20000000LL);
  }
  lua_pop(L, 1);
  lua_newtable(L);
  lua_rawseti(L, LUA_REGISTRYINDEX, e->events_ref);
  e->tick++;
  if (e->net_on && e->tick % SX_NET_HASH_EVERY == 0) sx_net_add_hash(&e->net, e->tick, sx_engine_state_hash(e));
  if (e->tick % SX_HASH_INTERVAL == 0) {
    uint64_t h = sx_engine_state_hash(e), want = 0;
    if (e->recording) sx_replay_add_hash(&e->rec, e->tick, h);
    if (e->playing && !e->replay_failed && !sx_replay_check_hash(&e->play, e->tick, h, &want)) {
      char m[200];
      snprintf(m, sizeof m, "replay diverged at tick %lld: hash %016llx, expected %016llx", (long long)e->tick,
               (unsigned long long)h, (unsigned long long)want);
      e->replay_failed = 1;
      fail(e, m);
    }
  }
  if (e->test_co && !e->test_done) {
    if (e->test_wait > 0) e->test_wait--;
    if (e->test_wait == 0) resume_test(e);
  }
  return !e->failed;
}

/* players in the sim right now (#state.players) */
int sx_engine_sim_players(sx_engine *e) {
  lua_State *L = e->L;
  int n = 0;
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->state_ref);
  if (lua_getfield(L, -1, "players") == LUA_TTABLE) n = (int)lua_rawlen(L, -1);
  lua_pop(L, 2);
  return n;
}

void sx_engine_render(sx_engine *e, double alpha) {
  lua_State *L = e->L;
  int i, nviews = e->xr.session ? e->xr.nviews : e->opt.viewports, nsim = 0;
  uint64_t before = 0;
  /* add-wider-dark: split screen follows the players in the game (a third
   * player gets a quad; the spare quarter shows the sector map) */
  if (!e->xr.session && !e->net_on) {
    nsim = sx_engine_sim_players(e);
    if (nsim == 3) nsim = 4;
    if (nsim > nviews) nviews = nsim;
  }
  if (nviews < 1) nviews = 1;
  e->render.xr = e->xr.session != 0;
  sx_render_begin_frame(&e->render, nviews);
  if (e->xr.session) {
    for (i = 0; i < nviews && i < 2; i++) {
      sx_viewport *v = &e->render.views[i];
      v->player = 1;
      v->cam.has_matrices = 1;
      memcpy(v->cam.view, e->xr.views[i].view, sizeof v->cam.view);
      memcpy(v->cam.proj, e->xr.views[i].proj, sizeof v->cam.proj);
      v->x = e->xr.views[i].x;
      v->y = e->xr.views[i].y;
      v->w = e->xr.views[i].w;
      v->h = e->xr.views[i].h;
    }
  } else if (e->net_on) {
    /* a network player sees their own saucer (player 1 until the slot joins) */
    int me = e->net.local_slot && e->net.local_slot <= sx_engine_sim_players(e) ? e->net.local_slot : 1;
    for (i = 0; i < nviews; i++) e->render.views[i].player = me;
  } else {
    int np = sx_engine_sim_players(e);
    if (np < e->input.nplayers) np = e->input.nplayers;
    for (i = 0; i < nviews; i++)
      e->render.views[i].player = np > 1 ? (i < np ? i + 1 : 0) : 1;
  }
  if (e->opt.test_mode) before = sx_engine_state_hash(e);
  e->in_render = 1;
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->state_ref);
  sx_script_push_readonly(L, -1);
  lua_remove(L, -2);
  for (i = 0; i < nviews; i++) {
    lua_pushnumber(L, alpha);
    sx_script_push_view(L, i);
    lua_pushvalue(L, -3);
    sx_script_call_hook(e, "on_render", 3, 50000000LL);
  }
  lua_pop(L, 1);
  e->in_render = 0;
  if (e->opt.test_mode && sx_engine_state_hash(e) != before) fail(e, "on_render mutated the sim state");
}

int sx_engine_finish(sx_engine *e) {
  if (e->recording && !sx_replay_save(&e->rec, e->opt.record)) fail(e, "cannot write replay");
  return e->failed ? 1 : 0;
}

int sx_run_headless(const sx_options *o) {
  sx_engine *e = sx_engine_create(o);
  int64_t limit;
  int status;
  if (!e) return 2;
  limit = o->max_ticks;
  if (limit <= 0) limit = e->playing ? e->play.end_tick : (o->script[0] ? 60 * 60 * 10 : 600);
  while (!e->failed && e->tick < limit) {
    if (o->script[0] && e->test_done) break;
    sx_engine_tick(e);
    if (e->net_on && e->net_stalled) {
      sx_net_sleep_ms(1); /* waiting for a peer's frame */
      continue;
    }
    /* headless renders still run the view code (it must not touch the sim);
     * with three or four split views every sixth tick is plenty */
    if (e->tick % (sx_engine_sim_players(e) > 2 ? 6 : 2) == 0) sx_engine_render(e, 1.0);
    e->naudio = 0; /* null audio */
  }
  if (o->script[0] && !e->test_done && !e->failed) fail(e, "test script did not finish before the tick limit");
  status = sx_engine_finish(e);
  printf("ticks %lld final_hash %016llx %s\n", (long long)e->tick, (unsigned long long)sx_engine_state_hash(e),
         status ? "FAIL" : "OK");
  if (e->net_on) {
    /* stderr too: the loopback test runs two of these in one pipeline */
    fprintf(stderr, "net slot %d ticks %lld final_hash %016llx checks %lld stalls %lld sent %lld received %lld %s\n",
            e->net.local_slot, (long long)e->tick, (unsigned long long)sx_engine_state_hash(e),
            (long long)e->net.checks, (long long)e->net.stalls, (long long)e->net.sent, (long long)e->net.received,
            status ? "FAIL" : "OK");
  }
  if (status) fprintf(stderr, "%s\n", e->fail_msg);
  sx_engine_destroy(e);
  return status;
}

int sx_run_lua_tests(const sx_options *o) {
  sx_options oo = *o;
  sx_engine *e;
  sx_strlist files = {0};
  lua_State *L;
  char *runner;
  int i, n = 0, env, status;
  oo.test_mode = oo.headless = 1;
  e = sx_engine_create(&oo);
  if (!e) return 2;
  L = e->L;
  sx_fs_list(o->test_lua, 0, &files);
  env = sx_script_new_env(L, "test");
  /* specs may use io/debug for tooling; the game sandbox is unchanged */
  lua_rawgeti(L, LUA_REGISTRYINDEX, env);
  lua_getglobal(L, "debug");
  lua_setfield(L, -2, "debug");
  lua_getglobal(L, "io");
  lua_setfield(L, -2, "io");
  lua_getglobal(L, "os");
  lua_setfield(L, -2, "os");
  lua_pushvalue(L, -1);
  lua_setfield(L, LUA_REGISTRYINDEX, "sx.test_env");
  lua_newtable(L);
  for (i = 0; i < files.count; i++) {
    size_t len = strlen(files.items[i]);
    if (len > 9 && strcmp(files.items[i] + len - 9, "_spec.lua") == 0 &&
        (!o->filter[0] || strstr(files.items[i], o->filter))) {
      char *p = sx_path_join(o->test_lua, files.items[i]);
      lua_pushstring(L, p);
      lua_rawseti(L, -2, ++n);
      free(p);
    }
  }
  lua_setfield(L, -2, "SPEC_FILES");
  lua_pop(L, 1);
  sx_strlist_free(&files);
  runner = sx_path_join(o->test_lua, "runner.lua");
  status = 1;
  if (sx_script_run_file_in_env(e, runner, env, 1)) {
    status = lua_tointeger(L, -1) == 0 ? 0 : 1;
    lua_pop(L, 1);
  } else {
    fprintf(stderr, "runner error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
  free(runner);
  if (o->coverage) {
    lua_getglobal(L, "require");
    lua_pushstring(L, "luacov.runner");
    if (lua_pcall(L, 1, 1, 0) == LUA_OK) {
      lua_getfield(L, -1, "shutdown");
      if (lua_pcall(L, 0, 0, 0) != LUA_OK) lua_pop(L, 1);
    }
    lua_pop(L, 1);
  }
  sx_engine_destroy(e);
  return status;
}

int sx_main(int argc, char **argv) {
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
  if (o.test_lua[0]) return sx_run_lua_tests(&o);
  o.headless = 1;
  return sx_run_headless(&o);
}
