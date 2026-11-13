/* SPDX-License-Identifier: MIT */
#include "sx_ser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lauxlib.h"
#include "sx_rng.h"

enum { T_NIL = 0, T_FALSE = 1, T_TRUE = 2, T_INT = 3, T_FLT = 4, T_STR = 5, T_TAB = 6 };
static const char MAGIC[4] = {'S', 'X', 'S', '1'};

void sx_buf_put(sx_buf *b, const void *p, size_t n) {
  if (b->len + n > b->cap) {
    size_t c = b->cap ? b->cap : 256;
    while (c < b->len + n) c *= 2;
    b->data = (unsigned char *)realloc(b->data, c);
    b->cap = c;
  }
  memcpy(b->data + b->len, p, n);
  b->len += n;
}

void sx_buf_free(sx_buf *b) {
  free(b->data);
  b->data = NULL;
  b->len = b->cap = 0;
}

static void put_u8(sx_buf *b, unsigned v) {
  unsigned char c = (unsigned char)v;
  sx_buf_put(b, &c, 1);
}

static void put_u64(sx_buf *b, uint64_t v) {
  unsigned char c[8];
  int i;
  for (i = 0; i < 8; i++) c[i] = (unsigned char)(v >> (8 * i));
  sx_buf_put(b, c, 8);
}

typedef struct key_ref {
  int type; /* ordering class: 0 int/float numbers, 1 bool, 2 string */
  int is_int;
  lua_Integer i;
  lua_Number n;
  const char *s;
  size_t slen;
  int boolean;
  int ref; /* index in the key array table */
} key_ref;

static int key_cmp(const void *pa, const void *pb) {
  const key_ref *a = (const key_ref *)pa, *b = (const key_ref *)pb;
  if (a->type != b->type) return a->type < b->type ? -1 : 1;
  if (a->type == 0) {
    lua_Number x = a->is_int ? (lua_Number)a->i : a->n;
    lua_Number y = b->is_int ? (lua_Number)b->i : b->n;
    if (a->is_int && b->is_int) return a->i < b->i ? -1 : (a->i > b->i);
    if (x != y) return x < y ? -1 : 1;
    return a->is_int - b->is_int;
  }
  if (a->type == 1) return a->boolean - b->boolean;
  {
    size_t n = a->slen < b->slen ? a->slen : b->slen;
    int c = memcmp(a->s, b->s, n);
    if (c) return c;
    return a->slen < b->slen ? -1 : (a->slen > b->slen);
  }
}

static int write_value(lua_State *L, int idx, sx_buf *out, int depth, char *err, size_t errlen);

static int write_table(lua_State *L, int idx, sx_buf *out, int depth, char *err, size_t errlen) {
  key_ref *keys = NULL;
  int n = 0, cap = 0, i, ok = 1, keytab;
  idx = lua_absindex(L, idx);
  if (depth >= SX_SER_MAX_DEPTH) {
    snprintf(err, errlen, "table nesting too deep (cycle?)");
    return 0;
  }
  lua_newtable(L); /* holds keys so strings stay alive */
  keytab = lua_gettop(L);
  lua_pushnil(L);
  while (lua_next(L, idx)) {
    key_ref k;
    int kt = lua_type(L, -2);
    memset(&k, 0, sizeof k);
    if (kt == LUA_TNUMBER) {
      k.type = 0;
      k.is_int = lua_isinteger(L, -2);
      if (k.is_int) k.i = lua_tointeger(L, -2);
      else k.n = lua_tonumber(L, -2);
    } else if (kt == LUA_TBOOLEAN) {
      k.type = 1;
      k.boolean = lua_toboolean(L, -2);
    } else if (kt == LUA_TSTRING) {
      k.type = 2;
      k.s = lua_tolstring(L, -2, &k.slen);
    } else {
      snprintf(err, errlen, "unsupported key type %s", lua_typename(L, kt));
      lua_pop(L, 2);
      ok = 0;
      break;
    }
    if (n == cap) {
      cap = cap ? cap * 2 : 16;
      keys = (key_ref *)realloc(keys, sizeof(key_ref) * (size_t)cap);
    }
    lua_pushvalue(L, -2);
    lua_rawseti(L, keytab, n + 1);
    k.ref = n + 1;
    keys[n++] = k;
    lua_pop(L, 1);
  }
  if (ok) {
    qsort(keys, (size_t)n, sizeof(key_ref), key_cmp);
    put_u8(out, T_TAB);
    put_u64(out, (uint64_t)n);
    for (i = 0; i < n && ok; i++) {
      lua_rawgeti(L, keytab, keys[i].ref);
      ok = write_value(L, -1, out, depth + 1, err, errlen);
      if (ok) {
        lua_rawget(L, idx); /* consumes key copy... re-fetch below */
        ok = write_value(L, -1, out, depth + 1, err, errlen);
      }
      lua_pop(L, 1);
    }
  }
  free(keys);
  lua_settop(L, keytab - 1);
  return ok;
}

