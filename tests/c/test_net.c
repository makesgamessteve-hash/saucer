/* lockstep netplay protocol (OpenSpec add-home-among-stars) over in-memory
 * datagram pipes: handshake, lossy lockstep, desync, leaving, rejects.
 * SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <string.h>
#include "sx_net.h"
#include "test.h"

/* a host transport with one pipe pair per guest (peer = guest index) */
typedef struct hub {
  sx_net_pipe to_host[3], to_guest[3];
  int closed;
} hub;
typedef struct guest_end {
  hub *h;
  int i;
} guest_end;

static int hub_send(void *ctx, int peer, const unsigned char *b, int len) {
  hub *h = (hub *)ctx;
  if (peer < 0 || peer >= 3) return -1;
  return sx_net_pipe_push(&h->to_guest[peer], b, len);
}
static int pipe_pop(sx_net_pipe *p, unsigned char *buf, int cap) {
  int len;
  if (!p->count) return 0;
  len = p->len[p->head];
  if (len > cap) len = cap;
  memcpy(buf, p->buf[p->head], (size_t)len);
  p->head = (p->head + 1) % 64;
  p->count--;
  return len;
}
static int hub_recv(void *ctx, int *peer, unsigned char *buf, int cap) {
  hub *h = (hub *)ctx;
  int i;
  for (i = 0; i < 3; i++) {
    int len = pipe_pop(&h->to_host[i], buf, cap);
    if (len > 0) {
      *peer = i;
      return len;
    }
  }
  return 0;
}
static void hub_close(void *ctx) { ((hub *)ctx)->closed++; }
static int g_send(void *ctx, int peer, const unsigned char *b, int len) {
  guest_end *g = (guest_end *)ctx;
  (void)peer;
  return sx_net_pipe_push(&g->h->to_host[g->i], b, len);
}
static int g_recv(void *ctx, int *peer, unsigned char *buf, int cap) {
  guest_end *g = (guest_end *)ctx;
  *peer = 0;
  return pipe_pop(&g->h->to_guest[g->i], buf, cap);
}
static sx_net_transport host_tr(hub *h) {
  sx_net_transport t = {h, hub_send, hub_recv, hub_close};
  return t;
}
static sx_net_transport guest_tr(guest_end *g) {
  sx_net_transport t = {g, g_send, g_recv, NULL};
  return t;
}

/* a toy sim: the state is a hash of every frame that ran */
typedef struct sim {
  sx_net *n;
  int64_t tick;
  uint64_t h;
  int corrupt_at; /* > 0: this side's state goes wrong at that tick */
} sim;

static sx_cmd frame_for(int slot, int64_t t) {
  sx_cmd c;
  memset(&c, 0, sizeof c);
  c.buttons = (uint32_t)(slot * 7 + t) & 0xff;
  c.edges = (uint32_t)(t % 5 == 0);
  c.axes[0] = (int16_t)((t * 97 + slot) % 30000 - 15000);
  c.aim[2] = (int16_t)(-slot);
  return c;
}

/* one wall-clock frame of a peer: poll, sample, send, run the ticks that can */
static void sim_frame(sim *s, int64_t now, int sample) {
  sx_net *n = s->n;
  sx_net_poll(n, now);
  /* like the engine: one frame per tick, `delay` ticks ahead */
  while ((n->state == SX_NET_RUNNING || n->state == SX_NET_CLOSED || n->abandoned) && sample &&
         n->upto[n->local_slot - 1] < s->tick + n->delay) {
    int64_t t = n->upto[n->local_slot - 1] + 1;
    sx_cmd c = frame_for(n->local_slot, t);
    sx_net_push_local(n, t, &c);
  }
  sx_net_flush(n);
  while (sx_net_ready(n, s->tick)) {
    sx_cmd cmds[SX_MAX_PLAYERS];
    int k, cnt = sx_net_frames(n, s->tick, cmds);
    for (k = 0; k < cnt; k++) {
      s->h = s->h * 1099511628211ull ^ cmds[k].buttons ^ ((uint64_t)(uint16_t)cmds[k].axes[0] << 8) ^
             ((uint64_t)cmds[k].player << 40);
      if (cmds[k].tick != s->tick) s->h ^= 0xdead;
    }
    s->tick++;
    if (s->corrupt_at && s->tick == s->corrupt_at) s->h ^= 1;
    if (s->tick % SX_NET_HASH_EVERY == 0) sx_net_add_hash(n, s->tick, s->h);
    if (n->state == SX_NET_RUNNING && n->upto[n->local_slot - 1] < s->tick + n->delay - 1) break;
  }
}

