/* SPDX-License-Identifier: MIT */
#include "sx_fs.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <direct.h>
#include <windows.h>
#else
#include <dirent.h>
#include <unistd.h>
#endif

char *sx_strdup(const char *s) {
  size_t n = strlen(s);
  char *d = (char *)malloc(n + 1);
  memcpy(d, s, n + 1);
  return d;
}

void sx_strlist_push(sx_strlist *l, const char *s) {
  if (l->count == l->cap) {
    l->cap = l->cap ? l->cap * 2 : 8;
    l->items = (char **)realloc(l->items, sizeof(char *) * (size_t)l->cap);
  }
  l->items[l->count++] = sx_strdup(s);
}

static int cmp_str(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }

void sx_strlist_sort(sx_strlist *l) {
  if (l->count > 1) qsort(l->items, (size_t)l->count, sizeof(char *), cmp_str);
}

int sx_strlist_contains(const sx_strlist *l, const char *s) {
  int i;
  for (i = 0; i < l->count; i++)
    if (strcmp(l->items[i], s) == 0) return 1;
  return 0;
}

void sx_strlist_free(sx_strlist *l) {
  int i;
  for (i = 0; i < l->count; i++) free(l->items[i]);
  free(l->items);
  l->items = NULL;
  l->count = l->cap = 0;
}

char *sx_fs_read(const char *path, size_t *out_len) {
  FILE *f = fopen(path, "rb");
  char *buf;
  long n;
  size_t got;
  if (!f) return NULL;
  if (fseek(f, 0, SEEK_END) != 0 || (n = ftell(f)) < 0) {
    fclose(f);
    return NULL;
  }
  fseek(f, 0, SEEK_SET);
  buf = (char *)malloc((size_t)n + 1);
  got = fread(buf, 1, (size_t)n, f);
  fclose(f);
  buf[got] = 0;
  if (out_len) *out_len = got;
  return buf;
}

int sx_fs_write_atomic(const char *path, const void *data, size_t len) {
  size_t n = strlen(path);
  char *tmp = (char *)malloc(n + 5);
  FILE *f;
  int ok;
  memcpy(tmp, path, n);
  memcpy(tmp + n, ".tmp", 5);
  f = fopen(tmp, "wb");
  if (!f) {
    free(tmp);
    return 0;
  }
  ok = fwrite(data, 1, len, f) == len;
  ok = (fclose(f) == 0) && ok;
  if (ok) {
#ifdef _WIN32
    ok = MoveFileExA(tmp, path, MOVEFILE_REPLACE_EXISTING) != 0;
#else
    ok = rename(tmp, path) == 0;
#endif
  }
  if (!ok) remove(tmp);
  free(tmp);
  return ok;
}

int sx_fs_is_dir(const char *path) {
  struct stat st;
  return stat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR;
}

int sx_fs_is_file(const char *path) {
  struct stat st;
  return stat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFREG;
}

int sx_fs_mkdirs(const char *path) {
  char *p = sx_strdup(path);
  size_t i, n = strlen(p);
  for (i = 1; i <= n; i++) {
    if (p[i] == '/' || p[i] == 0) {
      char c = p[i];
      p[i] = 0;
      if (!sx_fs_is_dir(p)) {
#ifdef _WIN32
        _mkdir(p);
#else
        mkdir(p, 0755);
#endif
      }
      p[i] = c;
    }
  }
  free(p);
  return sx_fs_is_dir(path);
}

int sx_fs_list(const char *dir, int dirs_only, sx_strlist *out) {
#ifdef _WIN32
  WIN32_FIND_DATAA fd;
  char *pat = sx_path_join(dir, "*");
  HANDLE h = FindFirstFileA(pat, &fd);
  free(pat);
  if (h == INVALID_HANDLE_VALUE) return 0;
  do {
    int isdir = (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    if (strcmp(fd.cFileName, ".") == 0 || strcmp(fd.cFileName, "..") == 0) continue;
    if (dirs_only == 1 && !isdir) continue;
    if (dirs_only == 0 && isdir) continue;
    sx_strlist_push(out, fd.cFileName);
  } while (FindNextFileA(h, &fd));
  FindClose(h);
#else
  DIR *d = opendir(dir);
  struct dirent *e;
  if (!d) return 0;
  while ((e = readdir(d)) != NULL) {
    char *full;
    int isdir;
    if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
    full = sx_path_join(dir, e->d_name);
    isdir = sx_fs_is_dir(full);
    free(full);
    if (dirs_only == 1 && !isdir) continue;
    if (dirs_only == 0 && isdir) continue;
    sx_strlist_push(out, e->d_name);
  }
  closedir(d);
#endif
  sx_strlist_sort(out);
  return 1;
}

char *sx_path_join(const char *a, const char *b) {
  size_t na = strlen(a), nb = strlen(b);
  char *r = (char *)malloc(na + nb + 2);
  memcpy(r, a, na);
  if (na && a[na - 1] != '/') r[na++] = '/';
  memcpy(r + na, b, nb + 1);
  return r;
}

char *sx_path_dir(const char *path) {
  const char *s = strrchr(path, '/');
  char *r;
  if (!s) return sx_strdup(".");
  r = (char *)malloc((size_t)(s - path) + 1);
  memcpy(r, path, (size_t)(s - path));
  r[s - path] = 0;
  return r;
}
