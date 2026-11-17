/* fs, vfs, serializer, replay — SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include "lauxlib.h"
#include "lualib.h"
#include "sx_fs.h"
#include "sx_replay.h"
#include "sx_ser.h"
#include "sx_vfs.h"
#include "test.h"

#define TMP "build/test-tmp"

TEST(fs_paths_and_lists) {
  sx_strlist l = {0};
  char *p, *d;
  size_t n;
  CHECK(sx_fs_mkdirs(TMP "/a/b"));
  CHECK(sx_fs_is_dir(TMP "/a/b") && !sx_fs_is_file(TMP "/a/b"));
  CHECK(sx_fs_write_atomic(TMP "/a/x.txt", "hi", 2));
  CHECK(sx_fs_is_file(TMP "/a/x.txt"));
  p = sx_fs_read(TMP "/a/x.txt", &n);
  CHECK(p && n == 2 && strcmp(p, "hi") == 0);
  free(p);
  CHECK(sx_fs_read(TMP "/nope", &n) == NULL);
  CHECK(sx_fs_list(TMP "/a", 1, &l) && l.count == 1 && strcmp(l.items[0], "b") == 0);
  sx_strlist_free(&l);
  CHECK(sx_fs_list(TMP "/a", 0, &l) && l.count == 1);
  sx_strlist_free(&l);
  CHECK(sx_fs_list(TMP "/a", 2, &l) && l.count == 2);
  CHECK(sx_strlist_contains(&l, "x.txt") && !sx_strlist_contains(&l, "y"));
  sx_strlist_free(&l);
  CHECK(!sx_fs_list(TMP "/missing", 0, &l));
  p = sx_path_join("a/", "b");
  CHECK_STR(p, "a/b");
  free(p);
  p = sx_path_join("", "b");
  CHECK_STR(p, "b");
  free(p);
  d = sx_path_dir("a/b/c.txt");
  CHECK_STR(d, "a/b");
  free(d);
  d = sx_path_dir("c.txt");
  CHECK_STR(d, ".");
  free(d);
  CHECK(!sx_fs_write_atomic(TMP "/no/such/dir/x", "a", 1));
}

TEST(vfs_mount_stack) {
  sx_vfs v;
  sx_strlist l = {0};
  int m = -1;
  char *p;
  size_t n;
  sx_fs_mkdirs(TMP "/m1/sub");
  sx_fs_mkdirs(TMP "/m2/sub");
  sx_fs_write_atomic(TMP "/m1/sub/a.txt", "one", 3);
  sx_fs_write_atomic(TMP "/m2/sub/a.txt", "two", 3);
  sx_fs_write_atomic(TMP "/m2/sub/b.txt", "bee", 3);
  sx_vfs_init(&v);
  CHECK(sx_vfs_mount(&v, TMP "/m1", "m1"));
  CHECK(sx_vfs_mount(&v, TMP "/m2", "m2"));
  p = sx_vfs_read(&v, "sub/a.txt", &n);
  CHECK(p && strcmp(p, "two") == 0); /* later mounts override */
  free(p);
  p = sx_vfs_resolve(&v, "sub/a.txt", &m);
  CHECK(m == 1);
  free(p);
  CHECK(sx_vfs_list(&v, "sub", &l) && l.count == 2);
  sx_strlist_free(&l);
  CHECK(!sx_vfs_path_ok("../x") && !sx_vfs_path_ok("/abs") && !sx_vfs_path_ok("a\\b") && !sx_vfs_path_ok("c:x"));
  CHECK(!sx_vfs_path_ok("a//b") && !sx_vfs_path_ok("") && sx_vfs_path_ok("a/b.txt"));
  CHECK(sx_vfs_read(&v, "../etc", &n) == NULL);
  sx_vfs_free(&v);
}

static lua_State *newL(void) {
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  return L;
}