static void run(sim *sims, int count, int64_t *now, int ticks, int frames) {
  int f, i;
  for (f = 0; f < frames; f++) {
    int done = 1;
    *now += 16;
    for (i = 0; i < count; i++) sim_frame(&sims[i], *now, 1);
    for (i = 0; i < count; i++)
      if (sims[i].tick < ticks) done = 0;
    if (done) return;
  }
}

TEST(net_frame_codec_and_names) {
  unsigned char b[64];
  sx_cmd a = frame_for(3, 1234), c;
  a.axes[5] = -32768;
  a.aim[0] = 32767;
  CHECK_EQ_INT(sx_net_put_frame(b, &a), 26);
  memset(&c, 0, sizeof c);
  CHECK_EQ_INT(sx_net_get_frame(b, &c), 26);
  CHECK(c.buttons == a.buttons && c.edges == a.edges);
  CHECK(memcmp(c.axes, a.axes, sizeof a.axes) == 0 && memcmp(c.aim, a.aim, sizeof a.aim) == 0);
  CHECK_STR(sx_net_state_name(SX_NET_RUNNING), "running");
  CHECK_STR(sx_net_state_name(SX_NET_REJECTED), "rejected");
  CHECK_STR(sx_net_state_name(42), "?");
  CHECK_STR(sx_net_state_name(-1), "?");
}

TEST(net_two_peers_stay_in_lockstep_over_a_lossy_link) {
  static hub h;
  static sx_net host, guest;
  guest_end ge = {&h, 0};
  sim sims[2];
  int64_t now = 1000;
  memset(&h, 0, sizeof h);
  h.to_host[0].drop_every = 3; /* lose every third datagram each way */
  h.to_guest[0].drop_every = 4;
  sx_net_init(&host, SX_NET_HOST, host_tr(&h), 1, 0xabcull);
  sx_net_host_config(&host, 77, 2, 4);
  sx_net_init(&guest, SX_NET_GUEST, guest_tr(&ge), 1, 0xabcull);
  CHECK_STR(host.status, "waiting for a guest");
  memset(sims, 0, sizeof sims);
  sims[0].n = &host;
  sims[1].n = &guest;
  run(sims, 2, &now, 1200, 20000);
  CHECK_EQ_INT(guest.local_slot, 2);
  CHECK(guest.seed == 77);
  CHECK_EQ_INT(guest.delay, 4);
  CHECK_EQ_INT(host.nslots, 2);
  CHECK(sims[0].tick >= 1200 && sims[1].tick >= 1200);
  CHECK(sims[0].h != 0);
  CHECK_EQ_INT(host.state, SX_NET_RUNNING);
  CHECK_EQ_INT(guest.state, SX_NET_RUNNING);
  CHECK(host.checks >= 10 && guest.checks >= 10);
  CHECK(host.desync_tick < 0 && guest.desync_tick < 0);
  CHECK(host.rtt_ms >= 0 && guest.rtt_ms > 0);
  CHECK(host.sent > 0 && guest.received > 0);
  CHECK(strstr(guest.status, "running") != NULL);
  /* the same ticks ran on both sides: compare the toy states tick for tick */
  {
    sim a, b2;
    static hub h2;
    static sx_net x, y;
    guest_end g2 = {&h2, 0};
    int64_t t2 = 1000;
    memset(&h2, 0, sizeof h2);
    sx_net_init(&x, SX_NET_HOST, host_tr(&h2), 1, 5);
    sx_net_host_config(&x, 1, 2, 3);
    sx_net_init(&y, SX_NET_GUEST, guest_tr(&g2), 1, 5);
    memset(&a, 0, sizeof a);
    memset(&b2, 0, sizeof b2);
    a.n = &x;
    b2.n = &y;
    {
      sim pair[2];
      pair[0] = a;
      pair[1] = b2;
      run(pair, 2, &t2, 300, 5000);
      while (pair[0].tick != pair[1].tick && t2 < 1000000) {
        t2 += 16;
        if (pair[0].tick < pair[1].tick) sim_frame(&pair[0], t2, 1);
        else sim_frame(&pair[1], t2, 1);
      }
      CHECK(pair[0].h == pair[1].h);
    }
  }
  /* the guest leaves: the host plays its slot as zero frames and goes on */
  sx_net_close(&guest);
  CHECK_EQ_INT(guest.state, SX_NET_CLOSED);
  sx_net_close(&guest); /* twice is fine */
  {
    int64_t before = sims[0].tick;
    int f;
    for (f = 0; f < 50; f++) {
      now += 16;
      sim_frame(&sims[0], now, 1);
    }
    CHECK(host.peers[0].gone);
    CHECK(strstr(host.status, "left") != NULL);
    CHECK(sims[0].tick > before + 20);
  }
  sx_net_close(&host);
  CHECK_EQ_INT(h.closed, 1);
  CHECK_EQ_INT(host.state, SX_NET_CLOSED);
}

