/* Mod manifests (mod.lua), dependency ordering and API checks.
 * SPDX-License-Identifier: MIT */
#ifndef SX_MOD_H
#define SX_MOD_H
#include <stddef.h>
#include "sx_fs.h"

#define SX_ENGINE_API 1
#define SX_MAX_MODS 64

typedef struct sx_mod {
  char id[64];
  char name[128];
  char version[32];
  char entry[256];
  char license_code[32];
  char license_assets[32];
  char root[512];
  char description[200]; /* add-home-among-stars: shown by the mod browser */
  int api;
  sx_strlist depends;     /* ids */
  sx_strlist depends_req; /* version requirement per dependency (">=0.1" or "") */
  sx_strlist load_after;
  int ok;                 /* 1 = will be mounted */
  char status[256];       /* reason when !ok, "ok" otherwise */
} sx_mod;

typedef struct sx_modset {
  sx_mod mods[SX_MAX_MODS];
  int count;
  int order[SX_MAX_MODS]; /* indices into mods, load order */
  int order_count;
} sx_modset;

/* Compare dotted versions numerically: <0, 0, >0. */
int sx_version_cmp(const char *a, const char *b);
/* Does version satisfy requirement like ">=0.1", "=1.2.0", "<2", "" ? */
int sx_version_satisfies(const char *version, const char *req);
/* Parse manifest source; returns 1 on success, else fills err. */
int sx_mod_parse(const char *src, size_t len, const char *root, sx_mod *out, char *err, size_t errlen);
void sx_mod_free(sx_mod *m);

void sx_modset_init(sx_modset *s);
void sx_modset_free(sx_modset *s);
/* Add a mod folder (reads <dir>/mod.lua). Returns index or -1. */
int sx_modset_add_dir(sx_modset *s, const char *dir);
/* Scan base_dir (data/base) and every folder in mods_dir. enabled_csv: NULL = all. */
int sx_modset_scan(sx_modset *s, const char *base_dir, const char *mods_dir, const char *enabled_csv);
/* Compute load order; mark failures (api, missing deps, cycles). Returns count loaded. */
int sx_modset_resolve(sx_modset *s, int engine_api);
int sx_modset_find(const sx_modset *s, const char *id);
#endif
