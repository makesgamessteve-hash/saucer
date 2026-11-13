/* Virtual file system: an ordered stack of mounted folders. A later mount
 * overrides files of an earlier one with the same relative path.
 * SPDX-License-Identifier: MIT */
#ifndef SX_VFS_H
#define SX_VFS_H
#include <stddef.h>
#include "sx_fs.h"

#define SX_VFS_MAX_MOUNTS 64

typedef struct sx_vfs_mnt {
  char *root; /* folder on disk, e.g. "./data/base" */
  char *id;   /* mod id */
} sx_vfs_mnt;

typedef struct sx_vfs {
  sx_vfs_mnt mounts[SX_VFS_MAX_MOUNTS];
  int count;
} sx_vfs;

void sx_vfs_init(sx_vfs *v);
void sx_vfs_free(sx_vfs *v);
int sx_vfs_mount(sx_vfs *v, const char *root, const char *id);
/* 1 if a relative path is safe (no "..", no absolute, no backslash, no empty). */
int sx_vfs_path_ok(const char *path);
/* Returns malloc'd disk path of the winning file or NULL; *mount_index optional. */
char *sx_vfs_resolve(const sx_vfs *v, const char *path, int *mount_index);
char *sx_vfs_read(const sx_vfs *v, const char *path, size_t *len);
/* Union of all files directly in dir across mounts (sorted, unique). */
int sx_vfs_list(const sx_vfs *v, const char *dir, sx_strlist *out);
#endif