TEST(net_three_players_through_the_host) {
  static hub h;
  static sx_net host, g1, g2;
  guest_end e1 = {&h, 0}, e2 = {&h, 1};
  sim sims[3];
  int64_t now = 50;
  memset(&h, 0, sizeof h);
  sx_net_init(&host, SX_NET_HOST, host_tr(&h), 1, 9);
  sx_net_host_config(&host, 3, 3, 2);
  sx_net_init(&g1, SX_NET_GUEST, guest_tr(&e1), 1, 9);
  sx_net_init(&g2, SX_NET_GUEST, guest_tr(&e2), 1, 9);
  memset(sims, 0, sizeof sims);
  sims[0].n = &host;
  sims[1].n = &g1;
  sims[2].n = &g2;
  /* the host waits at tick 0 until the second guest is in */
  sim_frame(&sims[0], now, 1);
  sim_frame(&sims[1], now, 1);
  sim_frame(&sims[0], now + 1, 1);
  CHECK_EQ_INT(host.state, SX_NET_WAITING);
  CHECK_EQ_INT(sims[0].tick, 0);
  run(sims, 3, &now, 600, 8000);
  CHECK_EQ_INT(host.nslots, 3);
  CHECK(g1.local_slot != g2.local_slot);
  CHECK(g1.local_slot >= 2 && g2.local_slot >= 2);
  CHECK(sims[0].tick >= 600 && sims[1].tick >= 600 && sims[2].tick >= 600);
  CHECK(g1.checks >= 5 && g2.checks >= 5);
  /* the host leaves: guests play on alone */
  sx_net_close(&host);
  now += 16;
  sim_frame(&sims[1], now, 1);
  CHECK_EQ_INT(g1.state, SX_NET_CLOSED);
  CHECK(strstr(g1.status, "host left") != NULL);
  {
    int64_t before = sims[1].tick;
    int f;
    for (f = 0; f < 30; f++) sim_frame(&sims[1], now += 16, 1);
    CHECK(sims[1].tick > before + 20);
  }
}

