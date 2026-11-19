/* SPDX-License-Identifier: MIT */
#include "sx_replay.h"
#include <stdlib.h>
#include <string.h>
#include "sx_fs.h"
#include "sx_ser.h"

void sx_replay_init(sx_replay *r, const char *version, uint64_t seed, uint64_t modset_hash, int players) {
  memset(r, 0, sizeof *r);
  strncpy(r->version, version ? version : "", sizeof r->version - 1);
  r->seed = seed;
  r->modset_hash = modset_hash;
  r->players = players;
}

void sx_replay_free(sx_replay *r) {
  free(r->frames);
  free(r->hashes);
  memset(r, 0, sizeof *r);
}

static int frame_zero(const sx_cmd *c) {
  int i;
  if (c->buttons || c->edges) return 0;
  for (i = 0; i < SX_NUM_AXES; i++)
    if (c->axes[i]) return 0;
  for (i = 0; i < 3; i++)
    if (c->aim[i]) return 0;
  return 1;
}

void sx_replay_add_frame(sx_replay *r, const sx_cmd *c) {
  if (c->tick + 1 > r->end_tick) r->end_tick = c->tick + 1;
  if (frame_zero(c)) return;
  if (r->nframes == r->cap_frames) {
    r->cap_frames = r->cap_frames ? r->cap_frames * 2 : 256;
    r->frames = (sx_replay_frame *)realloc(r->frames, sizeof(sx_replay_frame) * (size_t)r->cap_frames);
  }
  r->frames[r->nframes++].cmd = *c;
}

void sx_replay_add_hash(sx_replay *r, int64_t tick, uint64_t hash) {
  if (r->nhashes == r->cap_hashes) {
    r->cap_hashes = r->cap_hashes ? r->cap_hashes * 2 : 64;
    r->hashes = (sx_replay_hash *)realloc(r->hashes, sizeof(sx_replay_hash) * (size_t)r->cap_hashes);
  }
  r->hashes[r->nhashes].tick = tick;
  r->hashes[r->nhashes].hash = hash;
  r->nhashes++;
}

int sx_replay_save(const sx_replay *r, const char *path) {
  sx_buf b = {0};
  char line[256];
  int i, k, n, fi = 0, hi = 0, ok;
  n = snprintf(line, sizeof line, "SREP 1\nengine %s\nseed %llu\nmods %016llx\nplayers %d\n", r->version,
               (unsigned long long)r->seed, (unsigned long long)r->modset_hash, r->players);
  sx_buf_put(&b, line, (size_t)n);
  if (r->slots > r->players) {
    n = snprintf(line, sizeof line, "slots %d\n", r->slots);
    sx_buf_put(&b, line, (size_t)n);
  }
  /* interleave frames and hashes in tick order */
  while (fi < r->nframes || hi < r->nhashes) {
    if (hi >= r->nhashes || (fi < r->nframes && r->frames[fi].cmd.tick <= r->hashes[hi].tick)) {
      const sx_cmd *c = &r->frames[fi++].cmd;
      n = snprintf(line, sizeof line, "t %lld %d %x %x", (long long)c->tick, c->player, c->buttons, c->edges);
      for (k = 0; k < SX_NUM_AXES; k++) n += snprintf(line + n, sizeof line - (size_t)n, " %d", c->axes[k]);
      for (k = 0; k < 3; k++) n += snprintf(line + n, sizeof line - (size_t)n, " %d", c->aim[k]);
      line[n++] = '\n';
    } else {
      n = snprintf(line, sizeof line, "h %lld %016llx\n", (long long)r->hashes[hi].tick,
                   (unsigned long long)r->hashes[hi].hash);
      hi++;
    }
    sx_buf_put(&b, line, (size_t)n);
  }
  n = snprintf(line, sizeof line, "end %lld\n", (long long)r->end_tick);
  sx_buf_put(&b, line, (size_t)n);
  ok = sx_fs_write_atomic(path, b.data, b.len);
  sx_buf_free(&b);
  (void)i;
  return ok;
}

