/* SPDX-License-Identifier: MIT */
#include "sx_procgen.h"
#include <stdlib.h>
#include <string.h>

int sx_grid_init(sx_grid *g, int w, int h, int d) {
  memset(g, 0, sizeof *g);
  if (w <= 0 || h <= 0 || d <= 0 || (long long)w * h * d > 4000000) return 0;
  g->w = w;
  g->h = h;
  g->d = d;
  g->cells = (int *)calloc((size_t)w * (size_t)h * (size_t)d, sizeof(int));
  return 1;
}

void sx_grid_free(sx_grid *g) {
  free(g->cells);
  memset(g, 0, sizeof *g);
}

int sx_grid_get(const sx_grid *g, int x, int y, int z) {
  if (x < 0 || y < 0 || z < 0 || x >= g->w || y >= g->h || z >= g->d) return -1;
  return g->cells[(z * g->h + y) * g->w + x];
}

int sx_grid_free_box(const sx_grid *g, int x, int y, int z, int sx, int sy, int sz) {
  int i, j, k;
  if (sx <= 0 || sy <= 0 || sz <= 0) return 0;
  for (k = z; k < z + sz; k++)
    for (j = y; j < y + sy; j++)
      for (i = x; i < x + sx; i++)
        if (sx_grid_get(g, i, j, k) != 0) return 0;
  return 1;
}

int sx_grid_place(sx_grid *g, int x, int y, int z, int sx, int sy, int sz, int id) {
  int i, j, k;
  if (id == 0 || !sx_grid_free_box(g, x, y, z, sx, sy, sz)) return 0;
  for (k = z; k < z + sz; k++)
    for (j = y; j < y + sy; j++)
      for (i = x; i < x + sx; i++) g->cells[(k * g->h + j) * g->w + i] = id;
  return 1;
}

int sx_reachable(int nnodes, const int *room_class, const sx_edge *edges, int nedges, int start, int start_class,
                 int min_class, int *reach_out) {
  /* BFS over (node, class) states */
  int nstates, *seen, *queue, qh = 0, qt = 0, i, count = 0;
  if (nnodes <= 0 || start < 0 || start >= nnodes) return 0;
  if (start_class < 0) start_class = 0;
  if (start_class > SX_MAX_CLASS) start_class = SX_MAX_CLASS;
  if (min_class < 0) min_class = 0;
  nstates = nnodes * (SX_MAX_CLASS + 1);
  seen = (int *)calloc((size_t)nstates, sizeof(int));
  queue = (int *)malloc(sizeof(int) * (size_t)nstates);
  for (i = 0; i < nnodes; i++) reach_out[i] = -1;
  seen[start * (SX_MAX_CLASS + 1) + start_class] = 1;
  queue[qt++] = start * (SX_MAX_CLASS + 1) + start_class;
  while (qh < qt) {
    int s = queue[qh++];
    int node = s / (SX_MAX_CLASS + 1), cls = s % (SX_MAX_CLASS + 1), e, nxt[2 + 64], nn = 0, k;
    if (reach_out[node] < cls) {
      if (reach_out[node] < 0) count++;
      reach_out[node] = cls;
    }
    if (cls > min_class) nxt[nn++] = node * (SX_MAX_CLASS + 1) + cls - 1; /* shrink */
    if (cls < SX_MAX_CLASS && room_class && room_class[node] >= cls + 1)
      nxt[nn++] = node * (SX_MAX_CLASS + 1) + cls + 1; /* grow */
    for (e = 0; e < nedges; e++) {
      const sx_edge *ed = &edges[e];
      int other = -1;
      if (ed->cls < cls) continue;
      if (ed->a == node) other = ed->b;
      else if (ed->b == node) other = ed->a;
      if (other < 0 || other >= nnodes) continue;
      {
        int st = other * (SX_MAX_CLASS + 1) + cls;
        if (!seen[st]) {
          seen[st] = 1;
          queue[qt++] = st;
        }
      }
    }
    for (k = 0; k < nn; k++) {
      if (!seen[nxt[k]]) {
        seen[nxt[k]] = 1;
        queue[qt++] = nxt[k];
      }
    }
  }
  free(seen);
  free(queue);
  return count;
}