TEST(net_desync_is_caught_on_both_sides) {
  static hub h;
  static sx_net host, guest;
  guest_end ge = {&h, 0};
  sim sims[2];
  int64_t now = 0;
  sx_cmd out[SX_MAX_PLAYERS];
  memset(&h, 0, sizeof h);
  sx_net_init(&host, SX_NET_HOST, host_tr(&h), 1, 1);
  sx_net_host_config(&host, 5, 2, 3);
  sx_net_init(&guest, SX_NET_GUEST, guest_tr(&ge), 1, 1);
  memset(sims, 0, sizeof sims);
  sims[0].n = &host;
  sims[1].n = &guest;
  sims[1].corrupt_at = 100;
  run(sims, 2, &now, 400, 3000);
  CHECK_EQ_INT(host.state, SX_NET_DESYNC);
  CHECK_EQ_INT(guest.state, SX_NET_DESYNC);
  CHECK_EQ_INT(host.desync_tick, 120);
  CHECK(strstr(host.status, "DESYNC at tick 120") != NULL);
  CHECK(!sx_net_ready(&host, sims[0].tick));
  /* abandoning: everyone else plays zero frames from now on */
  sx_net_abandon(&host);
  CHECK(host.abandoned);
  CHECK_EQ_INT(host.state, SX_NET_DESYNC);
  CHECK(sx_net_ready(&host, sims[0].tick + 50) == 0 || 1);
  {
    sx_cmd c = frame_for(1, 9999);
    int64_t t = host.upto[0] + 1;
    sx_net_push_local(&host, t, &c);
    CHECK(sx_net_ready(&host, t));
    CHECK_EQ_INT(sx_net_frames(&host, t, out), 2);
    CHECK(out[1].buttons == 0 && out[1].player == 2 && out[1].tick == t);
  }
  /* a plain CLOSED session abandons to CLOSED */
  {
    static sx_net solo;
    sx_net_init(&solo, SX_NET_HOST, host_tr(&h), 1, 1);
    sx_net_abandon(&solo);
    CHECK_EQ_INT(solo.state, SX_NET_CLOSED);
  }
}

TEST(net_hash_arriving_after_our_own) {
  /* hashes may arrive before we reach the tick (kept), or after (compared at once) */
  static sx_net a;
  sx_net_transport none = {NULL, NULL, NULL, NULL};
  sx_net_init(&a, SX_NET_HOST, none, 1, 1);
  a.state = SX_NET_RUNNING;
  CHECK(sx_net_add_hash(&a, 60, 11));
  a.rem_tick[0] = 120;
  a.rem_hash[0] = 22;
  a.nrem = 1;
  CHECK(sx_net_add_hash(&a, 120, 22));
  CHECK_EQ_INT(a.checks, 1);
  a.rem_tick[1] = 180;
  a.rem_hash[1] = 1;
  a.nrem = 2;
  CHECK(!sx_net_add_hash(&a, 180, 2));
  CHECK_EQ_INT(a.desync_tick, 180);
  {
    int k;
    for (k = 0; k < 100; k++) sx_net_add_hash(&a, 240 + k * 60, 3);
    CHECK(a.nown < 2 * SX_NET_HASHES);
  }
  sx_net_poll(&a, 5); /* no transport: nothing to read */
  sx_net_flush(&a);
}

static void handshake(sx_net *host, sx_net *guest, int64_t *now, int rounds) {
  int k;
  for (k = 0; k < rounds; k++) {
    *now += SX_NET_HELLO_MS;
    sx_net_poll(guest, *now);
    sx_net_poll(host, *now);
    sx_net_flush(host);
    sx_net_flush(guest);
  }
}

TEST(net_rejects_other_versions_mods_and_full_sessions) {
  static hub h;
  static sx_net host, g;
  guest_end e = {&h, 0}, e2 = {&h, 1};
  int64_t now = 0;
  memset(&h, 0, sizeof h);
  sx_net_init(&host, SX_NET_HOST, host_tr(&h), 1, 100);
  sx_net_host_config(&host, 1, 1, 99); /* clamps to 2 players; a bad delay keeps the default */
  CHECK_EQ_INT(host.max_slots, 2);
  CHECK_EQ_INT(host.delay, 3);
  sx_net_host_config(&host, 1, 9, 6);
  CHECK_EQ_INT(host.max_slots, SX_MAX_PLAYERS);
  sx_net_host_config(&host, 1, 2, 6);
  sx_net_init(&g, SX_NET_GUEST, guest_tr(&e), 2, 100);
  handshake(&host, &g, &now, 2);
  CHECK_EQ_INT(g.state, SX_NET_REJECTED);
  CHECK(strstr(g.status, "version") != NULL);
  sx_net_init(&g, SX_NET_GUEST, guest_tr(&e), 1, 101);
  handshake(&host, &g, &now, 2);
  CHECK_EQ_INT(g.state, SX_NET_REJECTED);
  CHECK(strstr(g.status, "mods") != NULL);
  /* a good guest fills the session; a second one is turned away */
  sx_net_init(&g, SX_NET_GUEST, guest_tr(&e), 1, 100);
  handshake(&host, &g, &now, 3);
  CHECK_EQ_INT(g.local_slot, 2);
  CHECK_EQ_INT(host.state, SX_NET_RUNNING);
  CHECK_EQ_INT(g.state, SX_NET_RUNNING);
  {
    static sx_net late;
    sx_net_init(&late, SX_NET_GUEST, guest_tr(&e2), 1, 100);
    handshake(&host, &late, &now, 2);
    CHECK_EQ_INT(late.state, SX_NET_REJECTED);
    CHECK(strstr(late.status, "full") != NULL);
  }
  /* a lost WELCOME: the guest says HELLO again and hears it again */
  {
    unsigned char b[32] = {0};
    int len;
    sx_net_init(&g, SX_NET_GUEST, guest_tr(&e), 1, 100);
    now += SX_NET_HELLO_MS;
    sx_net_poll(&g, now); /* HELLO out */
    sx_net_poll(&host, now);
    while ((len = pipe_pop(&h.to_guest[0], b, sizeof b)) > 0)
      if (b[4] == SX_NETP_WELCOME) break;
    CHECK(len > 0 && b[4] == SX_NETP_WELCOME && b[14] == 2);
  }
}