TEST(ser_roundtrip_canonical) {
  lua_State *L = newL();
  sx_buf a = {0}, b = {0};
  char err[128];
  luaL_dostring(L, "return { z = 1, a = { 1, 2.5, 'x', true, false }, [3] = 'n', [1.5] = 2, [true] = 1, [false] = 0 }");
  CHECK(sx_ser_write(L, -1, &a, err, sizeof err));
  CHECK(sx_ser_read(L, a.data, a.len, err, sizeof err));
  CHECK(sx_ser_write(L, -1, &b, err, sizeof err));
  CHECK(a.len == b.len && memcmp(a.data, b.data, a.len) == 0);
  CHECK(sx_ser_hash(L, -1) == sx_ser_hash(L, -2));
  lua_settop(L, 0);
  /* corrupt inputs */
  CHECK(!sx_ser_read(L, (const unsigned char *)"XXXX", 4, err, sizeof err));
  CHECK(!sx_ser_read(L, a.data, a.len - 1, err, sizeof err));
  {
    unsigned char *t = (unsigned char *)malloc(a.len + 1);
    memcpy(t, a.data, a.len);
    t[a.len] = 0;
    CHECK(!sx_ser_read(L, t, a.len + 1, err, sizeof err)); /* trailing data */
    t[4] = 99;                                             /* bad tag */
    CHECK(!sx_ser_read(L, t, a.len, err, sizeof err));
    free(t);
  }
  CHECK(lua_gettop(L) == 0);
  /* unsupported values and keys, nil, cycles */
  luaL_dostring(L, "return { f = print }");
  CHECK(!sx_ser_write(L, -1, &b, err, sizeof err));
  luaL_dostring(L, "return { [{}] = 1 }");
  CHECK(!sx_ser_write(L, -1, &b, err, sizeof err));
  CHECK(strstr(err, "key") != NULL);
  luaL_dostring(L, "local t = {} t.t = t return t");
  CHECK(!sx_ser_write(L, -1, &b, err, sizeof err));
  CHECK(strstr(err, "deep") != NULL);
  lua_pushnil(L);
  sx_buf_free(&b);
  CHECK(sx_ser_write(L, -1, &b, err, sizeof err));
  CHECK(sx_ser_read(L, b.data, b.len, err, sizeof err) && lua_isnil(L, -1));
  /* ordering: ints vs floats with equal value, strings of different length */
  luaL_dostring(L, "return { [1] = 'a', [2.5] = 'b', ab = 1, a = 2, abc = 3 }");
  CHECK(sx_ser_write(L, -1, &b, err, sizeof err));
  sx_buf_free(&a);
  sx_buf_free(&b);
  lua_close(L);
}

TEST(replay_roundtrip_and_errors) {
  sx_replay r, q;
  sx_cmd c, out[2];
  char err[128];
  uint64_t exp = 0;
  sx_fs_mkdirs(TMP);
  memset(&c, 0, sizeof c);
  sx_replay_init(&r, "0.1.0", 42, 0xabc, 2);
  c.player = 1;
  c.tick = 3;
  c.buttons = 5;
  c.axes[0] = -100;
  sx_replay_add_frame(&r, &c);
  memset(&c, 0, sizeof c);
  c.player = 2;
  c.tick = 3;
  sx_replay_add_frame(&r, &c); /* all-zero: skipped */
  sx_replay_add_hash(&r, 60, 0x1234);
  r.end_tick = 61;
  r.slots = 4; /* add-wider-dark: co-op frame slots */
  CHECK(r.nframes == 1);
  CHECK(sx_replay_save(&r, TMP "/r.srep"));
  CHECK(sx_replay_load(&q, TMP "/r.srep", err, sizeof err));
  CHECK(q.seed == 42 && q.players == 2 && q.end_tick == 61 && q.nframes == 1 && q.nhashes == 1 && q.slots == 4);
  sx_replay_frames_for(&q, 3, out, 2);
  CHECK(out[0].buttons == 5 && out[0].axes[0] == -100 && out[1].buttons == 0);
  CHECK(sx_replay_check_hash(&q, 10, 1, &exp));
  CHECK(!sx_replay_check_hash(&q, 60, 1, &exp) && exp == 0x1234);
  CHECK(sx_replay_check_hash(&q, 60, 0x1234, &exp));
  sx_replay_free(&q);
  CHECK(!sx_replay_load(&q, TMP "/missing.srep", err, sizeof err));
  sx_replay_free(&q);
  CHECK(!sx_replay_parse(&q, "nope\n", err, sizeof err));
  sx_replay_free(&q);
  CHECK(!sx_replay_parse(&q, "SREP 1\nt x\n", err, sizeof err));
  sx_replay_free(&q);
  CHECK(!sx_replay_parse(&q, "SREP 1\nh 1\n", err, sizeof err));
  sx_replay_free(&q);
  CHECK(!sx_replay_parse(&q, "SREP 1\nwhat 1\n", err, sizeof err));
  sx_replay_free(&q);
  CHECK(!sx_replay_parse(&q, "", err, sizeof err));
  sx_replay_free(&q);
  CHECK(sx_replay_parse(&q, "SREP 1\r\nengine 0.1.0\r\nseed 1\r\n# comment\r\n\r\nend 5\r\n", err, sizeof err));
  CHECK(q.end_tick == 5);
  sx_replay_free(&q);
  sx_replay_free(&r);
}
