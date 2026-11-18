/* Lua runtime: sandboxed per-mod environments, instruction budget, VFS-based
 * require, read-only render proxies and the saucer.* API (v1).
 * SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include "sx_engine.h"
#include "sx_fs.h"
#include "sx_log.h"
#include "sx_math.h"
#include "sx_procgen.h"
#include "sx_rng.h"
#include "sx_ser.h"

#define ENGINE_KEY "sx.engine"
#define RNG_MT "sx.rng"
#define GRID_MT "sx.grid"
#define VIEW_MT "sx.view"
#define CMD_MT "sx.cmd"
#define RO_MT "sx.readonly"

static sx_engine *get_engine(lua_State *L) {
  sx_engine *e;
  lua_getfield(L, LUA_REGISTRYINDEX, ENGINE_KEY);
  e = (sx_engine *)lua_touserdata(L, -1);
  lua_pop(L, 1);
  return e;
}

/* ---------- helpers ---------- */
static void get_vec3(lua_State *L, int idx, double out[3]) {
  int i;
  luaL_checktype(L, idx, LUA_TTABLE);
  for (i = 0; i < 3; i++) {
    lua_geti(L, idx, i + 1);
    out[i] = luaL_optnumber(L, -1, 0.0);
    lua_pop(L, 1);
  }
}

static void push_vec3(lua_State *L, const double v[3]) {
  int i;
  lua_createtable(L, 3, 0);
  for (i = 0; i < 3; i++) {
    lua_pushnumber(L, v[i]);
    lua_rawseti(L, -2, i + 1);
  }
}

static float field_num(lua_State *L, int idx, const char *k, float def) {
  float v;
  lua_getfield(L, idx, k);
  v = lua_isnumber(L, -1) ? (float)lua_tonumber(L, -1) : def;
  lua_pop(L, 1);
  return v;
}

static int field_vec(lua_State *L, int idx, const char *k, float out[], int n) {
  int i, ok = 0;
  lua_getfield(L, idx, k);
  if (lua_istable(L, -1)) {
    ok = 1;
    for (i = 0; i < n; i++) {
      lua_geti(L, -1, i + 1); /* honours read-only state proxies */
      if (lua_isnumber(L, -1)) out[i] = (float)lua_tonumber(L, -1);
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  return ok;
}

/* ---------- saucer.log ---------- */
static int log_at(lua_State *L, sx_log_level lv) {
  const char *msg;
  int n = lua_gettop(L);
  if (n > 1) {
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "format");
    lua_insert(L, 1);
    lua_pop(L, 1);
    lua_call(L, n, 1);
  }
  msg = luaL_tolstring(L, 1, NULL);
  sx_log(lv, "%s", msg);
  return 0;
}
static int l_log_info(lua_State *L) { return log_at(L, SX_LOG_INFO); }
static int l_log_warn(lua_State *L) { return log_at(L, SX_LOG_WARN); }
static int l_log_error(lua_State *L) { return log_at(L, SX_LOG_ERROR); }

/* ---------- saucer.vfs ---------- */
static int l_vfs_read(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *p = luaL_checkstring(L, 1);
  size_t n;
  char *d = sx_vfs_read(&e->vfs, p, &n);
  if (!d) {
    lua_pushnil(L);
    lua_pushfstring(L, "not found: %s", p);
    return 2;
  }
  lua_pushlstring(L, d, n);
  free(d);
  return 1;
}

static int l_vfs_exists(lua_State *L) {
  sx_engine *e = get_engine(L);
  char *full = sx_vfs_resolve(&e->vfs, luaL_checkstring(L, 1), NULL);
  lua_pushboolean(L, full != NULL);
  free(full);
  return 1;
}

static int l_vfs_list(lua_State *L) {
  sx_engine *e = get_engine(L);
  sx_strlist l = {0};
  int i;
  sx_vfs_list(&e->vfs, luaL_optstring(L, 1, ""), &l);
  lua_createtable(L, l.count, 0);
  for (i = 0; i < l.count; i++) {
    lua_pushstring(L, l.items[i]);
    lua_rawseti(L, -2, i + 1);
  }
  sx_strlist_free(&l);
  return 1;
}

/* ---------- saucer.registry ---------- */
static void push_registry_kind(lua_State *L, const char *kind) {
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.registry");
  if (lua_getfield(L, -1, kind) != LUA_TTABLE) {
    lua_pop(L, 1);
    lua_newtable(L);
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, kind);
  }
  lua_remove(L, -2);
}

static int l_reg_define(lua_State *L) {
  const char *kind = luaL_checkstring(L, 1);
  luaL_checkany(L, 2);
  luaL_checktype(L, 3, LUA_TTABLE);
  push_registry_kind(L, kind);
  lua_pushvalue(L, 2);
  lua_pushvalue(L, 3);
  lua_rawset(L, -3);
  return 0;
}

static int l_reg_get(lua_State *L) {
  push_registry_kind(L, luaL_checkstring(L, 1));
  lua_pushvalue(L, 2);
  lua_rawget(L, -2);
  return 1;
}

/* extend(kind, { id = { field = value } }) merges fields into existing entries */
static int l_reg_extend(lua_State *L) {
  luaL_checktype(L, 2, LUA_TTABLE);
  push_registry_kind(L, luaL_checkstring(L, 1)); /* 3 */
  lua_pushnil(L);
  while (lua_next(L, 2)) {
    lua_pushvalue(L, -2);
    if (lua_rawget(L, 3) == LUA_TTABLE && lua_istable(L, -2)) {
      lua_pushnil(L);
      while (lua_next(L, -3)) {
        lua_pushvalue(L, -2);
        lua_insert(L, -2);
        lua_rawset(L, -4);
      }
      lua_pop(L, 2);
    } else {
      lua_pop(L, 1);
      lua_pushvalue(L, -2);
      lua_insert(L, -2);
      lua_rawset(L, 3);
    }
  }
  return 0;
}

static int l_util_sorted_keys(lua_State *L);
static int l_reg_all(lua_State *L) {
  int n, i;
  push_registry_kind(L, luaL_checkstring(L, 1)); /* 2 */
  lua_pushcfunction(L, l_util_sorted_keys);
  lua_pushvalue(L, 2);
  lua_call(L, 1, 1); /* 3 keys */
  n = (int)lua_rawlen(L, 3);
  lua_createtable(L, n, 0); /* 4 */
  for (i = 1; i <= n; i++) {
    lua_rawgeti(L, 3, i);
    lua_rawget(L, 2);
    lua_rawseti(L, 4, i);
  }
  return 1;
}

/* ---------- saucer.rng ---------- */
typedef struct l_rng {
  sx_pcg32 r;
  uint64_t seed;
} l_rng;

static l_rng *push_rng(lua_State *L, uint64_t seed) {
  l_rng *r = (l_rng *)lua_newuserdatauv(L, sizeof(l_rng), 0);
  r->seed = seed;
  sx_pcg32_seed(&r->r, seed, 0x5A0CE5ull);
  luaL_setmetatable(L, RNG_MT);
  return r;
}

static int l_rng_new(lua_State *L) {
  push_rng(L, (uint64_t)luaL_checkinteger(L, 1));
  return 1;
}

static int l_rng_int(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  lua_Integer lo = luaL_checkinteger(L, 2), hi = luaL_checkinteger(L, 3);
  lua_pushinteger(L, (lua_Integer)sx_pcg32_range(&r->r, lo, hi));
  return 1;
}

static int l_rng_fixed(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  lua_pushinteger(L, sx_pcg32_fixed(&r->r));
  return 1;
}

static int l_rng_float(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  lua_pushnumber(L, (lua_Number)sx_pcg32_fixed(&r->r) / 65536.0);
  return 1;
}

static int l_rng_pick(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  lua_Integer n;
  luaL_checktype(L, 2, LUA_TTABLE);
  n = (lua_Integer)lua_rawlen(L, 2);
  if (n == 0) return 0;
  lua_rawgeti(L, 2, 1 + (lua_Integer)sx_pcg32_bounded(&r->r, (uint32_t)n));
  return 1;
}

/* weighted({ {weight, value}, ... }) or ({ {w=..., v=...} }) -> value, index */
static int l_rng_weighted(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  lua_Integer n, i, total = 0, pick, acc = 0;
  luaL_checktype(L, 2, LUA_TTABLE);
  n = (lua_Integer)lua_rawlen(L, 2);
  for (i = 1; i <= n; i++) {
    lua_rawgeti(L, 2, i);
    if (lua_rawgeti(L, -1, 1) != LUA_TNUMBER) {
      lua_pop(L, 1);
      lua_getfield(L, -1, "w");
    }
    total += luaL_optinteger(L, -1, 0) > 0 ? luaL_optinteger(L, -1, 0) : 0;
    lua_pop(L, 2);
  }
  if (total <= 0) return 0;
  pick = (lua_Integer)sx_pcg32_range(&r->r, 0, total - 1);
  for (i = 1; i <= n; i++) {
    lua_Integer w;
    int keyed;
    lua_rawgeti(L, 2, i);
    keyed = lua_rawgeti(L, -1, 1) != LUA_TNUMBER;
    if (keyed) {
      lua_pop(L, 1);
      lua_getfield(L, -1, "w");
    }
    w = luaL_optinteger(L, -1, 0);
    lua_pop(L, 1);
    if (w > 0) {
      acc += w;
      if (pick < acc) {
        if (keyed) lua_getfield(L, -1, "v");
        else lua_rawgeti(L, -1, 2);
        lua_pushinteger(L, i);
        return 2;
      }
    }
    lua_pop(L, 1);
  }
  return 0; /* unreachable */
}

static int l_rng_child(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  push_rng(L, sx_seed_child(r->seed, luaL_checkstring(L, 2), (uint64_t)luaL_optinteger(L, 3, 0)));
  return 1;
}

static int l_rng_seed(lua_State *L) {
  l_rng *r = (l_rng *)luaL_checkudata(L, 1, RNG_MT);
  lua_pushinteger(L, (lua_Integer)r->seed);
  return 1;
}

static int l_hash64(lua_State *L) {
  int i, n = lua_gettop(L);
  uint64_t h = 0x5A0CE5ull;
  for (i = 1; i <= n; i++) {
    if (lua_type(L, i) == LUA_TNUMBER && lua_isinteger(L, i)) h = sx_hash64_combine(h, (uint64_t)lua_tointeger(L, i));
    else {
      size_t len;
      const char *s = luaL_tolstring(L, i, &len);
      h = sx_hash64_combine(h, sx_hash64(s, len));
      lua_pop(L, 1);
    }
  }
  lua_pushinteger(L, (lua_Integer)h);
  return 1;
}

static int l_seed_child(lua_State *L) {
  lua_pushinteger(L, (lua_Integer)sx_seed_child((uint64_t)luaL_checkinteger(L, 1), luaL_checkstring(L, 2),
                                                (uint64_t)luaL_optinteger(L, 3, 0)));
  return 1;
}

