/* SPDX-License-Identifier: MIT */
#include "sx_mod.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include "sx_log.h"

static void copy_str(char *dst, size_t cap, const char *src) {
  size_t n = strlen(src);
  if (n >= cap) n = cap - 1;
  memcpy(dst, src, n);
  dst[n] = 0;
}

int sx_version_cmp(const char *a, const char *b) {
  while (*a || *b) {
    long x = strtol(a, (char **)&a, 10);
    long y = strtol(b, (char **)&b, 10);
    if (x != y) return x < y ? -1 : 1;
    if (*a == '.') a++;
    else if (*a) a = "";
    if (*b == '.') b++;
    else if (*b) b = "";
  }
  return 0;
}

int sx_version_satisfies(const char *version, const char *req) {
  int c;
  while (*req == ' ') req++;
  if (!*req) return 1;
  if (req[0] == '>' && req[1] == '=') return sx_version_cmp(version, req + 2) >= 0;
  if (req[0] == '<' && req[1] == '=') return sx_version_cmp(version, req + 2) <= 0;
  if (req[0] == '>') return sx_version_cmp(version, req + 1) > 0;
  if (req[0] == '<') return sx_version_cmp(version, req + 1) < 0;
  if (req[0] == '=') req++;
  c = sx_version_cmp(version, req);
  return c == 0;
}

static void get_str(lua_State *L, const char *key, char *dst, size_t cap, const char *def) {
  lua_getfield(L, -1, key);
  copy_str(dst, cap, lua_type(L, -1) == LUA_TSTRING ? lua_tostring(L, -1) : def);
  lua_pop(L, 1);
}