int sx_replay_parse(sx_replay *r, const char *text, char *err, int errlen) {
  const char *p = text;
  int lineno = 0, have_magic = 0;
  sx_replay_init(r, "", 0, 0, 1);
  while (*p) {
    char line[256];
    const char *e = strchr(p, '\n');
    size_t n = e ? (size_t)(e - p) : strlen(p);
    lineno++;
    if (n >= sizeof line) n = sizeof line - 1;
    memcpy(line, p, n);
    line[n] = 0;
    p = e ? e + 1 : p + strlen(p);
    if (n && line[n - 1] == '\r') line[n - 1] = 0; /* tolerate CRLF checkouts */
    if (!line[0] || line[0] == '#') continue;
    if (!have_magic) {
      if (strcmp(line, "SREP 1") != 0) {
        snprintf(err, (size_t)errlen, "not a replay (line %d)", lineno);
        return 0;
      }
      have_magic = 1;
    } else if (strncmp(line, "engine ", 7) == 0) {
      snprintf(r->version, sizeof r->version, "%.31s", line + 7);
    } else if (strncmp(line, "seed ", 5) == 0) {
      r->seed = strtoull(line + 5, NULL, 10);
    } else if (strncmp(line, "mods ", 5) == 0) {
      r->modset_hash = strtoull(line + 5, NULL, 16);
    } else if (strncmp(line, "players ", 8) == 0) {
      r->players = atoi(line + 8);
    } else if (strncmp(line, "slots ", 6) == 0) {
      r->slots = atoi(line + 6);
    } else if (line[0] == 't' && line[1] == ' ') {
      sx_cmd c;
      long long tick;
      int player, a[11], k, got, nax;
      unsigned b, ed;
      memset(&c, 0, sizeof c);
      /* touch-look-speed: 8 axes since the touch look angles; files from
       * before carry 6 (the two new ones are 0 there) */
      got = sscanf(line + 2, "%lld %d %x %x %d %d %d %d %d %d %d %d %d %d %d", &tick, &player, &b, &ed, &a[0], &a[1],
                   &a[2], &a[3], &a[4], &a[5], &a[6], &a[7], &a[8], &a[9], &a[10]);
      nax = got == 4 + SX_NUM_AXES + 3 ? SX_NUM_AXES : got == 13 ? 6 : -1;
      if (nax < 0) {
        snprintf(err, (size_t)errlen, "bad frame on line %d", lineno);
        return 0;
      }
      c.tick = tick;
      c.player = player;
      c.buttons = b;
      c.edges = ed;
      for (k = 0; k < nax; k++) c.axes[k] = (int16_t)a[k];
      for (k = 0; k < 3; k++) c.aim[k] = (int16_t)a[nax + k];
      sx_replay_add_frame(r, &c);
    } else if (line[0] == 'h' && line[1] == ' ') {
      long long tick;
      unsigned long long h;
      if (sscanf(line + 2, "%lld %llx", &tick, &h) != 2) {
        snprintf(err, (size_t)errlen, "bad hash on line %d", lineno);
        return 0;
      }
      sx_replay_add_hash(r, tick, h);
    } else if (strncmp(line, "end ", 4) == 0) {
      r->end_tick = atoll(line + 4);
    } else {
      snprintf(err, (size_t)errlen, "unknown record on line %d", lineno);
      return 0;
    }
  }
  if (!have_magic) {
    snprintf(err, (size_t)errlen, "empty replay");
    return 0;
  }
  return 1;
}

int sx_replay_load(sx_replay *r, const char *path, char *err, int errlen) {
  size_t len;
  char *text = sx_fs_read(path, &len);
  int ok;
  if (!text) {
    snprintf(err, (size_t)errlen, "cannot read %s", path);
    sx_replay_init(r, "", 0, 0, 1);
    return 0;
  }
  ok = sx_replay_parse(r, text, err, errlen);
  free(text);
  return ok;
}

void sx_replay_frames_for(sx_replay *r, int64_t tick, sx_cmd *out, int n) {
  int i;
  for (i = 0; i < n; i++) {
    memset(&out[i], 0, sizeof out[i]);
    out[i].player = i + 1;
    out[i].tick = tick;
  }
  while (r->cursor < r->nframes && r->frames[r->cursor].cmd.tick < tick) r->cursor++;
  while (r->cursor < r->nframes && r->frames[r->cursor].cmd.tick == tick) {
    const sx_cmd *c = &r->frames[r->cursor].cmd;
    if (c->player >= 1 && c->player <= n) out[c->player - 1] = *c;
    r->cursor++;
  }
}

int sx_replay_check_hash(sx_replay *r, int64_t tick, uint64_t hash, uint64_t *expected) {
  while (r->hash_cursor < r->nhashes && r->hashes[r->hash_cursor].tick < tick) r->hash_cursor++;
  if (r->hash_cursor < r->nhashes && r->hashes[r->hash_cursor].tick == tick) {
    uint64_t want = r->hashes[r->hash_cursor].hash;
    if (expected) *expected = want;
    return want == hash;
  }
  return 1;
}
