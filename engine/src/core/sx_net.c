/* SPDX-License-Identifier: MIT */
#include "sx_net.h"
#include <stdio.h>
#include <string.h>

/* ---------- little-endian codec ---------- */
static void put32(unsigned char *p, uint32_t v) {
  p[0] = (unsigned char)v;
  p[1] = (unsigned char)(v >> 8);
  p[2] = (unsigned char)(v >> 16);
  p[3] = (unsigned char)(v >> 24);
}
static uint32_t get32(const unsigned char *p) {
  return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static void put64(unsigned char *p, uint64_t v) {
  put32(p, (uint32_t)v);
  put32(p + 4, (uint32_t)(v >> 32));
}
static uint64_t get64(const unsigned char *p) { return (uint64_t)get32(p) | ((uint64_t)get32(p + 4) << 32); }
static void put16(unsigned char *p, int16_t v) {
  p[0] = (unsigned char)((uint16_t)v);
  p[1] = (unsigned char)((uint16_t)v >> 8);
}
static int16_t get16(const unsigned char *p) { return (int16_t)(uint16_t)(p[0] | (p[1] << 8)); }

#define FRAME_BYTES (8 + 2 * SX_NUM_AXES + 6)

int sx_net_put_frame(unsigned char *p, const sx_cmd *c) {
  int k, o = 8;
  put32(p, c->buttons);
  put32(p + 4, c->edges);
  for (k = 0; k < SX_NUM_AXES; k++, o += 2) put16(p + o, c->axes[k]);
  for (k = 0; k < 3; k++, o += 2) put16(p + o, c->aim[k]);
  return o;
}

int sx_net_get_frame(const unsigned char *p, sx_cmd *c) {
  int k, o = 8;
  c->buttons = get32(p);
  c->edges = get32(p + 4);
  for (k = 0; k < SX_NUM_AXES; k++, o += 2) c->axes[k] = get16(p + o);
  for (k = 0; k < 3; k++, o += 2) c->aim[k] = get16(p + o);
  return o;
}

const char *sx_net_state_name(int state) {
  static const char *names[] = {"idle", "waiting", "running", "closed", "desync", "rejected"};
  return state >= 0 && state <= SX_NET_REJECTED ? names[state] : "?";
}

static void status(sx_net *n, const char *text) { snprintf(n->status, sizeof n->status, "%s", text); }

void sx_net_init(sx_net *n, int role, sx_net_transport tr, uint32_t api, uint64_t modset_hash) {
  int s, i;
  memset(n, 0, sizeof *n);
  n->role = role;
  n->tr = tr;
  n->api = api;
  n->modset_hash = modset_hash;
  n->state = SX_NET_WAITING;
  n->local_slot = role == SX_NET_HOST ? 1 : 0;
  n->nslots = 1;
  n->max_slots = 2;
  n->delay = 3;
  n->desync_tick = -1;
  n->checked_tick = -1;
  n->nonce = (uint32_t)(modset_hash ^ (modset_hash >> 32)) * 2654435761u + 1u;
  for (s = 0; s < SX_MAX_PLAYERS; s++) {
    n->upto[s] = -1;
    n->gone_from[s] = -1;
    for (i = 0; i < SX_NET_WINDOW; i++) n->have_tick[s][i] = -1;
  }
  n->last_hello_ms = -100000;
  status(n, role == SX_NET_HOST ? "waiting for a guest" : "joining");
}

void sx_net_host_config(sx_net *n, uint64_t seed, int max_slots, int delay) {
  n->seed = seed;
  n->max_slots = max_slots < 2 ? 2 : max_slots > SX_MAX_PLAYERS ? SX_MAX_PLAYERS : max_slots;
  if (delay >= 1 && delay <= 12) n->delay = delay;
}

static int64_t clamp_ack(int64_t v) { return v < -1 ? -1 : v; }

/* store a frame; advance the slot's contiguous mark */
static void store(sx_net *n, int slot, int64_t tick, const sx_cmd *c) {
  int s = slot - 1, i;
  if (s < 0 || s >= SX_MAX_PLAYERS || tick < 0 || tick <= n->upto[s]) return;
  if (tick > n->upto[s] + SX_NET_WINDOW) return; /* too far ahead to hold */
  i = (int)(tick % SX_NET_WINDOW);
  n->frames[s][i] = *c;
  n->frames[s][i].player = slot;
  n->frames[s][i].tick = tick;
  n->have_tick[s][i] = tick;
  while (n->have_tick[s][(n->upto[s] + 1) % SX_NET_WINDOW] == n->upto[s] + 1) n->upto[s]++;
}

/* the first `delay` ticks of a session have no input from anyone */
static void start_session(sx_net *n) {
  int s;
  int64_t t;
  sx_cmd zero;
  memset(&zero, 0, sizeof zero);
  n->state = SX_NET_RUNNING;
  for (s = 1; s <= n->nslots; s++)
    for (t = n->start_tick; t < n->start_tick + n->delay; t++) store(n, s, t, &zero);
  {
    char b[96];
    snprintf(b, sizeof b, "running: %d players, slot %d, delay %d", n->nslots, n->local_slot, n->delay);
    status(n, b);
  }
}

static void send_to(sx_net *n, int peer, const unsigned char *buf, int len) {
  if (n->tr.send && n->tr.send(n->tr.ctx, peer, buf, len) == len) n->sent++;
}

static int header(unsigned char *b, int type, const sx_net *n) {
  put32(b, SX_NET_MAGIC);
  b[4] = (unsigned char)type;
  b[5] = (unsigned char)n->local_slot;
  return 6;
}

static void send_hello(sx_net *n) {
  unsigned char b[32];
  int o = header(b, SX_NETP_HELLO, n);
  put32(b + o, n->api);
  put64(b + o + 4, n->modset_hash);
  put32(b + o + 12, n->nonce);
  send_to(n, 0, b, o + 16);
  n->last_hello_ms = n->now_ms;
}

static void send_simple(sx_net *n, int peer, int type, int a, int b2) {
  unsigned char b[48];
  int o = header(b, type, n);
  put64(b + o, n->seed);
  b[o + 8] = (unsigned char)a;
  b[o + 9] = (unsigned char)b2;
  b[o + 10] = (unsigned char)n->delay;
  b[o + 11] = (unsigned char)n->max_slots;
  send_to(n, peer, b, o + 12);
}

static void peer_gone(sx_net *n, int pi, const char *why) {
  sx_net_peer *pe = &n->peers[pi];
  char b[96];
  if (pe->gone) return;
  pe->gone = 1;
  if (n->role == SX_NET_HOST) {
    int s = pe->slot - 1;
    /* the host plays the leaver's slot as zero frames and relays those */
    if (s >= 0) n->gone_from[s] = n->upto[s] + 1;
    snprintf(b, sizeof b, "player %d left (%s)", pe->slot, why);
  } else {
    int s;
    for (s = 0; s < SX_MAX_PLAYERS; s++)
      if (s != n->local_slot - 1) n->gone_from[s] = n->upto[s] + 1;
    snprintf(b, sizeof b, "the host left (%s): playing on alone", why);
    if (n->state == SX_NET_RUNNING || n->state == SX_NET_WAITING) n->state = SX_NET_CLOSED;
  }
  status(n, b);
}

/* host: a HELLO from a new address */
static void on_hello(sx_net *n, int peer, const unsigned char *b, int len) {
  sx_net_peer *pe;
  if (n->role != SX_NET_HOST || len < 22 || peer < 0 || peer >= SX_NET_PEERS) return;
  pe = &n->peers[peer];
  if (pe->used) { /* our WELCOME was lost: say it again */
    send_simple(n, peer, SX_NETP_WELCOME, pe->slot, n->nslots);
    return;
  }
  if (get32(b + 6) != n->api) {
    send_simple(n, peer, SX_NETP_REJECT, 1, 0);
    return;
  }
  if (get64(b + 10) != n->modset_hash) {
    send_simple(n, peer, SX_NETP_REJECT, 2, 0);
    return;
  }
  if (n->state != SX_NET_WAITING || n->nslots >= n->max_slots) {
    send_simple(n, peer, SX_NETP_REJECT, 3, 0);
    return;
  }
  memset(pe, 0, sizeof *pe);
  pe->used = 1;
  pe->slot = ++n->nslots;
  pe->last_recv_ms = n->now_ms;
  {
    int s;
    for (s = 0; s < SX_MAX_PLAYERS; s++) pe->ack[s] = -1;
  }
  send_simple(n, peer, SX_NETP_WELCOME, pe->slot, n->nslots);
  if (n->nslots >= n->max_slots) start_session(n);
}

static void on_welcome(sx_net *n, const unsigned char *b, int len) {
  int s;
  if (n->role != SX_NET_GUEST || len < 18 || n->local_slot) return;
  n->seed = get64(b + 6);
  n->local_slot = b[14];
  n->delay = b[16];
  n->max_slots = b[17];
  n->nslots = n->max_slots;
  n->peers[0].used = 1;
  n->peers[0].slot = 1;
  n->peers[0].last_recv_ms = n->now_ms;
  for (s = 0; s < SX_MAX_PLAYERS; s++) n->peers[0].ack[s] = -1;
  status(n, "joined: waiting for the host to start");
}

static void on_input(sx_net *n, int peer, const unsigned char *b, int len) {
  sx_net_peer *pe;
  int o = 6, s, nb, k, nh;
  if (len < 6 + 4 + 8 * SX_MAX_PLAYERS + 16 + 2) return;
  if (n->role == SX_NET_GUEST) {
    if (!n->local_slot) return;
    peer = 0;
    if (n->state == SX_NET_WAITING) {
      n->nslots = b[o];
      start_session(n);
    }
  }
  if (peer < 0 || peer >= SX_NET_PEERS || !n->peers[peer].used) return;
  pe = &n->peers[peer];
  o += 4; /* nslots, delay, 2 spare */
  for (s = 0; s < SX_MAX_PLAYERS; s++, o += 8) {
    int64_t a = clamp_ack((int64_t)get64(b + o));
    if (a > pe->ack[s]) pe->ack[s] = a;
  }
  pe->echo_ms = (int64_t)get64(b + o);
  {
    int64_t echoed = (int64_t)get64(b + o + 8);
    if (echoed > 0 && n->now_ms >= echoed) n->rtt_ms = n->now_ms - echoed;
  }
  o += 16;
  nb = b[o++];
  for (k = 0; k < nb; k++) {
    int slot, cnt, j;
    int64_t first;
    if (o + 10 > len) return;
    slot = b[o];
    first = (int64_t)get64(b + o + 1);
    cnt = b[o + 9];
    o += 10;
    if (o + cnt * FRAME_BYTES > len) return;
    for (j = 0; j < cnt; j++) {
      sx_cmd c;
      memset(&c, 0, sizeof c);
      o += sx_net_get_frame(b + o, &c);
      /* a guest may only speak for its own slot */
      if (n->role == SX_NET_HOST && slot != pe->slot) continue;
      if (slot == n->local_slot) continue;
      store(n, slot, first + j, &c);
    }
  }
  if (o >= len) return;
  nh = b[o++];
  for (k = 0; k < nh && o + 16 <= len; k++, o += 16) {
    int64_t t = (int64_t)get64(b + o);
    uint64_t h = get64(b + o + 8);
    int i, matched = 0;
    for (i = 0; i < n->nown && i < SX_NET_HASHES; i++) {
      if (n->own_tick[i] == t) {
        matched = 1;
        if (n->own_hash[i] != h) {
          if (n->state != SX_NET_DESYNC) {
            char m[96];
            n->state = SX_NET_DESYNC;
            n->desync_tick = t;
            snprintf(m, sizeof m, "DESYNC at tick %lld with player %d", (long long)t, pe->slot);
            status(n, m);
          }
        } else if (t > n->checked_tick) {
          n->checks++;
          n->checked_tick = t;
        }
        break;
      }
    }
    if (!matched) {
      /* keep it until we get there ourselves (ring) */
      int at = (int)(n->nrem % SX_NET_HASHES);
      n->rem_tick[at] = t;
      n->rem_hash[at] = h;
      n->nrem++;
    }
  }
}

void sx_net_poll(sx_net *n, int64_t now_ms) {
  unsigned char b[SX_NET_MTU + 64];
  int i, guard;
  n->now_ms = now_ms;
  if (n->state == SX_NET_IDLE || !n->tr.recv) return;
  if (n->role == SX_NET_GUEST && !n->local_slot && n->state == SX_NET_WAITING &&
      now_ms - n->last_hello_ms >= SX_NET_HELLO_MS)
    send_hello(n);
  for (guard = 0; guard < 4096; guard++) {
    int peer = 0, len = n->tr.recv(n->tr.ctx, &peer, b, (int)sizeof b);
    if (len <= 0) break;
    if (len < 6 || get32(b) != SX_NET_MAGIC) continue;
    n->received++;
    n->last_recv_ms = now_ms;
    if (n->role == SX_NET_GUEST) peer = 0;
    if (peer >= 0 && peer < SX_NET_PEERS && n->peers[peer].used) n->peers[peer].last_recv_ms = now_ms;
    switch (b[4]) {
      case SX_NETP_HELLO: on_hello(n, peer, b, len); break;
      case SX_NETP_WELCOME: on_welcome(n, b, len); break;
      case SX_NETP_REJECT:
        if (n->role == SX_NET_GUEST && !n->local_slot && len >= 15) {
          n->state = SX_NET_REJECTED;
          status(n, b[14] == 1 ? "rejected: a different game version"
                    : b[14] == 2 ? "rejected: a different set of mods"
                                 : "rejected: the session is full or already running");
        }
        break;
      case SX_NETP_INPUT:
        if (n->state == SX_NET_RUNNING || n->state == SX_NET_WAITING) on_input(n, peer, b, len);
        break;
      case SX_NETP_BYE:
        if (peer >= 0 && peer < SX_NET_PEERS && n->peers[peer].used) peer_gone(n, peer, "said goodbye");
        break;
      default: break;
    }
  }
  /* silence */
  if (n->state == SX_NET_RUNNING)
    for (i = 0; i < SX_NET_PEERS; i++)
      if (n->peers[i].used && !n->peers[i].gone && now_ms - n->peers[i].last_recv_ms > SX_NET_TIMEOUT_MS)
        peer_gone(n, i, "timed out");
}

void sx_net_push_local(sx_net *n, int64_t tick, const sx_cmd *cmd) {
  if (n->local_slot) store(n, n->local_slot, tick, cmd);
}

static void send_input(sx_net *n, int pi) {
  unsigned char b[SX_NET_MTU];
  sx_net_peer *pe = &n->peers[pi];
  int o = header(b, SX_NETP_INPUT, n), s, nbo, nb = 0, k, budget;
  b[o] = (unsigned char)n->nslots;
  b[o + 1] = (unsigned char)n->delay;
  b[o + 2] = b[o + 3] = 0;
  o += 4;
  for (s = 0; s < SX_MAX_PLAYERS; s++, o += 8) put64(b + o, (uint64_t)n->upto[s]);
  put64(b + o, (uint64_t)n->now_ms);
  put64(b + o + 8, (uint64_t)pe->echo_ms);
  o += 16;
  nbo = o++;
  budget = SX_NET_MTU - o - 1 - 4 * 16;
  for (s = 1; s <= n->nslots; s++) {
    int64_t from = pe->ack[s - 1] + 1, to = n->upto[s - 1], t;
    int cnt;
    if (s == pe->slot || to < from) continue;
    if (to - from + 1 > SX_NET_MAX_SEND) to = from + SX_NET_MAX_SEND - 1;
    cnt = (int)(to - from + 1);
    if (10 + cnt * FRAME_BYTES > budget) cnt = (budget - 10) / FRAME_BYTES;
    if (cnt <= 0) break;
    b[o] = (unsigned char)s;
    put64(b + o + 1, (uint64_t)from);
    b[o + 9] = (unsigned char)cnt;
    o += 10;
    for (t = from; t < from + cnt; t++) o += sx_net_put_frame(b + o, &n->frames[s - 1][t % SX_NET_WINDOW]);
    budget -= 10 + cnt * FRAME_BYTES;
    nb++;
  }
  b[nbo] = (unsigned char)nb;
  /* our newest hashes */
  {
    int nh = n->nown < 4 ? n->nown : 4;
    b[o++] = (unsigned char)nh;
    for (k = n->nown - nh; k < n->nown; k++, o += 16) {
      int at = k % SX_NET_HASHES;
      put64(b + o, (uint64_t)n->own_tick[at]);
      put64(b + o + 8, n->own_hash[at]);
    }
  }
  send_to(n, pi, b, o);
}

void sx_net_flush(sx_net *n) {
  int i;
  /* after a desync we still send (our hashes let the others see it too)
   * until the session is abandoned */
  if (n->state != SX_NET_RUNNING && !(n->state == SX_NET_DESYNC && !n->abandoned)) return;
  for (i = 0; i < SX_NET_PEERS; i++)
    if (n->peers[i].used && !n->peers[i].gone) send_input(n, i);
  n->last_send_ms = n->now_ms;
}

static int slot_ready(const sx_net *n, int s, int64_t tick) {
  if (n->upto[s] >= tick) return 1;
  return n->gone_from[s] >= 0 && tick >= n->gone_from[s];
}

int sx_net_ready(const sx_net *n, int64_t tick) {
  int s;
  if (n->state != SX_NET_RUNNING && n->state != SX_NET_CLOSED && n->state != SX_NET_DESYNC) return 0;
  if (n->state == SX_NET_DESYNC && !n->abandoned) return 0;
  for (s = 0; s < n->nslots; s++)
    if (!slot_ready(n, s, tick)) return 0;
  return 1;
}

int sx_net_frames(const sx_net *n, int64_t tick, sx_cmd *out) {
  int s;
  for (s = 0; s < n->nslots; s++) {
    if (n->upto[s] >= tick && n->have_tick[s][tick % SX_NET_WINDOW] == tick) {
      out[s] = n->frames[s][tick % SX_NET_WINDOW];
    } else {
      memset(&out[s], 0, sizeof out[s]);
    }
    out[s].player = s + 1;
    out[s].tick = tick;
  }
  return n->nslots;
}

int sx_net_add_hash(sx_net *n, int64_t tick, uint64_t hash) {
  int at = n->nown % SX_NET_HASHES, i;
  n->own_tick[at] = tick;
  n->own_hash[at] = hash;
  n->nown++;
  if (n->nown >= 2 * SX_NET_HASHES) n->nown -= SX_NET_HASHES; /* keep the ring index small */
  for (i = 0; i < SX_NET_HASHES && i < n->nrem; i++) {
    if (n->rem_tick[i] != tick) continue;
    n->rem_tick[i] = -1;
    if (n->rem_hash[i] != hash) {
      if (n->state != SX_NET_DESYNC) {
        char m[96];
        n->state = SX_NET_DESYNC;
        n->desync_tick = tick;
        snprintf(m, sizeof m, "DESYNC at tick %lld", (long long)tick);
        status(n, m);
      }
    } else if (tick > n->checked_tick) {
      n->checks++;
      n->checked_tick = tick;
    }
  }
  return n->state != SX_NET_DESYNC;
}

void sx_net_close(sx_net *n) {
  int i, k;
  if (n->state == SX_NET_IDLE) return;
  /* frames still in flight first, then goodbye (datagrams get lost) */
  for (k = 0; k < 4; k++) {
    if (n->state == SX_NET_RUNNING) sx_net_flush(n);
    for (i = 0; i < SX_NET_PEERS; i++) {
      if (n->peers[i].used && !n->peers[i].gone) {
        unsigned char b[8];
        int o = header(b, SX_NETP_BYE, n);
        send_to(n, i, b, o);
      }
    }
  }
  if (n->tr.close) n->tr.close(n->tr.ctx);
  n->tr.send = NULL;
  n->tr.recv = NULL;
  n->tr.close = NULL;
  if (n->state == SX_NET_RUNNING || n->state == SX_NET_WAITING) n->state = SX_NET_CLOSED;
}

/* ---------- in-memory datagram pair ---------- */
int sx_net_pipe_push(sx_net_pipe *p, const unsigned char *buf, int len) {
  int at;
  p->sent++;
  if (p->drop_every > 0 && p->sent % p->drop_every == 0) return len; /* lost on the way */
  if (p->count >= 64 || len > SX_NET_MTU || len < 0) return -1;
  at = (p->head + p->count) % 64;
  memcpy(p->buf[at], buf, (size_t)len);
  p->len[at] = len;
  p->count++;
  return len;
}

static int loop_send(void *ctx, int peer, const unsigned char *buf, int len) {
  (void)peer;
  return sx_net_pipe_push(((sx_net_loop *)ctx)->out, buf, len);
}

static int loop_recv(void *ctx, int *peer, unsigned char *buf, int cap) {
  sx_net_pipe *p = ((sx_net_loop *)ctx)->in;
  int len;
  if (!p->count) return 0;
  len = p->len[p->head];
  if (len > cap) len = cap;
  memcpy(buf, p->buf[p->head], (size_t)len);
  p->head = (p->head + 1) % 64;
  p->count--;
  *peer = 0;
  return len;
}

sx_net_transport sx_net_loop_transport(sx_net_loop *l) {
  sx_net_transport t;
  t.ctx = l;
  t.send = loop_send;
  t.recv = loop_recv;
  t.close = NULL;
  return t;
}

/* ---------- the web shell's data channel ---------- */
static sx_net_pipe web_in;
static int (*web_send)(const unsigned char *buf, int len);

void sx_net_web_set_send(int (*fn)(const unsigned char *buf, int len)) { web_send = fn; }
int sx_net_web_push(const unsigned char *buf, int len) { return sx_net_pipe_push(&web_in, buf, len); }

static int web_tr_send(void *ctx, int peer, const unsigned char *buf, int len) {
  (void)ctx;
  (void)peer;
  return web_send ? web_send(buf, len) : -1;
}

static int web_tr_recv(void *ctx, int *peer, unsigned char *buf, int cap) {
  sx_net_loop l;
  l.in = &web_in;
  l.out = NULL;
  (void)ctx;
  return loop_recv(&l, peer, buf, cap);
}

sx_net_transport sx_net_web_transport(void) {
  sx_net_transport t;
  t.ctx = NULL;
  t.send = web_tr_send;
  t.recv = web_tr_recv;
  t.close = NULL;
  return t;
}

void sx_net_abandon(sx_net *n) {
  int s;
  for (s = 0; s < SX_MAX_PLAYERS; s++)
    if (s != n->local_slot - 1 && n->gone_from[s] < 0) n->gone_from[s] = n->upto[s] + 1;
  n->abandoned = 1;
  if (n->state != SX_NET_DESYNC) n->state = SX_NET_CLOSED;
}