static int write_value(lua_State *L, int idx, sx_buf *out, int depth, char *err, size_t errlen) {
  int t = lua_type(L, idx);
  switch (t) {
  case LUA_TNIL: put_u8(out, T_NIL); return 1;
  case LUA_TBOOLEAN: put_u8(out, lua_toboolean(L, idx) ? T_TRUE : T_FALSE); return 1;
  case LUA_TNUMBER:
    if (lua_isinteger(L, idx)) {
      put_u8(out, T_INT);
      put_u64(out, (uint64_t)lua_tointeger(L, idx));
    } else {
      lua_Number v = lua_tonumber(L, idx);
      uint64_t bits;
      memcpy(&bits, &v, 8);
      put_u8(out, T_FLT);
      put_u64(out, bits);
    }
    return 1;
  case LUA_TSTRING: {
    size_t n;
    const char *s = lua_tolstring(L, idx, &n);
    put_u8(out, T_STR);
    put_u64(out, (uint64_t)n);
    sx_buf_put(out, s, n);
    return 1;
  }
  case LUA_TTABLE: return write_table(L, idx, out, depth, err, errlen);
  default: snprintf(err, errlen, "cannot serialize a %s", lua_typename(L, t)); return 0;
  }
}

int sx_ser_write(lua_State *L, int idx, sx_buf *out, char *err, size_t errlen) {
  int top = lua_gettop(L), ok;
  idx = lua_absindex(L, idx);
  sx_buf_put(out, MAGIC, 4);
  ok = write_value(L, idx, out, 0, err, errlen);
  lua_settop(L, top);
  return ok;
}

typedef struct reader {
  const unsigned char *p, *end;
} reader;

static int get_u64(reader *r, uint64_t *v) {
  int i;
  if (r->end - r->p < 8) return 0;
  *v = 0;
  for (i = 0; i < 8; i++) *v |= (uint64_t)r->p[i] << (8 * i);
  r->p += 8;
  return 1;
}

static int read_value(lua_State *L, reader *r, int depth) {
  uint64_t v, n, i;
  int t;
  if (r->p >= r->end || depth > SX_SER_MAX_DEPTH) return 0;
  t = *r->p++;
  switch (t) {
  case T_NIL: lua_pushnil(L); return 1;
  case T_FALSE: lua_pushboolean(L, 0); return 1;
  case T_TRUE: lua_pushboolean(L, 1); return 1;
  case T_INT:
    if (!get_u64(r, &v)) return 0;
    lua_pushinteger(L, (lua_Integer)v);
    return 1;
  case T_FLT: {
    lua_Number d;
    if (!get_u64(r, &v)) return 0;
    memcpy(&d, &v, 8);
    lua_pushnumber(L, d);
    return 1;
  }
  case T_STR:
    if (!get_u64(r, &n) || n > (uint64_t)(r->end - r->p)) return 0;
    lua_pushlstring(L, (const char *)r->p, (size_t)n);
    r->p += n;
    return 1;
  case T_TAB:
    if (!get_u64(r, &n) || n > (uint64_t)(r->end - r->p)) return 0;
    if (!lua_checkstack(L, 4)) return 0;
    lua_createtable(L, 0, (int)(n < 1024 ? n : 1024));
    for (i = 0; i < n; i++) {
      if (!read_value(L, r, depth + 1)) return 0;
      if (lua_isnil(L, -1) || !read_value(L, r, depth + 1)) return 0;
      lua_rawset(L, -3);
    }
    return 1;
  default: return 0;
  }
}

int sx_ser_read(lua_State *L, const unsigned char *data, size_t len, char *err, size_t errlen) {
  reader r;
  int top = lua_gettop(L);
  if (!data || len < 4 || memcmp(data, MAGIC, 4) != 0) {
    snprintf(err, errlen, "bad magic");
    return 0;
  }
  r.p = data + 4;
  r.end = data + len;
  if (!read_value(L, &r, 0) || r.p != r.end) {
    lua_settop(L, top);
    snprintf(err, errlen, "corrupt data");
    return 0;
  }
  return 1;
}

uint64_t sx_ser_hash(lua_State *L, int idx) {
  sx_buf b = {0};
  char err[128];
  uint64_t h = 0;
  if (sx_ser_write(L, idx, &b, err, sizeof err)) h = sx_hash64(b.data, b.len);
  sx_buf_free(&b);
  return h;
}