static void get_list(lua_State *L, const char *key, sx_strlist *ids, sx_strlist *reqs) {
  lua_Integer i, n;
  lua_getfield(L, -1, key);
  if (lua_type(L, -1) == LUA_TTABLE) {
    n = (lua_Integer)lua_rawlen(L, -1);
    for (i = 1; i <= n; i++) {
      lua_rawgeti(L, -1, i);
      if (lua_type(L, -1) == LUA_TSTRING) {
        char buf[128];
        char *sp;
        copy_str(buf, sizeof buf, lua_tostring(L, -1));
        sp = strchr(buf, ' ');
        if (sp) *sp++ = 0;
        sx_strlist_push(ids, buf);
        if (reqs) sx_strlist_push(reqs, sp ? sp : "");
      }
      lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
}

static void count_hook(lua_State *L, lua_Debug *ar) {
  (void)ar;
  luaL_error(L, "manifest exceeded instruction budget");
}

int sx_mod_parse(const char *src, size_t len, const char *root, sx_mod *out, char *err, size_t errlen) {
  lua_State *L = luaL_newstate();
  int ok = 0;
  memset(out, 0, sizeof *out);
  copy_str(out->root, sizeof out->root, root ? root : "");
  /* Manifests are pure data: no libraries at all, and a small instruction cap. */
  lua_sethook(L, count_hook, LUA_MASKCOUNT, 100000);
  if (luaL_loadbufferx(L, src, len, "=mod.lua", "t") != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
    snprintf(err, errlen, "manifest error: %s", lua_tostring(L, -1));
  } else if (lua_type(L, -1) != LUA_TTABLE) {
    snprintf(err, errlen, "manifest must return a table");
  } else {
    get_str(L, "id", out->id, sizeof out->id, "");
    get_str(L, "name", out->name, sizeof out->name, out->id);
    get_str(L, "version", out->version, sizeof out->version, "0.0.0");
    get_str(L, "entry", out->entry, sizeof out->entry, "");
    get_str(L, "license_code", out->license_code, sizeof out->license_code, "unknown");
    get_str(L, "license_assets", out->license_assets, sizeof out->license_assets, "unknown");
    lua_getfield(L, -1, "api");
    out->api = lua_isinteger(L, -1) ? (int)lua_tointeger(L, -1) : -1;
    lua_pop(L, 1);
    get_list(L, "depends", &out->depends, &out->depends_req);
    get_list(L, "load_after", &out->load_after, NULL);
    if (!out->id[0]) snprintf(err, errlen, "manifest has no id");
    else ok = 1;
  }
  lua_close(L);
  copy_str(out->status, sizeof out->status, ok ? "ok" : err);
  return ok;
}

void sx_mod_free(sx_mod *m) {
  sx_strlist_free(&m->depends);
  sx_strlist_free(&m->depends_req);
  sx_strlist_free(&m->load_after);
}

void sx_modset_init(sx_modset *s) { memset(s, 0, sizeof *s); }

void sx_modset_free(sx_modset *s) {
  int i;
  for (i = 0; i < s->count; i++) sx_mod_free(&s->mods[i]);
  s->count = s->order_count = 0;
}

int sx_modset_find(const sx_modset *s, const char *id) {
  int i;
  for (i = 0; i < s->count; i++)
    if (strcmp(s->mods[i].id, id) == 0) return i;
  return -1;
}

int sx_modset_add_dir(sx_modset *s, const char *dir) {
  char *path, *src;
  size_t len = 0;
  char err[256];
  sx_mod *m;
  if (s->count >= SX_MAX_MODS) return -1;
  path = sx_path_join(dir, "mod.lua");
  src = sx_fs_read(path, &len);
  free(path);
  if (!src) return -1;
  m = &s->mods[s->count];
  if (!sx_mod_parse(src, len, dir, m, err, sizeof err)) {
    SX_WARN("mod at %s: %s", dir, err);
    sx_mod_free(m);
    free(src);
    return -1;
  }
  free(src);
  if (sx_modset_find(s, m->id) >= 0) {
    SX_WARN("duplicate mod id '%s' at %s ignored", m->id, dir);
    sx_mod_free(m);
    return -1;
  }
  return s->count++;
}

static int csv_has(const char *csv, const char *id) {
  size_t n = strlen(id);
  const char *p = csv;
  while (*p) {
    const char *e = strchr(p, ',');
    size_t len = e ? (size_t)(e - p) : strlen(p);
    if (len == n && strncmp(p, id, n) == 0) return 1;
    if (!e) break;
    p = e + 1;
  }
  return 0;
}

int sx_modset_scan(sx_modset *s, const char *base_dir, const char *mods_dir, const char *enabled_csv) {
  sx_strlist dirs = {0};
  int i, base;
  base = sx_modset_add_dir(s, base_dir);
  if (base < 0) {
    SX_ERROR("base game not found at %s", base_dir);
    return 0;
  }
  if (mods_dir && sx_fs_list(mods_dir, 1, &dirs)) {
    for (i = 0; i < dirs.count; i++) {
      char *d = sx_path_join(mods_dir, dirs.items[i]);
      int idx = sx_modset_add_dir(s, d);
      if (idx >= 0 && enabled_csv && !csv_has(enabled_csv, s->mods[idx].id)) {
        sx_mod_free(&s->mods[idx]);
        s->count--;
      }
      free(d);
    }
  }
  sx_strlist_free(&dirs);
  return 1;
}

static void fail_msg(sx_mod *m, const char *buf) {
  copy_str(m->status, sizeof m->status, buf);
  m->ok = 0;
  SX_WARN("mod '%s' not loaded: %s", m->id, buf);
}

static void fail(sx_mod *m, const char *fmt, const char *a) {
  char buf[256];
  snprintf(buf, sizeof buf, fmt, a);
  fail_msg(m, buf);
}

static void fail_api(sx_mod *m, int api, int engine_api) {
  char buf[256];
  snprintf(buf, sizeof buf, "incompatible API %d (engine %d)", api, engine_api);
  fail_msg(m, buf);
}

int sx_modset_resolve(sx_modset *s, int engine_api) {
  int i, j, changed, placed[SX_MAX_MODS] = {0};
  s->order_count = 0;
  for (i = 0; i < s->count; i++) {
    sx_mod *m = &s->mods[i];
    m->ok = 1;
    copy_str(m->status, sizeof m->status, "ok");
    if (m->api != engine_api) fail_api(m, m->api, engine_api);
  }
  /* Missing/unsatisfied dependencies propagate until stable. */
  do {
    changed = 0;
    for (i = 0; i < s->count; i++) {
      sx_mod *m = &s->mods[i];
      if (!m->ok) continue;
      for (j = 0; j < m->depends.count; j++) {
        int d = sx_modset_find(s, m->depends.items[j]);
        if (d < 0) {
          fail(m, "missing dependency %s", m->depends.items[j]);
          changed = 1;
          break;
        }
        if (!sx_version_satisfies(s->mods[d].version, m->depends_req.items[j])) {
          fail(m, "dependency %s version not satisfied", m->depends.items[j]);
          changed = 1;
          break;
        }
        if (!s->mods[d].ok && strncmp(s->mods[d].status, "dependency cycle", 16) != 0) {
          fail(m, "dependency %s failed to load", m->depends.items[j]);
          changed = 1;
          break;
        }
      }
    }
  } while (changed);
  /* Kahn's algorithm, picking the alphabetically smallest ready mod; base first. */
  for (;;) {
    int best = -1;
    for (i = 0; i < s->count; i++) {
      sx_mod *m = &s->mods[i];
      int ready = 1;
      if (!m->ok || placed[i]) continue;
      if (strcmp(m->id, "base") != 0) {
        int b = sx_modset_find(s, "base");
        if (b >= 0 && s->mods[b].ok && !placed[b]) ready = 0;
      }
      for (j = 0; ready && j < m->depends.count; j++) {
        int d = sx_modset_find(s, m->depends.items[j]);
        if (!placed[d]) ready = 0;
      }
      for (j = 0; ready && j < m->load_after.count; j++) {
        int d = sx_modset_find(s, m->load_after.items[j]);
        if (d >= 0 && s->mods[d].ok && !placed[d]) ready = 0;
      }
      if (ready && (best < 0 || strcmp(m->id, s->mods[best].id) < 0)) best = i;
    }
    if (best < 0) break;
    placed[best] = 1;
    s->order[s->order_count++] = best;
  }
  /* Anything ok but unplaced is part of (or behind) a cycle. */
  {
    char cyc[200] = "";
    for (i = 0; i < s->count; i++) {
      if (s->mods[i].ok && !placed[i]) {
        size_t n = strlen(cyc);
        snprintf(cyc + n, sizeof cyc - n, "%s%s", n ? " <-> " : "", s->mods[i].id);
      }
    }
    for (i = 0; i < s->count; i++)
      if (s->mods[i].ok && !placed[i]) fail(&s->mods[i], "dependency cycle: %s", cyc);
  }
  return s->order_count;
}
