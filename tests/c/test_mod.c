/* mod manifests and load order — SPDX-License-Identifier: MIT */
#include <stdio.h>
#include "sx_fs.h"
#include "sx_mod.h"
#include "test.h"

TEST(version_compare) {
  CHECK(sx_version_cmp("1.2.0", "1.10") < 0);
  CHECK(sx_version_cmp("1.2", "1.2.0") == 0);
  CHECK(sx_version_cmp("2", "1.9.9") > 0);
  CHECK(sx_version_cmp("1.0-beta", "1.0") == 0);
  CHECK(sx_version_satisfies("1.0.0", ""));
  CHECK(sx_version_satisfies("1.0.0", "  >=1.0"));
  CHECK(!sx_version_satisfies("1.0.0", ">=1.1"));
  CHECK(sx_version_satisfies("1.0.0", "<=1.0") && !sx_version_satisfies("1.1", "<=1.0"));
  CHECK(sx_version_satisfies("1.1", ">1.0") && !sx_version_satisfies("1.0", ">1.0"));
  CHECK(sx_version_satisfies("0.9", "<1.0") && !sx_version_satisfies("1.0", "<1.0"));
  CHECK(sx_version_satisfies("1.0", "=1.0") && sx_version_satisfies("1.0", "1.0") && !sx_version_satisfies("1.1", "=1.0"));
}

static int parse(const char *src, sx_mod *m) {
  char err[256];
  return sx_mod_parse(src, strlen(src), "r", m, err, sizeof err);
}

TEST(manifest_parse) {
  sx_mod m;
  CHECK(parse("return { id = 'x', api = 1, depends = { 'base >=0.1', 5 }, load_after = { 'y' } }", &m));
  CHECK_STR(m.name, "x");
  CHECK_STR(m.version, "0.0.0");
  CHECK(m.depends.count == 1 && strcmp(m.depends_req.items[0], ">=0.1") == 0);
  CHECK(m.load_after.count == 1);
  sx_mod_free(&m);
  CHECK(!parse("return 5", &m));
  CHECK(strstr(m.status, "table") != NULL);
  sx_mod_free(&m);
  CHECK(!parse("return {}", &m));
  sx_mod_free(&m);
  CHECK(!parse("while true do end", &m));
  CHECK(strstr(m.status, "budget") != NULL);
  sx_mod_free(&m);
  CHECK(!parse("return os.exit()", &m)); /* no libraries */
  sx_mod_free(&m);
  CHECK(!parse("return {", &m));
  sx_mod_free(&m);
  CHECK(parse("return { id = 'q', api = 'one' }", &m) && m.api == -1);
  sx_mod_free(&m);
}

TEST(modset_scan_and_resolve) {
  sx_modset s;
  int i;
  sx_modset_init(&s);
  CHECK(sx_modset_scan(&s, "data/base", "tests/fixtures/mods", NULL));
  CHECK(sx_modset_find(&s, "broken_manifest") < 0);
  sx_modset_resolve(&s, SX_ENGINE_API);
  CHECK(s.order_count >= 3);
  CHECK_STR(s.mods[s.order[0]].id, "base");
  CHECK(!s.mods[sx_modset_find(&s, "bad_api")].ok);
  CHECK(strstr(s.mods[sx_modset_find(&s, "needs_missing")].status, "missing") != NULL);
  CHECK(strstr(s.mods[sx_modset_find(&s, "old_dep")].status, "version") != NULL);
  CHECK(strstr(s.mods[sx_modset_find(&s, "cycle_a")].status, "cycle") != NULL);
  for (i = 0; i < s.order_count; i++)
    if (strcmp(s.mods[s.order[i]].id, "greedy") == 0) CHECK(strcmp(s.mods[s.order[i - 1]].id, "bigger_tractor") == 0);
  /* duplicate directory is ignored */
  CHECK(sx_modset_add_dir(&s, "data/base") < 0);
  CHECK(sx_modset_add_dir(&s, "no/such/dir") < 0);
  sx_modset_free(&s);

  sx_modset_init(&s);
  CHECK(sx_modset_scan(&s, "data/base", "tests/fixtures/mods", "greedy,bigger_tractor"));
  CHECK(s.count == 3);
  sx_modset_free(&s);

  sx_modset_init(&s);
  CHECK(!sx_modset_scan(&s, "no/base", NULL, NULL));
  sx_modset_free(&s);
}

TEST(modset_failed_dependency_propagates) {
  sx_modset s;
  char err[64];
  sx_modset_init(&s);
  sx_mod_parse("return { id='base', api=1 }", 27, "", &s.mods[0], err, sizeof err);
  sx_mod_parse("return { id='a', api=2 }", 24, "", &s.mods[1], err, sizeof err);
  sx_mod_parse("return { id='b', api=1, depends={'a'} }", 39, "", &s.mods[2], err, sizeof err);
  sx_mod_parse("return { id='c', api=1, depends={'b'} }", 39, "", &s.mods[3], err, sizeof err);
  s.count = 4;
  CHECK(sx_modset_resolve(&s, 1) == 1);
  CHECK(strstr(s.mods[3].status, "failed") != NULL);
  sx_modset_free(&s);
  sx_modset_init(&s);
  for (s.count = 0; s.count < SX_MAX_MODS; s.count++) {
    char src[64];
    snprintf(src, sizeof src, "return { id='m%d', api=1 }", s.count);
    sx_mod_parse(src, strlen(src), "", &s.mods[s.count], err, sizeof err);
  }
  CHECK(sx_modset_add_dir(&s, "data/base") < 0); /* table full */
  sx_modset_free(&s);
}