/* ---------- saucer.math ---------- */
static int l_m_sin(lua_State *L) { lua_pushnumber(L, sx_sin(luaL_checknumber(L, 1))); return 1; }
static int l_m_cos(lua_State *L) { lua_pushnumber(L, sx_cos(luaL_checknumber(L, 1))); return 1; }
static int l_m_sqrt(lua_State *L) { lua_pushnumber(L, sx_sqrt(luaL_checknumber(L, 1))); return 1; }
static int l_m_atan(lua_State *L) { lua_pushnumber(L, sx_atan(luaL_checknumber(L, 1))); return 1; }
static int l_m_atan2(lua_State *L) {
  lua_pushnumber(L, sx_atan2(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
  return 1;
}
static int l_m_wrap(lua_State *L) { lua_pushnumber(L, sx_wrap_angle(luaL_checknumber(L, 1))); return 1; }
static int l_m_fx(lua_State *L) { lua_pushinteger(L, sx_fx_from(luaL_checknumber(L, 1))); return 1; }
static int l_m_fx_to(lua_State *L) { lua_pushnumber(L, sx_fx_to((sx_fx)luaL_checkinteger(L, 1))); return 1; }
static int l_m_fxmul(lua_State *L) {
  lua_pushinteger(L, sx_fx_mul((sx_fx)luaL_checkinteger(L, 1), (sx_fx)luaL_checkinteger(L, 2)));
  return 1;
}
static int l_m_fxdiv(lua_State *L) {
  lua_pushinteger(L, sx_fx_div((sx_fx)luaL_checkinteger(L, 1), (sx_fx)luaL_checkinteger(L, 2)));
  return 1;
}
static int l_m_random(lua_State *L) { return luaL_error(L, "math.random is not deterministic; use saucer.rng"); }

/* ---------- saucer.util ---------- */
static int key_less(lua_State *L, int a, int b) {
  int ta = lua_type(L, a), tb = lua_type(L, b);
  if (ta != tb) return ta < tb;
  if (ta == LUA_TNUMBER || ta == LUA_TSTRING) return lua_compare(L, a, b, LUA_OPLT);
  if (ta == LUA_TBOOLEAN) return !lua_toboolean(L, a) && lua_toboolean(L, b);
  return 0;
}

static int l_util_sorted_keys(lua_State *L) {
  int n = 0, i, j;
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_newtable(L); /* 2 */
  lua_pushnil(L);
  while (lua_next(L, 1)) {
    lua_pop(L, 1);
    /* insertion sort into array */
    lua_pushvalue(L, -1); /* key copy */
    for (i = n; i > 0; i--) {
      lua_rawgeti(L, 2, i);
      if (key_less(L, -2, -1)) {
        lua_rawseti(L, 2, i + 1);
      } else {
        lua_pop(L, 1);
        break;
      }
    }
    lua_rawseti(L, 2, i + 1);
    n++;
  }
  (void)j;
  return 1;
}

static int sorted_iter(lua_State *L) {
  lua_Integer i = lua_tointeger(L, lua_upvalueindex(3)) + 1;
  lua_pushinteger(L, i);
  lua_replace(L, lua_upvalueindex(3));
  if (lua_rawgeti(L, lua_upvalueindex(2), i) == LUA_TNIL) return 0;
  lua_pushvalue(L, -1);
  lua_gettable(L, lua_upvalueindex(1));
  return 2;
}

static int l_util_sorted_pairs(lua_State *L) {
  luaL_checkany(L, 1);
  if (!lua_istable(L, 1)) {
    /* read-only proxies: sort the target's keys */
    if (lua_getmetatable(L, 1)) {
      lua_pop(L, 1);
      lua_getfield(L, LUA_REGISTRYINDEX, "sx.ro_targets");
      lua_pushvalue(L, 1);
      lua_rawget(L, -2);
      lua_remove(L, -2);
    } else {
      return luaL_error(L, "sorted_pairs expects a table");
    }
    lua_pushcfunction(L, l_util_sorted_keys);
    lua_insert(L, -2);
    lua_call(L, 1, 1);
  } else {
    lua_pushcfunction(L, l_util_sorted_keys);
    lua_pushvalue(L, 1);
    lua_call(L, 1, 1);
  }
  lua_pushvalue(L, 1);
  lua_insert(L, -2);
  lua_pushinteger(L, 0);
  lua_pushcclosure(L, sorted_iter, 3);
  return 1;
}

/* ---------- read-only proxies ---------- */
static int ro_index(lua_State *L) {
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.ro_targets");
  lua_pushvalue(L, 1);
  lua_rawget(L, -2); /* target */
  lua_pushvalue(L, 2);
  lua_gettable(L, -2);
  if (lua_istable(L, -1)) sx_script_push_readonly(L, lua_gettop(L));
  return 1;
}

static int ro_newindex(lua_State *L) {
  lua_Debug ar;
  const char *where = "?";
  int line = 0;
  if (lua_getstack(L, 1, &ar) && lua_getinfo(L, "Sl", &ar)) {
    where = ar.short_src;
    line = ar.currentline;
  }
  return luaL_error(L, "%s:%d: render code cannot mutate sim state (key '%s')", where, line,
                    luaL_tolstring(L, 2, NULL));
}

static int ro_len(lua_State *L) {
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.ro_targets");
  lua_pushvalue(L, 1);
  lua_rawget(L, -2);
  lua_pushinteger(L, (lua_Integer)luaL_len(L, -1));
  return 1;
}

static int ro_next(lua_State *L) {
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.ro_targets");
  lua_pushvalue(L, 1);
  lua_rawget(L, -2); /* target */
  lua_pushvalue(L, 2);
  if (!lua_next(L, -2)) return 0;
  if (lua_istable(L, -1)) {
    sx_script_push_readonly(L, lua_gettop(L));
    lua_replace(L, -2);
  }
  return 2;
}

static int ro_pairs(lua_State *L) {
  lua_pushcfunction(L, ro_next);
  lua_pushvalue(L, 1);
  lua_pushnil(L);
  return 3;
}

void sx_script_push_readonly(lua_State *L, int idx) {
  idx = lua_absindex(L, idx);
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.ro_cache"); /* weak-keyed target -> proxy */
  lua_pushvalue(L, idx);
  if (lua_rawget(L, -2) != LUA_TNIL) {
    lua_remove(L, -2);
    return;
  }
  lua_pop(L, 1);
  lua_newtable(L); /* proxy */
  luaL_setmetatable(L, RO_MT);
  lua_pushvalue(L, idx);
  lua_pushvalue(L, -2);
  lua_rawset(L, -4); /* cache[target] = proxy */
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.ro_targets");
  lua_pushvalue(L, -2);
  lua_pushvalue(L, idx);
  lua_rawset(L, -3); /* targets[proxy] = target */
  lua_pop(L, 1);
  lua_remove(L, -2); /* cache */
}

static int l_util_readonly(lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  sx_script_push_readonly(L, 1);
  return 1;
}

/* ---------- saucer.players / input ---------- */
static int l_players_count(lua_State *L) {
  sx_engine *e = get_engine(L);
  lua_pushinteger(L, e->input.nplayers);
  return 1;
}

static int l_players_get(lua_State *L) {
  sx_engine *e = get_engine(L);
  lua_Integer i = luaL_checkinteger(L, 1);
  if (i < 1 || i > e->input.nplayers || !e->input.players[i - 1].active) return 0;
  lua_createtable(L, 0, 3);
  lua_pushinteger(L, i);
  lua_setfield(L, -2, "index");
  lua_pushinteger(L, i - 1);
  lua_setfield(L, -2, "record_index");
  lua_pushstring(L, sx_input_device_mode(&e->input, (int)i));
  lua_setfield(L, -2, "mode");
  return 1;
}

static int l_input_define(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *name = luaL_checkstring(L, 1);
  const char *kind = luaL_optstring(L, 2, "button");
  int k = strcmp(kind, "axis") == 0 ? SX_ACT_AXIS : (strcmp(kind, "button") == 0 ? SX_ACT_BUTTON : -1);
  int idx = k < 0 ? -1 : sx_input_define_action(&e->input, name, (sx_action_kind)k);
  if (idx < 0) return luaL_error(L, "cannot define action '%s' (%s)", name, kind);
  lua_pushinteger(L, idx);
  return 1;
}

static int check_action(lua_State *L, sx_engine *e, int arg) {
  const char *name = luaL_checkstring(L, arg);
  int a = sx_input_find_action(&e->input, name);
  if (a < 0) luaL_error(L, "unknown action '%s'", name);
  return a;
}

static int l_input_bind(lua_State *L) {
  sx_engine *e = get_engine(L);
  int p = (int)luaL_checkinteger(L, 1), a = check_action(L, e, 2);
  lua_pushboolean(L, sx_input_bind(&e->input, p, a, luaL_checkstring(L, 3)));
  return 1;
}

static int l_input_rebind(lua_State *L) {
  sx_engine *e = get_engine(L);
  int p = (int)luaL_checkinteger(L, 1), a = check_action(L, e, 2);
  sx_binding b;
  if (!sx_binding_parse(luaL_checkstring(L, 3), &b) || p < 1 || p > SX_MAX_PLAYERS) {
    lua_pushboolean(L, 0);
    return 1;
  }
  sx_input_clear_bindings(&e->input, p, a);
  sx_input_bind(&e->input, p, a, luaL_checkstring(L, 3));
  lua_pushboolean(L, sx_engine_save_bindings(e, p));
  return 1;
}

static int l_input_bindings(lua_State *L) {
  sx_engine *e = get_engine(L);
  int p = (int)luaL_checkinteger(L, 1), a, k;
  if (p < 1 || p > SX_MAX_PLAYERS) return 0;
  lua_newtable(L);
  for (a = 0; a < e->input.nactions; a++) {
    lua_createtable(L, e->input.players[p - 1].nbindings[a], 0);
    for (k = 0; k < e->input.players[p - 1].nbindings[a]; k++) {
      char buf[64];
      sx_binding_format(&e->input.players[p - 1].bindings[a][k], buf, sizeof buf);
      lua_pushstring(L, buf);
      lua_rawseti(L, -2, k + 1);
    }
    lua_setfield(L, -2, e->input.actions[a].name);
  }
  return 1;
}

static int l_input_mode(lua_State *L) {
  sx_engine *e = get_engine(L);
  int p = (int)luaL_optinteger(L, 1, 1);
  if (e->touch.active && e->input.players[p > 0 && p <= SX_MAX_PLAYERS ? p - 1 : 0].last_device == SX_DEV_TOUCH)
    lua_pushstring(L, "touch");
  else lua_pushstring(L, sx_input_device_mode(&e->input, p));
  return 1;
}

static int l_input_touch_layout(lua_State *L) {
  sx_engine *e = get_engine(L);
  int i;
  lua_createtable(L, e->touch.nwidgets, 1);
  for (i = 0; i < e->touch.nwidgets; i++) {
    const sx_touch_widget *w = &e->touch.widgets[i];
    lua_createtable(L, 0, 7);
    lua_pushstring(L, w->name);
    lua_setfield(L, -2, "name");
    lua_pushnumber(L, w->x);
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, w->y);
    lua_setfield(L, -2, "y");
    lua_pushnumber(L, w->w);
    lua_setfield(L, -2, "w");
    lua_pushnumber(L, w->h);
    lua_setfield(L, -2, "h");
    lua_pushinteger(L, w->kind);
    lua_setfield(L, -2, "kind");
    lua_pushnumber(L, e->touch.values[w->ctl]);
    lua_setfield(L, -2, "value");
    lua_pushboolean(L, sx_touch_held(&e->touch, i));
    lua_setfield(L, -2, "held");
    lua_rawseti(L, -2, i + 1);
  }
  lua_pushboolean(L, e->touch.active);
  lua_setfield(L, -2, "active");
  {
    float s[4];
    if (sx_touch_stick(&e->touch, s)) {
      int k;
      lua_createtable(L, 4, 0);
      for (k = 0; k < 4; k++) {
        lua_pushnumber(L, s[k]);
        lua_rawseti(L, -2, k + 1);
      }
      lua_setfield(L, -2, "stick");
    }
  }
  return 1;
}

static int l_input_join_offers(lua_State *L) {
  sx_engine *e = get_engine(L);
  int d, n = 0;
  lua_newtable(L);
  for (d = 0; d < SX_NUM_DEVICES; d++)
    if (e->input.join_offer[d]) {
      lua_pushinteger(L, d);
      lua_rawseti(L, -2, ++n);
    }
  return 1;
}

/* Command frame methods: cmd:held(name) cmd:pressed(name) cmd:axis(name) */
static int cmd_slot(lua_State *L, int want_kind) {
  sx_engine *e = get_engine(L);
  int a = check_action(L, e, 2);
  if ((int)e->input.actions[a].kind != want_kind)
    return luaL_error(L, "action '%s' is not a%s", e->input.actions[a].name,
                      want_kind == SX_ACT_AXIS ? "n axis" : " button");
  return e->input.actions[a].slot;
}

static int cmd_bits(lua_State *L, const char *field, int slot) {
  lua_Integer bits;
  lua_getfield(L, 1, field);
  bits = lua_tointeger(L, -1);
  lua_pushboolean(L, (bits >> slot) & 1);
  return 1;
}

static int l_cmd_held(lua_State *L) { return cmd_bits(L, "buttons", cmd_slot(L, SX_ACT_BUTTON)); }
static int l_cmd_pressed(lua_State *L) { return cmd_bits(L, "edges", cmd_slot(L, SX_ACT_BUTTON)); }
static int l_cmd_axis(lua_State *L) {
  int slot = cmd_slot(L, SX_ACT_AXIS);
  lua_getfield(L, 1, "axes");
  lua_rawgeti(L, -1, slot + 1);
  lua_pushnumber(L, (lua_Number)lua_tointeger(L, -1) / (lua_Number)SX_AXIS_MAX);
  return 1;
}

static void push_cmd(lua_State *L, const sx_cmd *c) {
  int i;
  lua_createtable(L, 0, 6);
  lua_pushinteger(L, c->player);
  lua_setfield(L, -2, "player");
  lua_pushinteger(L, (lua_Integer)c->tick);
  lua_setfield(L, -2, "tick");
  lua_pushinteger(L, (lua_Integer)c->buttons);
  lua_setfield(L, -2, "buttons");
  lua_pushinteger(L, (lua_Integer)c->edges);
  lua_setfield(L, -2, "edges");
  lua_createtable(L, SX_NUM_AXES, 0);
  for (i = 0; i < SX_NUM_AXES; i++) {
    lua_pushinteger(L, c->axes[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setfield(L, -2, "axes");
  lua_createtable(L, 3, 0);
  for (i = 0; i < 3; i++) {
    lua_pushinteger(L, c->aim[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setfield(L, -2, "aim");
  luaL_setmetatable(L, CMD_MT);
}

void sx_script_push_cmds(lua_State *L, const sx_cmd *cmds, int n);
void sx_script_push_cmds(lua_State *L, const sx_cmd *cmds, int n) {
  int i;
  lua_createtable(L, n, 0);
  for (i = 0; i < n; i++) {
    push_cmd(L, &cmds[i]);
    lua_rawseti(L, -2, i + 1);
  }
}

/* saucer.input.command{player=, buttons={...names}, axes={name=v}} -> cmd (for tests/bots) */
static int l_input_command(lua_State *L) {
  sx_engine *e = get_engine(L);
  sx_cmd c;
  memset(&c, 0, sizeof c);
  luaL_checktype(L, 1, LUA_TTABLE);
  c.player = (int)field_num(L, 1, "player", 1);
  c.tick = e->tick;
  lua_getfield(L, 1, "buttons");
  if (lua_istable(L, -1)) {
    lua_Integer i, n = (lua_Integer)lua_rawlen(L, -1);
    for (i = 1; i <= n; i++) {
      int a;
      lua_rawgeti(L, -1, i);
      a = sx_input_find_action(&e->input, luaL_checkstring(L, -1));
      if (a < 0 || e->input.actions[a].kind != SX_ACT_BUTTON) return luaL_error(L, "bad button action");
      c.buttons |= 1u << e->input.actions[a].slot;
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  lua_getfield(L, 1, "pressed");
  if (lua_istable(L, -1)) {
    lua_Integer i, n = (lua_Integer)lua_rawlen(L, -1);
    for (i = 1; i <= n; i++) {
      int a;
      lua_rawgeti(L, -1, i);
      a = sx_input_find_action(&e->input, luaL_checkstring(L, -1));
      if (a < 0 || e->input.actions[a].kind != SX_ACT_BUTTON) return luaL_error(L, "bad button action");
      c.buttons |= 1u << e->input.actions[a].slot;
      c.edges |= 1u << e->input.actions[a].slot;
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  lua_getfield(L, 1, "axes");
  if (lua_istable(L, -1)) {
    lua_pushnil(L);
    while (lua_next(L, -2)) {
      int a = sx_input_find_action(&e->input, luaL_checkstring(L, -2));
      if (a < 0 || e->input.actions[a].kind != SX_ACT_AXIS) return luaL_error(L, "bad axis action");
      c.axes[e->input.actions[a].slot] = sx_quantize_axis((float)luaL_checknumber(L, -1));
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  push_cmd(L, &c);
  return 1;
}

/* ---------- saucer.physics ---------- */
static unsigned opt_mask(lua_State *L, int idx) { return (unsigned)luaL_optinteger(L, idx, 0xFFFFFFFF); }

static int l_ph_clear(lua_State *L) {
  sx_phys_clear(&get_engine(L)->phys);
  return 0;
}

static int l_ph_add_box(lua_State *L) {
  double mn[3], mx[3];
  get_vec3(L, 1, mn);
  get_vec3(L, 2, mx);
  lua_pushinteger(L, sx_phys_add_box(&get_engine(L)->phys, mn, mx, opt_mask(L, 3)) + 1);
  return 1;
}

static int l_ph_remove(lua_State *L) {
  sx_phys_remove(&get_engine(L)->phys, (int)luaL_checkinteger(L, 1) - 1);
  return 0;
}

static int l_ph_count(lua_State *L) {
  lua_pushinteger(L, get_engine(L)->phys.count);
  return 1;
}

/* clearance(pos, radius, half_height [, margin, mask]) -> true when free */
static int l_ph_clearance(lua_State *L) {
  double p[3];
  get_vec3(L, 1, p);
  lua_pushboolean(L, !sx_phys_overlaps(&get_engine(L)->phys, p, luaL_checknumber(L, 2), luaL_checknumber(L, 3),
                                       luaL_optnumber(L, 4, 0.0), opt_mask(L, 5)));
  return 1;
}

/* move(pos, radius, half_height, delta [, mask]) -> newpos, blocked_axes */
static int l_ph_move(lua_State *L) {
  double p[3], d[3];
  int blocked;
  get_vec3(L, 1, p);
  get_vec3(L, 4, d);
  blocked = sx_phys_move(&get_engine(L)->phys, p, luaL_checknumber(L, 2), luaL_checknumber(L, 3), d, opt_mask(L, 5));
  push_vec3(L, p);
  lua_pushinteger(L, blocked);
  return 2;
}

static int l_ph_raycast(lua_State *L) {
  double o[3], d[3];
  sx_hit h;
  get_vec3(L, 1, o);
  get_vec3(L, 2, d);
  h = sx_phys_raycast(&get_engine(L)->phys, o, d, luaL_checknumber(L, 3), opt_mask(L, 4));
  if (!h.hit) return 0;
  lua_createtable(L, 0, 3);
  lua_pushnumber(L, h.t);
  lua_setfield(L, -2, "t");
  lua_pushinteger(L, h.box + 1);
  lua_setfield(L, -2, "box");
  push_vec3(L, h.normal);
  lua_setfield(L, -2, "normal");
  return 1;
}

static int l_ph_cone(lua_State *L) {
  double o[3], d[3], t[3];
  get_vec3(L, 1, o);
  get_vec3(L, 2, d);
  get_vec3(L, 5, t);
  lua_pushboolean(L, sx_phys_cone_visible(&get_engine(L)->phys, o, d, luaL_checknumber(L, 3), luaL_checknumber(L, 4),
                                          t, opt_mask(L, 6)));
  return 1;
}

/* ---------- saucer.procgen ---------- */
static int l_grid_new(lua_State *L) {
  sx_grid *g = (sx_grid *)lua_newuserdatauv(L, sizeof(sx_grid), 0);
  memset(g, 0, sizeof *g);
  luaL_setmetatable(L, GRID_MT);
  if (!sx_grid_init(g, (int)luaL_checkinteger(L, 1), (int)luaL_checkinteger(L, 2), (int)luaL_checkinteger(L, 3)))
    return luaL_error(L, "invalid grid size");
  return 1;
}

static int l_grid_gc(lua_State *L) {
  sx_grid_free((sx_grid *)luaL_checkudata(L, 1, GRID_MT));
  return 0;
}

#define GI(n) ((int)luaL_checkinteger(L, n))
static int l_grid_place(lua_State *L) {
  sx_grid *g = (sx_grid *)luaL_checkudata(L, 1, GRID_MT);
  lua_pushboolean(L, sx_grid_place(g, GI(2), GI(3), GI(4), GI(5), GI(6), GI(7), GI(8)));
  return 1;
}
static int l_grid_free(lua_State *L) {
  sx_grid *g = (sx_grid *)luaL_checkudata(L, 1, GRID_MT);
  lua_pushboolean(L, sx_grid_free_box(g, GI(2), GI(3), GI(4), GI(5), GI(6), GI(7)));
  return 1;
}
static int l_grid_get(lua_State *L) {
  sx_grid *g = (sx_grid *)luaL_checkudata(L, 1, GRID_MT);
  lua_pushinteger(L, sx_grid_get(g, GI(2), GI(3), GI(4)));
  return 1;
}

/* reachable(nodes={room_class...}, edges={{a,b,cls}...}, start, start_class [, min_class]) -> {cls or false} */
static int l_reachable(lua_State *L) {
  int n, m, i, *rc, *out;
  sx_edge *ed;
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TTABLE);
  n = (int)lua_rawlen(L, 1);
  m = (int)lua_rawlen(L, 2);
  if (n == 0) {
    lua_newtable(L);
    return 1;
  }
  rc = (int *)malloc(sizeof(int) * (size_t)n);
  out = (int *)malloc(sizeof(int) * (size_t)n);
  ed = (sx_edge *)malloc(sizeof(sx_edge) * (size_t)(m ? m : 1));
  for (i = 0; i < n; i++) {
    lua_rawgeti(L, 1, i + 1);
    rc[i] = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
  }
  for (i = 0; i < m; i++) {
    lua_rawgeti(L, 2, i + 1);
    lua_rawgeti(L, -1, 1);
    lua_rawgeti(L, -2, 2);
    lua_rawgeti(L, -3, 3);
    ed[i].a = (int)lua_tointeger(L, -3) - 1;
    ed[i].b = (int)lua_tointeger(L, -2) - 1;
    ed[i].cls = (int)lua_tointeger(L, -1);
    lua_pop(L, 4);
  }
  sx_reachable(n, rc, ed, m, (int)luaL_checkinteger(L, 3) - 1, (int)luaL_checkinteger(L, 4),
               (int)luaL_optinteger(L, 5, 0), out);
  lua_createtable(L, n, 0);
  for (i = 0; i < n; i++) {
    if (out[i] >= 0) lua_pushinteger(L, out[i]);
    else lua_pushboolean(L, 0);
    lua_rawseti(L, -2, i + 1);
  }
  free(rc);
  free(out);
  free(ed);
  return 1;
}

/* ---------- saucer.mesh ---------- */
static void read_style(lua_State *L, int idx, sx_part_style *s) {
  sx_style_default(s);
  field_vec(L, idx, "color", s->color, 3);
  s->emissive = field_num(L, idx, "emissive", 0.0f);
  s->uv_scale = field_num(L, idx, "uv", 0.25f);
}

typedef struct part_xf {
  float pos[3], scale[3];
  float yaw, pitch, roll;
} part_xf;

static void apply_xf(sx_mesh *m, int from, const part_xf *x) {
  int i, k;
  float cy = (float)sx_cos(x->yaw), sy = (float)sx_sin(x->yaw);
  float cp = (float)sx_cos(x->pitch), sp = (float)sx_sin(x->pitch);
  float cr = (float)sx_cos(x->roll), sr = (float)sx_sin(x->roll);
  for (i = from; i < m->nv; i++) {
    float *v = m->v + SX_VTX_FLOATS * i;
    for (k = 0; k < 2; k++) { /* position, then normal */
      float *p = v + 3 * k;
      float a = p[0] * (k ? 1 : x->scale[0]), b = p[1] * (k ? 1 : x->scale[1]), c = p[2] * (k ? 1 : x->scale[2]);
      float t;
      /* roll (z), pitch (x), yaw (y) */
      t = a * cr - b * sr; b = a * sr + b * cr; a = t;
      t = b * cp - c * sp; c = b * sp + c * cp; b = t;
      t = a * cy + c * sy; c = -a * sy + c * cy; a = t;
      if (!k) {
        a += x->pos[0];
        b += x->pos[1];
        c += x->pos[2];
      }
      p[0] = a;
      p[1] = b;
      p[2] = c;
    }
  }
}

static void recompute_bounds(sx_mesh *m) {
  int i, k;
  for (k = 0; k < 3; k++) {
    m->bmin[k] = 1e30f;
    m->bmax[k] = -1e30f;
  }
  for (i = 0; i < m->nv; i++)
    for (k = 0; k < 3; k++) {
      /* quantize positions to 1/1024 m so hashes are platform independent */
      float *p = m->v + SX_VTX_FLOATS * i + k;
      *p = (float)(sx_floor((double)*p * 1024.0 + 0.5) / 1024.0);
      if (*p < m->bmin[k]) m->bmin[k] = *p;
      if (*p > m->bmax[k]) m->bmax[k] = *p;
    }
}

static int build_part(lua_State *L, int idx, sx_mesh *m) {
  sx_part_style s;
  part_xf x;
  int from = m->nv, t;
  float mn[3] = {-0.5f, -0.5f, -0.5f}, mx[3] = {0.5f, 0.5f, 0.5f}, c[3] = {0, 0, 0};
  read_style(L, idx, &s);
  memset(&x, 0, sizeof x);
  x.scale[0] = x.scale[1] = x.scale[2] = 1;
  field_vec(L, idx, "pos", x.pos, 3);
  field_vec(L, idx, "scale", x.scale, 3);
  x.yaw = field_num(L, idx, "yaw", 0);
  x.pitch = field_num(L, idx, "pitch", 0);
  x.roll = field_num(L, idx, "roll", 0);
  field_vec(L, idx, "min", mn, 3);
  field_vec(L, idx, "max", mx, 3);
  field_vec(L, idx, "c", c, 3);
  lua_getfield(L, idx, "kind");
  if (lua_type(L, -1) != LUA_TSTRING) {
    lua_pop(L, 1);
    return 0;
  }
  {
    const char *k = lua_tostring(L, -1);
    int seg = (int)field_num(L, idx, "seg", 12);
    float r = field_num(L, idx, "r", 1), h = field_num(L, idx, "h", 1);
    int open;
    void (*fr)(sx_mesh *, const float *, float, float, float, int, const sx_part_style *);
    lua_getfield(L, idx, "open"); /* open = true: no end caps (shells you can stand inside) */
    open = lua_toboolean(L, -1);
    lua_pop(L, 1);
    fr = open ? sx_mesh_tube : sx_mesh_frustum;
    if (strcmp(k, "box") == 0) sx_mesh_box(m, mn, mx, &s);
    else if (strcmp(k, "wedge") == 0) sx_mesh_wedge(m, mn, mx, field_num(L, idx, "low", 0), &s);
    else if (strcmp(k, "cylinder") == 0) fr(m, c, r, r, h, seg, &s);
    else if (strcmp(k, "cone") == 0) fr(m, c, r, field_num(L, idx, "r1", 0), h, seg, &s);
    else if (strcmp(k, "ring") == 0) sx_mesh_ring(m, c, field_num(L, idx, "rin", 0.5f), r, h, seg, &s);
    else if (strcmp(k, "hemisphere") == 0) sx_mesh_dome(m, c, r, h, seg, (int)field_num(L, idx, "rings", 4), &s);
    else if (strcmp(k, "sphere") == 0) {
      int start;
      sx_mesh_dome(m, c, r, h, seg, (int)field_num(L, idx, "rings", 4), &s);
      start = m->nv;
      sx_mesh_dome(m, c, r, h, seg, (int)field_num(L, idx, "rings", 4), &s);
      /* mirror the second half below the center */
      for (t = start; t < m->nv; t++) {
        float *v = m->v + SX_VTX_FLOATS * t;
        v[1] = 2 * c[1] - v[1];
        v[4] = -v[4];
      }
      {
        int i;
        for (i = 0; i < m->ni; i += 3)
          if ((int)m->idx[i] >= start) {
            uint32_t tmp = m->idx[i + 1];
            m->idx[i + 1] = m->idx[i + 2];
            m->idx[i + 2] = tmp;
          }
      }
    } else if (strcmp(k, "lathe") == 0 || strcmp(k, "extrude") == 0) {
      float buf[256];
      int n = 0;
      lua_getfield(L, idx, "points");
      if (lua_istable(L, -1)) {
        int i, len = (int)lua_rawlen(L, -1);
        for (i = 1; i <= len && n < 256; i++) {
          lua_rawgeti(L, -1, i);
          buf[n++] = (float)lua_tonumber(L, -1);
          lua_pop(L, 1);
        }
      }
      lua_pop(L, 1);
      if (k[0] == 'e') sx_mesh_extrude(m, buf, n / 2, field_num(L, idx, "y0", 0), field_num(L, idx, "y1", 1), &s);
      else {
        /* lathe: profile pairs (radius, y) revolved as stacked frustums */
        int i;
        for (i = 0; i + 3 < n; i += 2) {
          float cc[3];
          cc[0] = c[0];
          cc[1] = c[1] + buf[i + 1];
          cc[2] = c[2];
          fr(m, cc, buf[i], buf[i + 2], buf[i + 3] - buf[i + 1], seg, &s);
        }
      }
    } else if (strcmp(k, "stars") == 0) {
      sx_mesh_stars(m, (int)field_num(L, idx, "count", 500), r, field_num(L, idx, "size", 1),
                    (uint64_t)field_num(L, idx, "seed", 1));
    } else {
      lua_pop(L, 1);
      return 0;
    }
  }
  lua_pop(L, 1);
  apply_xf(m, from, &x);
  return 1;
}

/* wall-clock milliseconds, only for the mesh build-time budget (never read by the sim) */
static double wall_ms(void) {
  struct timespec ts;
  if (!timespec_get(&ts, TIME_UTC)) return 0.0;
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1.0e6;
}

/* build{ parts = { {kind="box", min=..., max=..., color=...}, ... } } -> id, hash, build milliseconds */
static int l_mesh_build(lua_State *L) {
  sx_engine *e = get_engine(L);
  sx_mesh m;
  int i, n, id;
  uint64_t h;
  double t0 = wall_ms();
  luaL_checktype(L, 1, LUA_TTABLE);
  sx_mesh_init(&m);
  lua_getfield(L, 1, "parts");
  luaL_checktype(L, -1, LUA_TTABLE);
  n = (int)lua_rawlen(L, -1);
  for (i = 1; i <= n; i++) {
    lua_rawgeti(L, -1, i);
    if (!lua_istable(L, -1) || !build_part(L, lua_gettop(L), &m)) {
      sx_mesh_free(&m);
      return luaL_error(L, "mesh part %d has an unknown kind", i);
    }
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
  recompute_bounds(&m);
  h = sx_mesh_hash(&m);
  id = sx_render_add_mesh(&e->render, &m);
  if (!id) return luaL_error(L, "too many meshes");
  lua_pushinteger(L, id);
  lua_pushinteger(L, (lua_Integer)h);
  lua_pushnumber(L, wall_ms() - t0);
  return 3;
}

static int l_mesh_info(lua_State *L) {
  sx_engine *e = get_engine(L);
  int id = (int)luaL_checkinteger(L, 1), k;
  sx_rmesh *rm;
  if (id <= 0 || id >= SX_MAX_MESHES || !e->render.meshes[id].used) return 0;
  rm = &e->render.meshes[id];
  lua_createtable(L, 0, 5);
  lua_pushinteger(L, rm->mesh.nv);
  lua_setfield(L, -2, "vertices");
  lua_pushinteger(L, rm->mesh.ni / 3);
  lua_setfield(L, -2, "triangles");
  lua_pushinteger(L, (lua_Integer)sx_mesh_hash(&rm->mesh));
  lua_setfield(L, -2, "hash");
  for (k = 0; k < 2; k++) {
    double v[3];
    int j;
    for (j = 0; j < 3; j++) v[j] = k ? rm->mesh.bmax[j] : rm->mesh.bmin[j];
    push_vec3(L, v);
    lua_setfield(L, -2, k ? "max" : "min");
  }
  return 1;
}

static int l_mesh_free(lua_State *L) {
  sx_render_free_mesh(&get_engine(L)->render, (int)luaL_checkinteger(L, 1));
  return 0;
}

/* ---------- saucer.render ---------- */
static int l_r_texture(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *p = luaL_checkstring(L, 1);
  int id = sx_render_find_texture(&e->render, p);
  if (!id) {
    size_t n = 0;
    char *d = sx_vfs_read(&e->vfs, p, &n);
    id = sx_render_texture_from_png(&e->render, p, (const unsigned char *)d, (int)n);
    free(d);
  }
  lua_pushinteger(L, id);
  return 1;
}

static int l_r_palette(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *p = luaL_checkstring(L, 1);
  int id = sx_render_find_palette(&e->render, p);
  if (id < 0) {
    size_t n = 0;
    char *d = sx_vfs_read(&e->vfs, p, &n);
    id = sx_render_palettes_from_png(&e->render, p, (const unsigned char *)d, (int)n);
    free(d);
    if (id < 0) id = 0;
  }
  lua_pushinteger(L, id);
  return 1;
}

static int l_r_settings(lua_State *L) {
  sx_engine *e = get_engine(L);
  if (lua_istable(L, 1)) {
    int w = (int)field_num(L, 1, "width", (float)e->render.settings.width);
    int h = (int)field_num(L, 1, "height", (float)e->render.settings.height);
    if (w >= 64 && w <= 3840) e->render.settings.width = w;
    if (h >= 36 && h <= 2160) e->render.settings.height = h;
    e->render.settings.vertex_snap = (int)field_num(L, 1, "snap", (float)e->render.settings.vertex_snap);
    e->render.settings.dither = (int)field_num(L, 1, "dither", (float)e->render.settings.dither);
  }
  lua_createtable(L, 0, 4);
  lua_pushinteger(L, e->render.settings.width);
  lua_setfield(L, -2, "width");
  lua_pushinteger(L, e->render.settings.height);
  lua_setfield(L, -2, "height");
  lua_pushboolean(L, e->render.settings.vertex_snap && !e->xr.session);
  lua_setfield(L, -2, "snap");
  lua_pushboolean(L, e->render.settings.dither);
  lua_setfield(L, -2, "dither");
  return 1;
}

static int l_r_stats(lua_State *L) {
  sx_engine *e = get_engine(L);
  int i, m = 0, b = 0, u = 0;
  for (i = 0; i < e->render.nviews; i++) {
    m += e->render.views[i].nmeshes;
    b += e->render.views[i].nbills;
    u += e->render.views[i].nui;
  }
  lua_createtable(L, 0, 5);
  lua_pushinteger(L, e->render.nviews);
  lua_setfield(L, -2, "viewports");
  lua_pushinteger(L, m);
  lua_setfield(L, -2, "meshes");
  lua_pushinteger(L, b);
  lua_setfield(L, -2, "billboards");
  lua_pushinteger(L, u);
  lua_setfield(L, -2, "ui");
  lua_pushinteger(L, e->render.frame);
  lua_setfield(L, -2, "frame");
  return 1;
}

static sx_viewport *check_view(lua_State *L) {
  int *vi = (int *)luaL_checkudata(L, 1, VIEW_MT);
  sx_engine *e = get_engine(L);
  if (*vi < 0 || *vi >= e->render.nviews) luaL_error(L, "stale viewport");
  return &e->render.views[*vi];
}

static int l_v_camera(lua_State *L) {
  sx_viewport *v = check_view(L);
  luaL_checktype(L, 2, LUA_TTABLE);
  /* In XR the head pose comes from the headset; pos/yaw place the cockpit. */
  field_vec(L, 2, "pos", v->cam.pos, 3);
  v->cam.yaw = field_num(L, 2, "yaw", v->cam.yaw);
  v->cam.pitch = field_num(L, 2, "pitch", v->cam.pitch);
  v->cam.roll = field_num(L, 2, "roll", 0.0f);
  /* fov is given in degrees (vertical) */
  v->cam.fov = field_num(L, 2, "fov", v->cam.fov * (float)(180.0 / SX_PI)) * (float)(SX_PI / 180.0);
  v->cam.znear = field_num(L, 2, "near", v->cam.znear);
  v->cam.zfar = field_num(L, 2, "far", v->cam.zfar);
  return 0;
}

static int l_v_fog(lua_State *L) {
  sx_viewport *v = check_view(L);
  luaL_checktype(L, 2, LUA_TTABLE);
  field_vec(L, 2, "color", v->fog_color, 3);
  v->fog_density = field_num(L, 2, "density", v->fog_density);
  field_vec(L, 2, "clear", v->clear_color, 3);
  field_vec(L, 2, "light", v->light_dir, 3);
  v->ambient = field_num(L, 2, "ambient", v->ambient);
  return 0;
}

static void read_tint(lua_State *L, int idx, float t[4]) {
  t[0] = t[1] = t[2] = t[3] = 1.0f;
  if (idx && lua_istable(L, idx)) field_vec(L, idx, "tint", t, 4);
}

/* view:mesh(id, {pos=, yaw=, pitch=, roll=, scale= num|{x,y,z}, tex=, palette=, tint=, sky=, ghost=, unlit=}) */
static int l_v_mesh(lua_State *L) {
  sx_viewport *v = check_view(L);
  sx_draw_mesh d;
  float pos[3] = {0, 0, 0}, sc[3] = {1, 1, 1};
  int o = lua_istable(L, 3) ? 3 : 0;
  memset(&d, 0, sizeof d);
  d.mesh = (int)luaL_checkinteger(L, 2);
  read_tint(L, o, d.tint);
  if (o) {
    field_vec(L, o, "pos", pos, 3);
    lua_getfield(L, o, "scale");
    if (lua_isnumber(L, -1)) sc[0] = sc[1] = sc[2] = (float)lua_tonumber(L, -1);
    lua_pop(L, 1);
    field_vec(L, o, "scale", sc, 3);
    d.tex = (int)field_num(L, o, "tex", 0);
    d.palette = (int)field_num(L, o, "palette", 0);
    lua_getfield(L, o, "sky");
    if (lua_toboolean(L, -1)) d.flags |= SX_DRAW_SKY | SX_DRAW_UNLIT | SX_DRAW_NOFOG;
    lua_getfield(L, o, "ghost");
    if (lua_toboolean(L, -1)) d.flags |= SX_DRAW_GHOST;
    lua_getfield(L, o, "unlit");
    if (lua_toboolean(L, -1)) d.flags |= SX_DRAW_UNLIT;
    lua_pop(L, 3);
  }
  if (o && (field_num(L, o, "pitch", 0) != 0.0f || field_num(L, o, "roll", 0) != 0.0f))
    sx_mat4_model_ypr(d.model, pos, field_num(L, o, "yaw", 0), field_num(L, o, "pitch", 0), field_num(L, o, "roll", 0), sc);
  else
    sx_mat4_model(d.model, pos, o ? field_num(L, o, "yaw", 0) : 0.0f, sc);
  sx_view_mesh(v, &d);
  return 0;
}

/* view:billboard(tex, pos, size, {palette=, tint=, yaxis=true}) */
static int l_v_billboard(lua_State *L) {
  sx_viewport *v = check_view(L);
  sx_draw_billboard b;
  double p[3];
  int o = lua_istable(L, 5) ? 5 : 0;
  memset(&b, 0, sizeof b);
  b.tex = (int)luaL_checkinteger(L, 2);
  get_vec3(L, 3, p);
  b.pos[0] = (float)p[0];
  b.pos[1] = (float)p[1];
  b.pos[2] = (float)p[2];
  b.size[0] = b.size[1] = (float)luaL_checknumber(L, 4);
  b.yaxis = 1;
  read_tint(L, o, b.tint);
  if (o) {
    b.palette = (int)field_num(L, o, "palette", 0);
    lua_getfield(L, o, "yaxis");
    if (!lua_isnil(L, -1)) b.yaxis = lua_toboolean(L, -1);
    lua_pop(L, 1);
    b.size[1] = field_num(L, o, "height", b.size[0]);
  }
  sx_view_billboard(v, &b);
  return 0;
}

static void read_color(lua_State *L, int idx, float c[4]) {
  c[0] = c[1] = c[2] = c[3] = 1.0f;
  if (lua_istable(L, idx)) {
    int i;
    for (i = 0; i < 4; i++) {
      lua_rawgeti(L, idx, i + 1);
      if (lua_isnumber(L, -1)) c[i] = (float)lua_tonumber(L, -1);
      lua_pop(L, 1);
    }
  }
}

static int l_v_rect(lua_State *L) {
  sx_viewport *v = check_view(L);
  sx_draw_ui u;
  memset(&u, 0, sizeof u);
  u.kind = 0;
  u.x = (float)luaL_checknumber(L, 2);
  u.y = (float)luaL_checknumber(L, 3);
  u.w = (float)luaL_checknumber(L, 4);
  u.h = (float)luaL_checknumber(L, 5);
  read_color(L, 6, u.color);
  sx_view_ui(v, &u);
  return 0;
}

static int l_v_text(lua_State *L) {
  sx_viewport *v = check_view(L);
  sx_draw_ui u;
  size_t n;
  const char *s;
  memset(&u, 0, sizeof u);
  u.kind = 1;
  u.x = (float)luaL_checknumber(L, 2);
  u.y = (float)luaL_checknumber(L, 3);
  s = luaL_checklstring(L, 4, &n);
  if (n >= sizeof u.text) n = sizeof u.text - 1;
  memcpy(u.text, s, n);
  read_color(L, 5, u.color);
  u.scale = (int)luaL_optinteger(L, 6, 1);
  u.w = (float)(n * 8 * (size_t)u.scale);
  u.h = (float)(8 * u.scale);
  sx_view_ui(v, &u);
  lua_pushnumber(L, u.w);
  return 1;
}

static int l_v_image(lua_State *L) {
  sx_viewport *v = check_view(L);
  sx_draw_ui u;
  memset(&u, 0, sizeof u);
  u.kind = 2;
  u.tex = (int)luaL_checkinteger(L, 2);
  u.x = (float)luaL_checknumber(L, 3);
  u.y = (float)luaL_checknumber(L, 4);
  u.w = (float)luaL_checknumber(L, 5);
  u.h = (float)luaL_checknumber(L, 6);
  u.palette = (int)luaL_optinteger(L, 7, 0);
  u.color[0] = u.color[1] = u.color[2] = u.color[3] = 1;
  sx_view_ui(v, &u);
  return 0;
}

/* add-presentation-packaging: comfort vignette, a radial fade over the whole view */
static int l_v_vignette(lua_State *L) {
  sx_viewport *v = check_view(L);
  sx_draw_ui u;
  float k = (float)luaL_checknumber(L, 2);
  if (!(k > 0.0f)) return 0;
  memset(&u, 0, sizeof u);
  u.kind = 3;
  u.w = (float)v->w;
  u.h = (float)v->h;
  u.color[3] = k > 1.0f ? 1.0f : k;
  sx_view_ui(v, &u);
  return 0;
}

static int l_v_index(lua_State *L) {
  int *vi = (int *)luaL_checkudata(L, 1, VIEW_MT);
  sx_engine *e = get_engine(L);
  const char *k = luaL_checkstring(L, 2);
  sx_viewport *v = &e->render.views[*vi];
  if (strcmp(k, "width") == 0) lua_pushinteger(L, v->w);
  else if (strcmp(k, "height") == 0) lua_pushinteger(L, v->h);
  else if (strcmp(k, "player") == 0) lua_pushinteger(L, v->player);
  else if (strcmp(k, "index") == 0) lua_pushinteger(L, *vi + 1);
  else if (strcmp(k, "xr") == 0) lua_pushboolean(L, v->cam.has_matrices);
  else {
    luaL_getmetatable(L, VIEW_MT);
    lua_getfield(L, -1, "methods");
    lua_getfield(L, -1, k);
  }
  return 1;
}

static void push_view(lua_State *L, int index) {
  int *vi = (int *)lua_newuserdatauv(L, sizeof(int), 0);
  *vi = index;
  luaL_setmetatable(L, VIEW_MT);
}

/* ---------- saucer.xr ---------- */
static int l_xr_available(lua_State *L) {
  lua_pushboolean(L, get_engine(L)->xr.available);
  return 1;
}
static int l_xr_session(lua_State *L) {
  sx_engine *e = get_engine(L);
  if (!e->xr.session) return 0;
  lua_pushstring(L, e->xr.session == 2 ? "standing" : "seated");
  return 1;
}
static int l_xr_comfort(lua_State *L) {
  sx_engine *e = get_engine(L);
  lua_createtable(L, 0, 5);
  lua_pushnumber(L, sx_xr_snap_deg(&e->xr));
  lua_setfield(L, -2, "snap_turn");
  lua_pushnumber(L, e->xr.vignette);
  lua_setfield(L, -2, "vignette");
  lua_pushboolean(L, 1);
  lua_setfield(L, -2, "xr_safe_retro");
  lua_pushboolean(L, e->xr.snap);
  lua_setfield(L, -2, "snap");
  lua_pushstring(L, e->xr.pref_mode == 1 ? "seated" : "standing");
  lua_setfield(L, -2, "mode");
  return 1;
}
/* may this script change the client's own settings? Not in a replay, and on a
 * network only for the local player (every peer runs every player's menus) */
static int comfort_allowed(sx_engine *e, lua_Integer player) {
  return !(e->opt.play[0] || (e->net_on && player != e->net.local_slot));
}
/* add-presentation-packaging, add-webxr-cockpit: comfort is a client setting (never in the sim).
 * set_comfort({snap =, vignette =, snap_turn =, mode = "seated"|"standing"}, player) -> applied */
static int l_xr_set_comfort(lua_State *L) {
  sx_engine *e = get_engine(L);
  luaL_checktype(L, 1, LUA_TTABLE);
  if (!comfort_allowed(e, luaL_optinteger(L, 2, 1))) {
    lua_pushboolean(L, 0);
    return 1;
  }
  lua_getfield(L, 1, "snap");
  if (!lua_isnil(L, -1)) e->xr.snap = lua_toboolean(L, -1);
  lua_pop(L, 1);
  e->xr.snap_latch = 0;
  sx_xr_set_vignette(&e->xr, (float)field_num(L, 1, "vignette", e->xr.vignette));
  sx_xr_set_snap_deg(&e->xr, (float)field_num(L, 1, "snap_turn", sx_xr_snap_deg(&e->xr)));
  lua_getfield(L, 1, "mode");
  if (lua_isstring(L, -1)) {
    const char *m = lua_tostring(L, -1);
    if (strcmp(m, "seated") == 0) e->xr.pref_mode = 1;
    else if (strcmp(m, "standing") == 0) e->xr.pref_mode = 2;
  }
  lua_pop(L, 1);
  lua_pushboolean(L, 1);
  return 1;
}
/* saucer.xr.save_comfort(player): writes <user-dir>/comfort.txt */
static int l_xr_save_comfort(lua_State *L) {
  sx_engine *e = get_engine(L);
  lua_pushboolean(L, comfort_allowed(e, luaL_optinteger(L, 1, 1)) && sx_engine_save_comfort(e));
  return 1;
}
static void push_vec3f(lua_State *L, const float *v) {
  int i;
  lua_createtable(L, 3, 0);
  for (i = 0; i < 3; i++) {
    lua_pushnumber(L, v[i]);
    lua_rawseti(L, -2, i + 1);
  }
}
/* head pose in the cockpit frame (yaw 0 looks down +z) -> pos, fwd */
static int l_xr_head(lua_State *L) {
  sx_engine *e = get_engine(L);
  if (!e->xr.session) return 0;
  push_vec3f(L, e->xr.head_pos);
  push_vec3f(L, e->xr.head_fwd);
  return 2;
}
/* tracked controllers -> { {hand = "left"|"right", pos = {}, fwd = {}}, ... } */
static int l_xr_hands(lua_State *L) {
  sx_engine *e = get_engine(L);
  int i, n = 0;
  lua_newtable(L);
  if (!e->xr.session) return 1;
  for (i = 0; i < 2; i++) {
    if (!e->xr.hand_ok[i]) continue;
    lua_createtable(L, 0, 6);
    lua_pushstring(L, i == 0 ? "left" : "right");
    lua_setfield(L, -2, "hand");
    lua_pushboolean(L, e->xr.joint_ok[i]);
    lua_setfield(L, -2, "tracked");
    lua_pushboolean(L, e->xr.pinch[i]);
    lua_setfield(L, -2, "pinch");
    lua_pushboolean(L, e->xr.grab[i]);
    lua_setfield(L, -2, "grab");
    push_vec3f(L, e->xr.hands[i]);
    lua_setfield(L, -2, "pos");
    push_vec3f(L, e->xr.hands[i] + 3);
    lua_setfield(L, -2, "fwd");
    lua_rawseti(L, -2, ++n);
  }
  return 1;
}
/* saucer.xr.lever() -> pos, held: the size lever's handle (head relative, same frame as head()) */
static int l_xr_lever(lua_State *L) {
  sx_engine *e = get_engine(L);
  float p[3];
  if (!e->xr.session) return 0;
  sx_xr_lever_pos(&e->xr, p);
  push_vec3f(L, p);
  lua_pushboolean(L, e->xr.lever_hand >= 0);
  return 2;
}
/* saucer.xr.haptic(hand, strength, ms): hand "left", "right" or "both" (default) */
static int l_xr_haptic(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *h = luaL_optstring(L, 1, "both");
  int hand = strcmp(h, "left") == 0 ? 0 : (strcmp(h, "right") == 0 ? 1 : -1);
  if (e->xr.session) sx_xr_haptic(&e->xr, hand, (float)luaL_optnumber(L, 2, 0.5), (int)luaL_optinteger(L, 3, 40));
  return 0;
}

/* ---------- saucer.audio ---------- */
static sx_audio_req *audio_req(sx_engine *e) {
  sx_audio_req *a;
  if (e->naudio >= (int)(sizeof e->audio / sizeof e->audio[0])) return NULL;
  a = &e->audio[e->naudio++];
  memset(a, 0, sizeof *a);
  return a;
}

/* saucer.audio.play(path, {volume=, pan=, loop=, pitch=}) -> handle (nil when the
 * frame's queue is full) */
static int l_audio_play(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *p = luaL_checkstring(L, 1);
  sx_audio_req *a = audio_req(e);
  if (!a) return 0;
  strncpy(a->path, p, sizeof a->path - 1);
  a->volume = 1.0f;
  a->pitch = 1.0f;
  if (lua_istable(L, 2)) {
    a->volume = field_num(L, 2, "volume", 1.0f);
    a->pan = field_num(L, 2, "pan", 0.0f);
    a->pitch = field_num(L, 2, "pitch", 1.0f);
    if (a->pitch < 0.05f) a->pitch = 0.05f;
    if (a->pitch > 8.0f) a->pitch = 8.0f;
    lua_getfield(L, 2, "loop");
    a->loop = lua_toboolean(L, -1);
    lua_pop(L, 1);
  }
  a->op = SX_AUDIO_PLAY;
  a->handle = ++e->audio_next_handle;
  e->audio_played_total++;
  if (a->loop && e->audio_nloops < (int)(sizeof e->audio_loops / sizeof e->audio_loops[0]))
    e->audio_loops[e->audio_nloops++] = a->handle;
  lua_pushinteger(L, a->handle);
  return 1;
}

/* saucer.audio.set(handle, {volume=}) -> true when queued */
static int l_audio_set(lua_State *L) {
  sx_engine *e = get_engine(L);
  int h = (int)luaL_checkinteger(L, 1);
  sx_audio_req *a = audio_req(e);
  if (!a) return 0;
  a->op = SX_AUDIO_SET;
  a->handle = h;
  a->volume = lua_istable(L, 2) ? field_num(L, 2, "volume", 1.0f) : (float)luaL_optnumber(L, 2, 1.0);
  lua_pushboolean(L, 1);
  return 1;
}

/* saucer.audio.stop(handle) -> true when queued */
static int l_audio_stop(lua_State *L) {
  sx_engine *e = get_engine(L);
  int h = (int)luaL_checkinteger(L, 1), i;
  sx_audio_req *a;
  for (i = 0; i < e->audio_nloops; i++)
    if (e->audio_loops[i] == h) e->audio_loops[i--] = e->audio_loops[--e->audio_nloops];
  a = audio_req(e);
  if (!a) return 0;
  a->op = SX_AUDIO_STOP;
  a->handle = h;
  lua_pushboolean(L, 1);
  return 1;
}

/* ---------- saucer.save ---------- */
static char *save_path(sx_engine *e, lua_State *L, const char *slot) {
  char name[160];
  const char *p;
  for (p = slot; *p; p++)
    if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_' || *p == '-'))
      luaL_error(L, "invalid save slot name '%s'", slot);
  if (!*slot || strlen(slot) > 64) luaL_error(L, "invalid save slot name");
  snprintf(name, sizeof name, "saves/%s.sav", slot);
  return sx_path_join(e->opt.user_dir, name);
}

static int l_save_write(lua_State *L) {
  sx_engine *e = get_engine(L);
  char err[128], *path, *dir;
  sx_buf b = {0};
  int ok;
  path = save_path(e, L, luaL_checkstring(L, 1));
  luaL_checkany(L, 2);
  if (!sx_ser_write(L, 2, &b, err, sizeof err)) {
    free(path);
    sx_buf_free(&b);
    return luaL_error(L, "save: %s", err);
  }
  dir = sx_path_dir(path);
  sx_fs_mkdirs(dir);
  free(dir);
  ok = sx_fs_write_atomic(path, b.data, b.len);
  free(path);
  sx_buf_free(&b);
  lua_pushboolean(L, ok);
  return 1;
}

static int l_save_read(lua_State *L) {
  sx_engine *e = get_engine(L);
  char err[128], *path = save_path(e, L, luaL_checkstring(L, 1));
  size_t n;
  char *d = sx_fs_read(path, &n);
  free(path);
  if (!d) return 0;
  if (!sx_ser_read(L, (const unsigned char *)d, n, err, sizeof err)) {
    free(d);
    lua_pushnil(L);
    lua_pushstring(L, err);
    return 2;
  }
  free(d);
  return 1;
}

/* ---------- saucer.time / mods / engine ---------- */
static int l_time_tick(lua_State *L) {
  lua_pushinteger(L, (lua_Integer)get_engine(L)->tick);
  return 1;
}
static int l_time_seconds(lua_State *L) {
  lua_pushnumber(L, (lua_Number)get_engine(L)->tick / (lua_Number)SX_TICK_HZ);
  return 1;
}

static int l_mods_list(lua_State *L) {
  sx_engine *e = get_engine(L);
  int i;
  lua_createtable(L, e->mods.count, 0);
  for (i = 0; i < e->mods.count; i++) {
    const sx_mod *m = &e->mods.mods[i];
    lua_createtable(L, 0, 6);
    lua_pushstring(L, m->id);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, m->name);
    lua_setfield(L, -2, "name");
    lua_pushstring(L, m->version);
    lua_setfield(L, -2, "version");
    lua_pushboolean(L, m->ok);
    lua_setfield(L, -2, "ok");
    lua_pushstring(L, m->status);
    lua_setfield(L, -2, "status");
    lua_pushstring(L, m->license_assets);
    lua_setfield(L, -2, "license_assets");
    lua_rawseti(L, -2, i + 1);
  }
  return 1;
}

/* add-home-among-stars: the mod browser - every local mod folder, whether it
 * is loaded now and whether it is switched off for the next start */
static int l_mods_available(lua_State *L) {
  sx_engine *e = get_engine(L);
  int i;
  lua_createtable(L, e->catalog.count, 0);
  for (i = 0; i < e->catalog.count; i++) {
    const sx_mod *m = &e->catalog.mods[i];
    int k = sx_modset_find(&e->mods, m->id);
    lua_createtable(L, 0, 8);
    lua_pushstring(L, m->id);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, m->name);
    lua_setfield(L, -2, "name");
    lua_pushstring(L, m->version);
    lua_setfield(L, -2, "version");
    lua_pushstring(L, m->description);
    lua_setfield(L, -2, "description");
    lua_pushstring(L, m->license_assets);
    lua_setfield(L, -2, "license_assets");
    lua_pushboolean(L, k >= 0 && e->mods.mods[k].ok);
    lua_setfield(L, -2, "loaded");
    lua_pushstring(L, k >= 0 ? e->mods.mods[k].status : "switched off");
    lua_setfield(L, -2, "status");
    lua_pushboolean(L, sx_engine_mod_disabled(e, m->id));
    lua_setfield(L, -2, "off");
    lua_rawseti(L, -2, i + 1);
  }
  return 1;
}

/* saucer.mods.set_enabled(id, on, player): writes <user-dir>/mods.txt. Only
 * the machine that owns `player` writes, and never while a replay plays. */
static int l_mods_set_enabled(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *id = luaL_checkstring(L, 1);
  int on = lua_toboolean(L, 2);
  lua_Integer player = luaL_optinteger(L, 3, 1);
  if (e->opt.play[0] || (e->net_on && player != e->net.local_slot)) {
    lua_pushboolean(L, 0);
    return 1;
  }
  lua_pushboolean(L, sx_engine_set_mod_enabled(e, id, on));
  return 1;
}

/* add-home-among-stars: the network session as the view and menus see it
 * (client-side: never feeds the sim) */
static int l_net_status(lua_State *L) {
  sx_engine *e = get_engine(L);
  const sx_net *n = &e->net;
  if (!e->net_on) return 0;
  lua_createtable(L, 0, 12);
  lua_pushstring(L, n->role == SX_NET_HOST ? "host" : "guest");
  lua_setfield(L, -2, "role");
  lua_pushstring(L, sx_net_state_name(n->state));
  lua_setfield(L, -2, "state");
  lua_pushinteger(L, n->local_slot);
  lua_setfield(L, -2, "slot");
  lua_pushinteger(L, n->nslots);
  lua_setfield(L, -2, "players");
  lua_pushinteger(L, n->max_slots);
  lua_setfield(L, -2, "max_players");
  lua_pushinteger(L, n->delay);
  lua_setfield(L, -2, "delay");
  lua_pushinteger(L, (lua_Integer)n->rtt_ms);
  lua_setfield(L, -2, "rtt");
  lua_pushinteger(L, (lua_Integer)n->checks);
  lua_setfield(L, -2, "checks");
  lua_pushinteger(L, (lua_Integer)n->desync_tick);
  lua_setfield(L, -2, "desync_tick");
  lua_pushstring(L, n->status);
  lua_setfield(L, -2, "status");
  lua_pushinteger(L, e->opt.net_port);
  lua_setfield(L, -2, "port");
  lua_pushboolean(L, e->opt.net_web);
  lua_setfield(L, -2, "web");
  lua_pushboolean(L, e->net_stalled);
  lua_setfield(L, -2, "waiting");
  return 1;
}

static int l_events_emit(lua_State *L) {
  sx_engine *e = get_engine(L);
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_rawgeti(L, LUA_REGISTRYINDEX, e->events_ref);
  lua_pushvalue(L, 1);
  lua_rawseti(L, -2, (lua_Integer)lua_rawlen(L, -2) + 1);
  return 0;
}

/* ---------- saucer.test (test mode only) ---------- */
static int l_test_state(lua_State *L) {
  lua_rawgeti(L, LUA_REGISTRYINDEX, get_engine(L)->state_ref);
  return 1;
}

static int l_test_state_hash(lua_State *L) {
  lua_pushinteger(L, (lua_Integer)sx_engine_state_hash(get_engine(L)));
  return 1;
}

static int l_test_snapshot(lua_State *L) {
  size_t n;
  unsigned char *d = sx_engine_snapshot(get_engine(L), &n);
  if (!d) return luaL_error(L, "snapshot failed");
  lua_pushlstring(L, (const char *)d, n);
  free(d);
  return 1;
}

static int l_test_restore(lua_State *L) {
  size_t n;
  const char *d = luaL_checklstring(L, 1, &n);
  lua_pushboolean(L, sx_engine_restore(get_engine(L), (const unsigned char *)d, n));
  return 1;
}

static int test_yield_ticks(lua_State *L, int ticks) {
  sx_engine *e = get_engine(L);
  if (L != e->test_co) return luaL_error(L, "saucer.test waits only work inside a game test script");
  e->test_wait = ticks < 1 ? 1 : ticks;
  return lua_yield(L, 0);
}

static int l_test_wait(lua_State *L) { return test_yield_ticks(L, (int)luaL_optinteger(L, 1, 1)); }

/* press(player, action, ticks): hold a button for `ticks` ticks (edge on the first) */
static int l_test_press(lua_State *L) {
  sx_engine *e = get_engine(L);
  int p = (int)luaL_checkinteger(L, 1), a = check_action(L, e, 2), ticks = (int)luaL_optinteger(L, 3, 1);
  if (p < 1 || p > SX_MAX_PLAYERS || e->input.actions[a].kind != SX_ACT_BUTTON)
    return luaL_error(L, "press: bad player or not a button");
  e->inject[p - 1].buttons_ticks[e->input.actions[a].slot] = ticks;
  if (lua_toboolean(L, 4)) return 0; /* no wait: combine with other inputs */
  return test_yield_ticks(L, ticks);
}

static int l_test_axis(lua_State *L) {
  sx_engine *e = get_engine(L);
  int p = (int)luaL_checkinteger(L, 1), a = check_action(L, e, 2), ticks = (int)luaL_optinteger(L, 4, 1);
  if (p < 1 || p > SX_MAX_PLAYERS || e->input.actions[a].kind != SX_ACT_AXIS)
    return luaL_error(L, "axis: bad player or not an axis");
  e->inject[p - 1].axes[e->input.actions[a].slot] = sx_quantize_axis((float)luaL_checknumber(L, 3));
  e->inject[p - 1].axes_ticks[e->input.actions[a].slot] = ticks;
  if (lua_toboolean(L, 5)) return 0;
  return test_yield_ticks(L, ticks);
}

static int l_test_assert(lua_State *L) {
  if (!lua_toboolean(L, 1)) {
    lua_Debug ar;
    const char *msg = luaL_optstring(L, 2, "assertion failed");
    if (lua_getstack(L, 1, &ar) && lua_getinfo(L, "Sl", &ar))
      return luaL_error(L, "%s:%d: %s", ar.short_src, ar.currentline, msg);
    return luaL_error(L, "%s", msg);
  }
  return 0;
}

static int l_test_screenshot(lua_State *L) {
  sx_engine *e = get_engine(L);
  strncpy(e->shot_path, luaL_checkstring(L, 1), sizeof e->shot_path - 1);
  e->shot_pending = 1;
  return 0;
}

static int l_test_audio_loops(lua_State *L) {
  lua_pushinteger(L, get_engine(L)->audio_nloops);
  return 1;
}

/* drop this frame's queued requests (specs run many "frames" in one) */
static int l_test_audio_flush(lua_State *L) {
  get_engine(L)->naudio = 0;
  return 0;
}

static int l_test_audio_count(lua_State *L) {
  lua_pushinteger(L, get_engine(L)->audio_played_total);
  return 1;
}

static int l_test_set_touch(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *what = luaL_checkstring(L, 1);
  long long id = (long long)luaL_optinteger(L, 2, 1);
  float x = (float)luaL_optnumber(L, 3, 0), y = (float)luaL_optnumber(L, 4, 0);
  if (strcmp(what, "down") == 0) sx_touch_down(&e->touch, id, x, y);
  else if (strcmp(what, "move") == 0) sx_touch_move(&e->touch, id, x, y);
  else sx_touch_up(&e->touch, id);
  return 0;
}

static int l_test_set_xr(lua_State *L) {
  sx_engine *e = get_engine(L);
  luaL_checktype(L, 1, LUA_TTABLE);
  e->xr.available = (int)field_num(L, 1, "available", (float)e->xr.available);
  e->xr.session = (int)field_num(L, 1, "session", (float)e->xr.session);
  field_vec(L, 1, "head_fwd", e->xr.head_fwd, 3);
  field_vec(L, 1, "head_pos", e->xr.head_pos, 3);
  e->xr.nviews = (int)field_num(L, 1, "views", (float)e->xr.nviews);
  if (e->xr.nviews < 0) e->xr.nviews = 0;
  if (e->xr.nviews > 2) e->xr.nviews = 2;
  lua_getfield(L, 1, "hands");
  if (lua_istable(L, -1)) {
    int i;
    for (i = 0; i < 2; i++) {
      lua_rawgeti(L, -1, i + 1);
      e->xr.hand_ok[i] = lua_istable(L, -1);
      if (e->xr.hand_ok[i]) field_vec(L, lua_gettop(L), "pose", e->xr.hands[i], 6);
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  lua_getfield(L, 1, "joints");
  if (lua_istable(L, -1)) {
    static const char *hn[2] = {"left", "right"};
    static const char *jn[SX_XR_JOINTS] = {"wrist", "thumb", "index", "middle", "ring", "pinky"};
    int i, k;
    for (i = 0; i < 2; i++) {
      float j[SX_XR_JOINTS * 3];
      lua_getfield(L, -1, hn[i]);
      if (lua_istable(L, -1)) {
        memset(j, 0, sizeof j);
        for (k = 0; k < SX_XR_JOINTS; k++) field_vec(L, lua_gettop(L), jn[k], j + k * 3, 3);
        sx_xr_set_joints(&e->xr, i, 1, j);
      } else if (!lua_isnil(L, -1)) {
        sx_xr_set_joints(&e->xr, i, 0, NULL);
      }
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  lua_getfield(L, 1, "mock_views");
  if (lua_toboolean(L, -1)) {
    sx_xr_mock_views(&e->xr, e->render.settings.width, e->render.settings.height, (float)field_num(L, 1, "ipd", 0.064f),
                     (float)field_num(L, 1, "fov", 90.0f));
    /* a headset's eye matrices carry the head's position (a standing session starts on the floor); the
     * engine keeps head positions flipped (x and z negated) against the WebXR frame of the views */
    {
      int eye;
      for (eye = 0; eye < 2; eye++) {
        e->xr.views[eye].view[12] += e->xr.head_pos[0];
        e->xr.views[eye].view[13] -= e->xr.head_pos[1];
        e->xr.views[eye].view[14] += e->xr.head_pos[2];
      }
    }
  }
  lua_pop(L, 1);
  lua_getfield(L, 1, "controls");
  if (lua_istable(L, -1)) {
    lua_pushnil(L);
    while (lua_next(L, -2)) {
      int c = sx_xr_ctl_from_name(luaL_checkstring(L, -2));
      if (c >= 0) e->xr.values[c] = (float)lua_tonumber(L, -1);
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  return 0;
}

/* test.xr_haptics() -> pulses requested so far, left pending strength, right pending strength */
static int l_test_xr_haptics(lua_State *L) {
  sx_engine *e = get_engine(L);
  lua_pushinteger(L, e->xr.haptic_total);
  lua_pushnumber(L, e->xr.haptic_strength[0]);
  lua_pushnumber(L, e->xr.haptic_strength[1]);
  return 3;
}

static int l_test_viewports(lua_State *L) {
  sx_engine *e = get_engine(L);
  int n = (int)luaL_checkinteger(L, 1);
  e->opt.viewports = n < 1 ? 1 : (n > SX_MAX_VIEWPORTS ? SX_MAX_VIEWPORTS : n);
  return 0;
}

/* ---------- sandbox ---------- */
static int l_forbidden(lua_State *L) {
  return luaL_error(L, "'%s' is not available to mods (sandbox)", lua_tostring(L, lua_upvalueindex(1)));
}

static int forbidden_index(lua_State *L) {
  return luaL_error(L, "'%s.%s' is not available to mods (sandbox)", lua_tostring(L, lua_upvalueindex(1)),
                    luaL_tolstring(L, 2, NULL));
}

static void push_forbidden_lib(lua_State *L, const char *name) {
  lua_newtable(L);
  lua_newtable(L);
  lua_pushstring(L, name);
  lua_pushcclosure(L, forbidden_index, 1);
  lua_setfield(L, -2, "__index");
  lua_setmetatable(L, -2);
}

static void copy_lib(lua_State *L, const char *name) {
  lua_newtable(L);
  lua_getglobal(L, name);
  lua_pushnil(L);
  while (lua_next(L, -2)) {
    lua_pushvalue(L, -2);
    lua_insert(L, -2);
    lua_rawset(L, -5);
  }
  lua_pop(L, 1);
}

/* text-only load() bound to the caller's environment */
static int l_safe_load(lua_State *L) {
  size_t n;
  const char *s = luaL_checklstring(L, 1, &n);
  const char *name = luaL_optstring(L, 2, "=(load)");
  if (luaL_loadbufferx(L, s, n, name, "t") != LUA_OK) {
    lua_pushnil(L);
    lua_insert(L, -2);
    return 2;
  }
  lua_pushvalue(L, lua_upvalueindex(1));
  lua_setupvalue(L, -2, 1);
  return 1;
}

static int l_print(lua_State *L) {
  int i, n = lua_gettop(L);
  luaL_Buffer b;
  luaL_buffinit(L, &b);
  for (i = 1; i <= n; i++) {
    if (i > 1) luaL_addchar(&b, '\t');
    luaL_tolstring(L, i, NULL);
    luaL_addvalue(&b);
  }
  luaL_pushresult(&b);
  SX_INFO("%s", lua_tostring(L, -1));
  return 0;
}

static int run_file_on(lua_State *L, const char *path, int env_ref, int nresults);

/* require(name): "sim.ship" -> scripts/sim/ship.lua through the VFS */
static int l_require(lua_State *L) {
  sx_engine *e = get_engine(L);
  const char *name = luaL_checkstring(L, 1);
  char rel[256], *full;
  size_t i, n = strlen(name);
  int mount = -1, k, env_ref = LUA_NOREF;
  if (n == 0 || n > 200) return luaL_error(L, "bad module name");
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.loaded");
  if (lua_getfield(L, -1, name) != LUA_TNIL) return 1;
  lua_pop(L, 1);
  memcpy(rel, "scripts/", 8);
  for (i = 0; i < n; i++) rel[8 + i] = name[i] == '.' ? '/' : name[i];
  memcpy(rel + 8 + n, ".lua", 5);
  full = sx_vfs_resolve(&e->vfs, rel, &mount);
  if (!full) return luaL_error(L, "module '%s' not found (looked for %s)", name, rel);
  /* the module runs in the environment of the mod that provides the file */
  for (k = 0; k < e->nrt; k++)
    if (strcmp(e->mods.mods[e->rt[k].mod_index].id, e->vfs.mounts[mount].id) == 0) env_ref = e->rt[k].env_ref;
  if (env_ref == LUA_NOREF) {
    lua_getfield(L, LUA_REGISTRYINDEX, "sx.test_env");
    env_ref = luaL_ref(L, LUA_REGISTRYINDEX); /* leaks one ref per test module: fine */
  }
  if (!run_file_on(L, full, env_ref, 1)) {
    free(full);
    return lua_error(L);
  }
  free(full);
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);
    lua_pushboolean(L, 1);
  }
  lua_pushvalue(L, -1);
  lua_setfield(L, -3, name);
  return 1;
}

int sx_script_run_file_in_env(sx_engine *e, const char *path, int env_ref, int nresults) {
  return run_file_on(e->L, path, env_ref, nresults);
}
static int run_file_on(lua_State *L, const char *path, int env_ref, int nresults) {
  size_t n;
  char *src = sx_fs_read(path, &n);
  char chunk[600];
  if (!src) {
    lua_pushfstring(L, "cannot read %s", path);
    return 0;
  }
  snprintf(chunk, sizeof chunk, "@%s", path);
  if (luaL_loadbufferx(L, src, n, chunk, "t") != LUA_OK) {
    free(src);
    return 0;
  }
  free(src);
  lua_rawgeti(L, LUA_REGISTRYINDEX, env_ref);
  lua_setupvalue(L, -2, 1);
  if (lua_pcall(L, 0, nresults, 0) != LUA_OK) return 0;
  return 1;
}

static void set_funcs(lua_State *L, const luaL_Reg *r) { luaL_setfuncs(L, r, 0); }

static void build_saucer_api(lua_State *L, sx_engine *e) {
  static const luaL_Reg log_f[] = {{"info", l_log_info}, {"warn", l_log_warn}, {"error", l_log_error}, {NULL, NULL}};
  static const luaL_Reg vfs_f[] = {{"read", l_vfs_read}, {"list", l_vfs_list}, {"exists", l_vfs_exists}, {NULL, NULL}};
  static const luaL_Reg reg_f[] = {
      {"define", l_reg_define}, {"get", l_reg_get}, {"extend", l_reg_extend}, {"all", l_reg_all}, {NULL, NULL}};
  static const luaL_Reg rng_f[] = {{"new", l_rng_new}, {NULL, NULL}};
  static const luaL_Reg math_f[] = {{"sin", l_m_sin},     {"cos", l_m_cos},       {"sqrt", l_m_sqrt},
                                    {"atan", l_m_atan},   {"atan2", l_m_atan2},   {"wrap", l_m_wrap},
                                    {"fx", l_m_fx},       {"fx_to", l_m_fx_to},   {"fxmul", l_m_fxmul},
                                    {"fxdiv", l_m_fxdiv}, {NULL, NULL}};
  static const luaL_Reg util_f[] = {{"sorted_pairs", l_util_sorted_pairs},
                                    {"sorted_keys", l_util_sorted_keys},
                                    {"readonly", l_util_readonly},
                                    {NULL, NULL}};
  static const luaL_Reg players_f[] = {{"count", l_players_count}, {"get", l_players_get}, {NULL, NULL}};
  static const luaL_Reg input_f[] = {{"define_action", l_input_define}, {"bind", l_input_bind},
                                     {"rebind", l_input_rebind},        {"bindings", l_input_bindings},
                                     {"device_mode", l_input_mode},     {"touch_layout", l_input_touch_layout},
                                     {"join_offers", l_input_join_offers}, {"command", l_input_command},
                                     {NULL, NULL}};
  static const luaL_Reg phys_f[] = {{"clear", l_ph_clear},         {"add_box", l_ph_add_box}, {"remove", l_ph_remove},
                                    {"count", l_ph_count},         {"clearance", l_ph_clearance},
                                    {"move", l_ph_move},           {"raycast", l_ph_raycast},
                                    {"cone_visible", l_ph_cone},   {NULL, NULL}};
  static const luaL_Reg procgen_f[] = {{"grid_new", l_grid_new}, {"reachable", l_reachable}, {NULL, NULL}};
  static const luaL_Reg mesh_f[] = {{"build", l_mesh_build}, {"info", l_mesh_info}, {"free", l_mesh_free}, {NULL, NULL}};
  static const luaL_Reg render_f[] = {
      {"texture", l_r_texture}, {"palette", l_r_palette}, {"settings", l_r_settings}, {"stats", l_r_stats}, {NULL, NULL}};
  static const luaL_Reg xr_f[] = {
      {"available", l_xr_available}, {"session", l_xr_session}, {"comfort", l_xr_comfort}, {"haptic", l_xr_haptic},
      {"set_comfort", l_xr_set_comfort}, {"save_comfort", l_xr_save_comfort}, {"head", l_xr_head},
      {"hands", l_xr_hands}, {"lever", l_xr_lever},
      {NULL, NULL}};
  static const luaL_Reg audio_f[] = {
      {"play", l_audio_play}, {"set", l_audio_set}, {"stop", l_audio_stop}, {NULL, NULL}};
  static const luaL_Reg save_f[] = {{"write", l_save_write}, {"read", l_save_read}, {NULL, NULL}};
  static const luaL_Reg time_f[] = {{"tick", l_time_tick}, {"sim_seconds", l_time_seconds}, {NULL, NULL}};
  static const luaL_Reg mods_f[] = {{"list", l_mods_list},
                                         {"available", l_mods_available},
                                         {"set_enabled", l_mods_set_enabled},
                                         {NULL, NULL}};
  static const luaL_Reg net_f[] = {{"status", l_net_status}, {NULL, NULL}};
  static const luaL_Reg events_f[] = {{"emit", l_events_emit}, {NULL, NULL}};
  static const luaL_Reg test_f[] = {{"state", l_test_state},           {"state_hash", l_test_state_hash},
                                    {"snapshot", l_test_snapshot},     {"restore", l_test_restore},
                                    {"wait", l_test_wait},             {"press", l_test_press},
                                    {"axis", l_test_axis},             {"assert", l_test_assert},
                                    {"screenshot", l_test_screenshot}, {"audio_count", l_test_audio_count},
                                    {"audio_loops", l_test_audio_loops}, {"audio_flush", l_test_audio_flush},
                                    {"touch", l_test_set_touch},       {"xr", l_test_set_xr},
                                    {"xr_haptics", l_test_xr_haptics},
                                    {"viewports", l_test_viewports},   {NULL, NULL}};
  struct {
    const char *name;
    const luaL_Reg *f;
  } libs[] = {{"log", log_f},         {"vfs", vfs_f},       {"registry", reg_f}, {"rng", rng_f},
              {"math", math_f},       {"util", util_f},     {"players", players_f}, {"input", input_f},
              {"physics", phys_f},    {"procgen", procgen_f}, {"mesh", mesh_f},   {"render", render_f},
              {"xr", xr_f},           {"audio", audio_f},   {"save", save_f},    {"time", time_f},
              {"mods", mods_f},       {"events", events_f}, {"net", net_f},       {NULL, NULL}};
  int i;
  lua_newtable(L);
  for (i = 0; libs[i].name; i++) {
    lua_newtable(L);
    set_funcs(L, libs[i].f);
    lua_setfield(L, -2, libs[i].name);
  }
  if (e->opt.test_mode) {
    lua_newtable(L);
    set_funcs(L, test_f);
    lua_setfield(L, -2, "test");
  }
  lua_getfield(L, -1, "math");
  lua_pushnumber(L, SX_PI);
  lua_setfield(L, -2, "pi");
  lua_pushnumber(L, SX_TAU);
  lua_setfield(L, -2, "tau");
  lua_pop(L, 1);
  lua_pushcfunction(L, l_hash64);
  lua_setfield(L, -2, "hash64");
  lua_pushcfunction(L, l_seed_child);
  lua_setfield(L, -2, "seed_child");
  lua_createtable(L, 0, 5);
  lua_pushstring(L, SX_VERSION);
  lua_setfield(L, -2, "version");
  lua_pushinteger(L, SX_ENGINE_API);
  lua_setfield(L, -2, "api");
  lua_pushboolean(L, e->opt.headless);
  lua_setfield(L, -2, "headless");
  lua_pushinteger(L, (lua_Integer)e->opt.seed);
  lua_setfield(L, -2, "seed");
#if defined(__EMSCRIPTEN__)
  lua_pushstring(L, "web");
#elif defined(_WIN32)
  lua_pushstring(L, "windows");
#else
  lua_pushstring(L, "linux");
#endif
  lua_setfield(L, -2, "platform");
  lua_setfield(L, -2, "engine");
}

/* Build the shared sandbox globals table (registry "sx.sandbox"). */
static void build_sandbox(lua_State *L, sx_engine *e) {
  static const char *safe[] = {"assert", "error",    "ipairs", "next",   "pairs",        "pcall",  "rawequal",
                               "rawget", "rawlen",   "rawset", "select", "setmetatable", "getmetatable",
                               "tonumber", "tostring", "type", "xpcall", NULL};
  int i;
  lua_newtable(L); /* sandbox */
  for (i = 0; safe[i]; i++) {
    lua_getglobal(L, safe[i]);
    lua_setfield(L, -2, safe[i]);
  }
  lua_pushstring(L, SX_VERSION);
  lua_setfield(L, -2, "_SAUCER");
  lua_pushcfunction(L, l_print);
  lua_setfield(L, -2, "print");
  lua_pushcfunction(L, l_require);
  lua_setfield(L, -2, "require");
  copy_lib(L, "string");
  lua_setfield(L, -2, "string");
  copy_lib(L, "table");
  lua_setfield(L, -2, "table");
  copy_lib(L, "utf8");
  lua_setfield(L, -2, "utf8");
  lua_getglobal(L, "coroutine"); /* shared so luacov can follow coroutines */
  lua_setfield(L, -2, "coroutine");
  copy_lib(L, "math");
  /* deterministic replacements */
  lua_pushcfunction(L, l_m_sin);
  lua_setfield(L, -2, "sin");
  lua_pushcfunction(L, l_m_cos);
  lua_setfield(L, -2, "cos");
  lua_pushcfunction(L, l_m_sqrt);
  lua_setfield(L, -2, "sqrt");
  lua_pushcfunction(L, l_m_atan);
  lua_setfield(L, -2, "atan");
  lua_pushcfunction(L, l_m_random);
  lua_setfield(L, -2, "random");
  lua_pushcfunction(L, l_m_random);
  lua_setfield(L, -2, "randomseed");
  {
    static const char *drop[] = {"tan", "asin", "acos", "exp", "log", NULL};
    for (i = 0; drop[i]; i++) {
      lua_pushstring(L, drop[i]);
      lua_pushcclosure(L, l_forbidden, 1);
      lua_setfield(L, -2, drop[i]);
    }
  }
  lua_setfield(L, -2, "math");
  {
    static const char *libs[] = {"io", "os", "debug", "package", NULL};
    static const char *fns[] = {"dofile", "loadfile", "collectgarbage", NULL};
    for (i = 0; libs[i]; i++) {
      push_forbidden_lib(L, libs[i]);
      lua_setfield(L, -2, libs[i]);
    }
    for (i = 0; fns[i]; i++) {
      lua_pushstring(L, fns[i]);
      lua_pushcclosure(L, l_forbidden, 1);
      lua_setfield(L, -2, fns[i]);
    }
  }
  build_saucer_api(L, e);
  lua_setfield(L, -2, "saucer");
  lua_setfield(L, LUA_REGISTRYINDEX, "sx.sandbox");
}

/* New mod environment: own globals, falling back to the sandbox. */
int sx_script_new_env(lua_State *L, const char *mod_id);
int sx_script_new_env(lua_State *L, const char *mod_id) {
  lua_newtable(L);
  lua_newtable(L);
  lua_getfield(L, LUA_REGISTRYINDEX, "sx.sandbox");
  lua_setfield(L, -2, "__index");
  lua_setmetatable(L, -2);
  lua_pushstring(L, mod_id);
  lua_setfield(L, -2, "_MOD");
  lua_pushvalue(L, -1);
  lua_pushcclosure(L, l_safe_load, 1);
  lua_setfield(L, -2, "load");
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "_G");
  return luaL_ref(L, LUA_REGISTRYINDEX);
}

static void budget_hook(lua_State *L, lua_Debug *ar) {
  sx_engine *e = get_engine(L);
  (void)ar;
  e->budget_left -= 1000;
  if (e->budget_left < 0) {
    e->budget_left = 1LL << 40; /* let the error unwind */
    luaL_error(L, "instruction budget exceeded");
  }
}

int sx_script_open(sx_engine *e) {
  lua_State *L = luaL_newstate();
  if (!L) return 0;
  e->L = L;
  luaL_openlibs(L);
  lua_pushlightuserdata(L, e);
  lua_setfield(L, LUA_REGISTRYINDEX, ENGINE_KEY);
  lua_newtable(L);
  lua_setfield(L, LUA_REGISTRYINDEX, "sx.registry");
  lua_newtable(L);
  lua_setfield(L, LUA_REGISTRYINDEX, "sx.loaded");
  /* weak tables for read-only proxies */
  lua_newtable(L);
  lua_newtable(L);
  lua_pushstring(L, "k");
  lua_setfield(L, -2, "__mode");
  lua_setmetatable(L, -2);
  lua_setfield(L, LUA_REGISTRYINDEX, "sx.ro_cache");
  lua_newtable(L);
  lua_newtable(L);
  lua_pushstring(L, "k");
  lua_setfield(L, -2, "__mode");
  lua_setmetatable(L, -2);
  lua_setfield(L, LUA_REGISTRYINDEX, "sx.ro_targets");
  luaL_newmetatable(L, RO_MT);
  lua_pushcfunction(L, ro_index);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, ro_newindex);
  lua_setfield(L, -2, "__newindex");
  lua_pushcfunction(L, ro_len);
  lua_setfield(L, -2, "__len");
  lua_pushcfunction(L, ro_pairs);
  lua_setfield(L, -2, "__pairs");
  lua_pushstring(L, "readonly");
  lua_setfield(L, -2, "__metatable");
  lua_pop(L, 1);
  {
    static const luaL_Reg rng_m[] = {{"int", l_rng_int},     {"fixed", l_rng_fixed}, {"float", l_rng_float},
                                     {"pick", l_rng_pick},   {"weighted", l_rng_weighted}, {"child", l_rng_child},
                                     {"seed", l_rng_seed},   {NULL, NULL}};
    static const luaL_Reg grid_m[] = {{"place", l_grid_place}, {"free", l_grid_free}, {"get", l_grid_get}, {NULL, NULL}};
    static const luaL_Reg view_m[] = {{"camera", l_v_camera}, {"fog", l_v_fog},     {"mesh", l_v_mesh},
                                      {"billboard", l_v_billboard}, {"rect", l_v_rect}, {"text", l_v_text},
                                      {"image", l_v_image},   {"vignette", l_v_vignette}, {NULL, NULL}};
    static const luaL_Reg cmd_m[] = {{"held", l_cmd_held}, {"pressed", l_cmd_pressed}, {"axis", l_cmd_axis}, {NULL, NULL}};
    luaL_newmetatable(L, RNG_MT);
    lua_newtable(L);
    set_funcs(L, rng_m);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    luaL_newmetatable(L, GRID_MT);
    lua_newtable(L);
    set_funcs(L, grid_m);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, l_grid_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    luaL_newmetatable(L, VIEW_MT);
    lua_newtable(L);
    set_funcs(L, view_m);
    lua_setfield(L, -2, "methods");
    lua_pushcfunction(L, l_v_index);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    luaL_newmetatable(L, CMD_MT);
    lua_newtable(L);
    set_funcs(L, cmd_m);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
  }
  lua_newtable(L);
  e->events_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  lua_newtable(L);
  e->state_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  build_sandbox(L, e);
  if (!e->opt.coverage) {
    lua_sethook(L, budget_hook, LUA_MASKCOUNT, 1000);
    e->budget_hook = 1;
  }
  e->budget_left = 1LL << 40;
  return 1;
}

void sx_script_close(sx_engine *e) {
  if (e->L) lua_close(e->L);
  e->L = NULL;
}

int sx_script_load_mods(sx_engine *e) {
  lua_State *L = e->L;
  int i;
  for (i = 0; i < e->mods.order_count; i++) {
    sx_mod *m = &e->mods.mods[e->mods.order[i]];
    sx_mod_rt *rt = &e->rt[e->nrt];
    rt->mod_index = e->mods.order[i];
    rt->env_ref = sx_script_new_env(L, m->id);
    rt->strikes = 0;
    rt->disabled = 0;
    e->nrt++;
  }
  for (i = 0; i < e->nrt; i++) {
    sx_mod *m = &e->mods.mods[e->rt[i].mod_index];
    char *full;
    if (!m->entry[0]) continue;
    full = sx_path_join(m->root, m->entry);
    e->budget_left = 1LL << 40;
    if (!sx_script_run_file_in_env(e, full, e->rt[i].env_ref, 0)) {
      SX_ERROR("[mod %s] %s", m->id, lua_tostring(L, -1));
      lua_pop(L, 1);
      e->rt[i].disabled = 1;
      if (strcmp(m->id, "base") == 0) {
        free(full);
        return 0;
      }
    }
    free(full);
  }
  return 1;
}

static int traceback(lua_State *L) {
  luaL_traceback(L, L, lua_tostring(L, 1), 1);
  return 1;
}

int sx_script_call_hook(sx_engine *e, const char *name, int nargs, long long budget) {
  lua_State *L = e->L;
  int i, k, base = lua_gettop(L) - nargs, ok = 1;
  for (i = 0; i < e->nrt; i++) {
    sx_mod_rt *rt = &e->rt[i];
    const char *id = e->mods.mods[rt->mod_index].id;
    if (rt->disabled) continue;
    lua_rawgeti(L, LUA_REGISTRYINDEX, rt->env_ref);
    lua_getfield(L, -1, name);
    lua_remove(L, -2);
    if (!lua_isfunction(L, -1)) {
      lua_pop(L, 1);
      continue;
    }
    lua_pushcfunction(L, traceback);
    lua_insert(L, -2);
    for (k = 1; k <= nargs; k++) lua_pushvalue(L, base + k);
    e->budget_left = budget;
    if (lua_pcall(L, nargs, 0, base + nargs + 1) != LUA_OK) {
      const char *msg = lua_tostring(L, -1);
      if (msg && strstr(msg, "instruction budget exceeded")) {
        rt->strikes++;
        SX_WARN("[mod %s] %s overran its instruction budget (strike %d/3)", id, name, rt->strikes);
        if (rt->strikes >= 3) {
          rt->disabled = 1;
          SX_WARN("[mod %s] disabled after 3 budget overruns", id);
        }
      } else {
        SX_ERROR("[mod %s] %s: %s", id, name, msg ? msg : "?");
        ok = 0;
        if (e->opt.test_mode) {
          e->failed = 1;
          snprintf(e->fail_msg, sizeof e->fail_msg, "[mod %s] %s", id, msg ? msg : "?");
        }
      }
      lua_pop(L, 1);
    }
    lua_pop(L, 1); /* traceback fn */
  }
  e->budget_left = 1LL << 40;
  lua_settop(L, base);
  return ok;
}

void sx_script_push_view(lua_State *L, int index);
void sx_script_push_view(lua_State *L, int index) { push_view(L, index); }