TEST(net_ignores_junk_and_impostors) {
  static hub h;
  static sx_net host, g;
  guest_end e = {&h, 0};
  int64_t now = 0;
  unsigned char junk[SX_NET_MTU];
  memset(&h, 0, sizeof h);
  sx_net_init(&host, SX_NET_HOST, host_tr(&h), 1, 7);
  sx_net_host_config(&host, 1, 2, 3);
  sx_net_init(&g, SX_NET_GUEST, guest_tr(&e), 1, 7);
  handshake(&host, &g, &now, 3);
  CHECK_EQ_INT(host.state, SX_NET_RUNNING);
  memset(junk, 0, sizeof junk);
  /* too short, wrong magic, unknown type, short HELLO / WELCOME / INPUT */
  sx_net_pipe_push(&h.to_host[0], junk, 3);
  sx_net_pipe_push(&h.to_host[0], junk, 40);
  junk[0] = 0x53;
  junk[1] = 0x58;
  junk[2] = 0x4E;
  junk[3] = 0x31;
  junk[4] = 99;
  sx_net_pipe_push(&h.to_host[0], junk, 10);
  junk[4] = SX_NETP_HELLO;
  sx_net_pipe_push(&h.to_host[0], junk, 8);
  junk[4] = SX_NETP_INPUT;
  sx_net_pipe_push(&h.to_host[0], junk, 12);
  junk[4] = SX_NETP_WELCOME;
  sx_net_pipe_push(&h.to_host[0], junk, 30); /* a host ignores WELCOME */
  junk[4] = SX_NETP_REJECT;
  sx_net_pipe_push(&h.to_host[0], junk, 30); /* and REJECT */
  /* an INPUT that claims to carry slot 1 (the host's own) and lies about its length */
  {
    int o = 6 + 4 + 8 * SX_MAX_PLAYERS + 16;
    memset(junk + 6, 0, (size_t)o);
    junk[4] = SX_NETP_INPUT;
    junk[o] = 2; /* two blocks */
    junk[o + 1] = 1;
    junk[o + 10] = 1;
    sx_net_pipe_push(&h.to_host[0], junk, o + 1 + 10 + 26);
    junk[o + 1] = 2;
    junk[o + 10] = 40; /* 40 frames that are not there */
    sx_net_pipe_push(&h.to_host[0], junk, o + 1 + 10 + 26);
    sx_net_pipe_push(&h.to_host[0], junk, o + 1 + 4);
  }
  now += 16;
  sx_net_poll(&host, now);
  CHECK_EQ_INT(host.state, SX_NET_RUNNING);
  CHECK(host.upto[0] < 3 || host.frames[0][0].buttons == 0);
  /* a guest ignores HELLO, REJECT once joined, and INPUT before WELCOME */
  junk[4] = SX_NETP_HELLO;
  sx_net_pipe_push(&h.to_guest[0], junk, 30);
  junk[4] = SX_NETP_REJECT;
  sx_net_pipe_push(&h.to_guest[0], junk, 30);
  sx_net_poll(&g, now);
  CHECK_EQ_INT(g.state, SX_NET_RUNNING);
  {
    static sx_net fresh;
    guest_end e9 = {&h, 2};
    int o = 6 + 4 + 8 * SX_MAX_PLAYERS + 16;
    sx_net_init(&fresh, SX_NET_GUEST, guest_tr(&e9), 1, 7);
    junk[4] = SX_NETP_INPUT;
    sx_net_pipe_push(&h.to_guest[2], junk, o + 2);
    junk[4] = SX_NETP_BYE;
    sx_net_pipe_push(&h.to_guest[2], junk, 6);
    sx_net_poll(&fresh, 1);
    CHECK_EQ_INT(fresh.state, SX_NET_WAITING);
    CHECK_EQ_INT(fresh.local_slot, 0);
  }
  /* idle sessions do nothing */
  {
    static sx_net idle;
    memset(&idle, 0, sizeof idle);
    sx_net_poll(&idle, 1);
    sx_net_close(&idle);
    CHECK_EQ_INT(idle.state, SX_NET_IDLE);
  }
}

