/* .srep replays: header + per-tick per-player command frames + state hashes
 * every 60 ticks. Text format so diffs are reviewable.
 * SPDX-License-Identifier: MIT */
#ifndef SX_REPLAY_H
#define SX_REPLAY_H
#include <stdint.h>
#include <stdio.h>
#include "sx_input.h"

#define SX_HASH_INTERVAL 60

typedef struct sx_replay_frame {
  sx_cmd cmd;
} sx_replay_frame;

typedef struct sx_replay_hash {
  int64_t tick;
  uint64_t hash;
} sx_replay_hash;

typedef struct sx_replay {
  char version[32];
  uint64_t seed;
  uint64_t modset_hash;
  int players;
  int64_t end_tick;
  sx_replay_frame *frames;
  int nframes, cap_frames;
  sx_replay_hash *hashes;
  int nhashes, cap_hashes;
  int cursor, hash_cursor; /* playback positions */
} sx_replay;

void sx_replay_init(sx_replay *r, const char *version, uint64_t seed, uint64_t modset_hash, int players);
void sx_replay_free(sx_replay *r);
/* Record a frame (all-zero frames are skipped to keep files small). */
void sx_replay_add_frame(sx_replay *r, const sx_cmd *c);
void sx_replay_add_hash(sx_replay *r, int64_t tick, uint64_t hash);
int sx_replay_save(const sx_replay *r, const char *path);
/* Parse text; returns 1 or 0 with err. */
int sx_replay_parse(sx_replay *r, const char *text, char *err, int errlen);
int sx_replay_load(sx_replay *r, const char *path, char *err, int errlen);
/* Fill frames for `tick` (players 1..n, zero frames for gaps). */
void sx_replay_frames_for(sx_replay *r, int64_t tick, sx_cmd *out, int n);
/* Check a computed hash; returns 1 ok / no expectation, 0 mismatch. */
int sx_replay_check_hash(sx_replay *r, int64_t tick, uint64_t hash, uint64_t *expected);
#endif
