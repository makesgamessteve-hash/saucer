/* Procgen helpers: 3D occupancy grid and size-class aware reachability.
 * SPDX-License-Identifier: MIT */
#ifndef SX_PROCGEN_H
#define SX_PROCGEN_H

typedef struct sx_grid {
  int w, h, d;
  int *cells; /* 0 = empty, otherwise owner id */
} sx_grid;

int sx_grid_init(sx_grid *g, int w, int h, int d);
void sx_grid_free(sx_grid *g);
int sx_grid_get(const sx_grid *g, int x, int y, int z); /* -1 outside */
/* 1 if the box [x,x+sx) ... is inside the grid and free */
int sx_grid_free_box(const sx_grid *g, int x, int y, int z, int sx, int sy, int sz);
int sx_grid_place(sx_grid *g, int x, int y, int z, int sx, int sy, int sz, int id);

/* Graph reachability where a traveller of size class c may cross an edge of
 * class >= c, may always shrink, and may grow only inside rooms whose
 * room_class allows it. Classes: 0 F (on foot), 1 S, 2 M, 3 L, 4 XL.
 * reach_out[node] gets the largest class the node was reached with, or -1. */
#define SX_MAX_CLASS 4
typedef struct sx_edge {
  int a, b, cls;
} sx_edge;
int sx_reachable(int nnodes, const int *room_class, const sx_edge *edges, int nedges, int start, int start_class,
                 int min_class, int *reach_out);
#endif