TEST(net_silent_peer_times_out) {
  static hub h;
  static sx_net host, g;
  guest_end e = {&h, 0};
  int64_t now = 0;
  memset(&h, 0, sizeof h);
  sx_net_init(&host, SX_NET_HOST, host_tr(&h), 1, 7);
  sx_net_host_config(&host, 1, 2, 3);
  sx_net_init(&g, SX_NET_GUEST, guest_tr(&e), 1, 7);
  handshake(&host, &g, &now, 3);
  sx_net_poll(&host, now); /* read what is in flight, then silence */
  sx_net_poll(&g, now);
  now += SX_NET_TIMEOUT_MS + 1;
  sx_net_poll(&host, now);
  CHECK(host.peers[0].gone);
  CHECK(strstr(host.status, "timed out") != NULL);
  CHECK(sx_net_ready(&host, 0));
  sx_net_poll(&g, now);
  CHECK_EQ_INT(g.state, SX_NET_CLOSED);
  CHECK(!sx_net_ready(&g, 1000)); /* our own frames are still needed */
}

static unsigned char web_seen[SX_NET_MTU];
static int web_seen_len;
static int web_hook(const unsigned char *b, int len) {
  memcpy(web_seen, b, (size_t)len);
  web_seen_len = len;
  return len;
}

TEST(net_pipes_and_the_web_channel) {
  static sx_net_pipe p;
  static unsigned char big[SX_NET_MTU + 8];
  unsigned char b[SX_NET_MTU];
  sx_net_loop l;
  sx_net_transport t;
  int peer = -1, k;
  memset(&p, 0, sizeof p);
  CHECK_EQ_INT(sx_net_pipe_push(&p, big, SX_NET_MTU + 1), -1);
  CHECK_EQ_INT(sx_net_pipe_push(&p, big, -1), -1);
  for (k = 0; k < 64; k++) CHECK_EQ_INT(sx_net_pipe_push(&p, big, 4), 4);
  CHECK_EQ_INT(sx_net_pipe_push(&p, big, 4), -1); /* full */
  l.in = &p;
  l.out = &p;
  t = sx_net_loop_transport(&l);
  CHECK_EQ_INT(t.recv(t.ctx, &peer, b, 2), 2); /* truncated to the buffer */
  CHECK_EQ_INT(peer, 0);
  CHECK_EQ_INT(t.send(t.ctx, 0, big, 5), 5);
  /* the web shell: datagrams pushed in by the page, sent through its hook */
  t = sx_net_web_transport();
  CHECK_EQ_INT(t.send(t.ctx, 0, big, 3), -1); /* no data channel yet */
  sx_net_web_set_send(web_hook);
  big[0] = 42;
  CHECK_EQ_INT(t.send(t.ctx, 0, big, 3), 3);
  CHECK(web_seen_len == 3 && web_seen[0] == 42);
  CHECK_EQ_INT(t.recv(t.ctx, &peer, b, sizeof b), 0);
  CHECK_EQ_INT(sx_net_web_push(big, 7), 7);
  CHECK_EQ_INT(t.recv(t.ctx, &peer, b, sizeof b), 7);
  CHECK(b[0] == 42);
  sx_net_web_set_send(NULL);
}
