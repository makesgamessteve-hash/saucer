/* Thin, portable file-system helpers (stdio + dirent / Win32).
 * SPDX-License-Identifier: MIT */
#ifndef SX_FS_H
#define SX_FS_H
#include <stddef.h>

typedef struct sx_strlist {
  char **items;
  int count;
  int cap;
} sx_strlist;

void sx_strlist_push(sx_strlist *l, const char *s);
void sx_strlist_sort(sx_strlist *l);
int sx_strlist_contains(const sx_strlist *l, const char *s);
void sx_strlist_free(sx_strlist *l);

/* Read a whole file; returns malloc'd buffer (NUL-terminated) or NULL. */
char *sx_fs_read(const char *path, size_t *out_len);
/* Write via "<path>.tmp" + rename so readers never see a partial file. */
int sx_fs_write_atomic(const char *path, const void *data, size_t len);
int sx_fs_is_dir(const char *path);
int sx_fs_is_file(const char *path);
int sx_fs_mkdirs(const char *path);
/* Sorted entry names (no "." / ".."). dirs_only: 1 dirs, 0 files, -1 both. */
int sx_fs_list(const char *dir, int dirs_only, sx_strlist *out);
/* Join a and b with '/', result malloc'd. */
char *sx_path_join(const char *a, const char *b);
/* Directory part of a path ("." if none), malloc'd. */
char *sx_path_dir(const char *path);
char *sx_strdup(const char *s);
#endif
