/* SPDX-License-Identifier: MIT */
#include "sx_vfs.h"
#include <stdlib.h>
#include <string.h>

void sx_vfs_init(sx_vfs *v) { memset(v, 0, sizeof *v); }

void sx_vfs_free(sx_vfs *v) {
  int i;
  for (i = 0; i < v->count; i++) {
    free(v->mounts[i].root);
    free(v->mounts[i].id);
  }
  v->count = 0;
}

int sx_vfs_mount(sx_vfs *v, const char *root, const char *id) {
  if (v->count >= SX_VFS_MAX_MOUNTS || !sx_fs_is_dir(root)) return 0;
  v->mounts[v->count].root = sx_strdup(root);
  v->mounts[v->count].id = sx_strdup(id ? id : "");
  v->count++;
  return 1;
}

int sx_vfs_path_ok(const char *path) {
  const char *p = path;
  if (!path || !*path || path[0] == '/' || strchr(path, '\\') || strchr(path, ':')) return 0;
  while (*p) {
    const char *e = strchr(p, '/');
    size_t n = e ? (size_t)(e - p) : strlen(p);
    if (n == 0 || (n == 2 && p[0] == '.' && p[1] == '.')) return 0;
    if (!e) break;
    p = e + 1;
  }
  return 1;
}

char *sx_vfs_resolve(const sx_vfs *v, const char *path, int *mount_index) {
  int i;
  if (!sx_vfs_path_ok(path)) return NULL;
  for (i = v->count - 1; i >= 0; i--) {
    char *full = sx_path_join(v->mounts[i].root, path);
    if (sx_fs_is_file(full)) {
      if (mount_index) *mount_index = i;
      return full;
    }
    free(full);
  }
  return NULL;
}

char *sx_vfs_read(const sx_vfs *v, const char *path, size_t *len) {
  char *full = sx_vfs_resolve(v, path, NULL);
  char *data;
  if (!full) return NULL;
  data = sx_fs_read(full, len);
  free(full);
  return data;
}

int sx_vfs_list(const sx_vfs *v, const char *dir, sx_strlist *out) {
  int i, j, any = 0;
  if (!(dir[0] == 0 || sx_vfs_path_ok(dir))) return 0;
  for (i = 0; i < v->count; i++) {
    sx_strlist files = {0};
    char *full = dir[0] ? sx_path_join(v->mounts[i].root, dir) : sx_strdup(v->mounts[i].root);
    if (sx_fs_list(full, 0, &files)) any = 1;
    for (j = 0; j < files.count; j++) {
      char *rel = dir[0] ? sx_path_join(dir, files.items[j]) : sx_strdup(files.items[j]);
      if (!sx_strlist_contains(out, rel)) sx_strlist_push(out, rel);
      free(rel);
    }
    sx_strlist_free(&files);
    free(full);
  }
  sx_strlist_sort(out);
  return any;
}
