/* Networked co-op (OpenSpec add-home-among-stars): deterministic lockstep
 * with input delay over an unreliable datagram transport (UDP on desktop,
 * a WebRTC data channel on the web), plus desync detection by comparing the
 * sim state hashes every SX_NET_HASH_EVERY ticks.
 *
 * Every peer owns one player slot (the host is slot 1, guests 2..4). A frame
 * sampled at tick t is scheduled for tick t + delay and sent, with every
 * frame the other side has not acknowledged yet, in each INPUT datagram (so
 * a lost datagram is covered by the next one). A tick only runs when every
 * slot's frame for it is here. The host relays guests' frames (star), so
 * guests only talk to the host.
 *
 * The protocol is pure C over a send/recv callback pair, so it runs over
 * real UDP sockets (sx_net_udp.c), the browser's data channel (the web shell
 * pushes datagrams in) and an in-memory loopback pair in the unit tests.
 * SPDX-License-Identifier: MIT */
#ifndef SX_NET_H
#define SX_NET_H
#include <stdint.h>
#include "sx_input.h"

#define SX_NET_API 1 /* bump when the protocol or the sim command layout changes */
#define SX_NET_MAGIC 0x314E5853u /* "SXN1" */
#define SX_NET_WINDOW 256          /* ticks of frames kept per slot (ring) */
#define SX_NET_MAX_SEND 48         /* frames per slot per datagram */
#define SX_NET_HASH_EVERY 60
#define SX_NET_HASHES 32           /* hash ring per side */
#define SX_NET_MTU 1400
#define SX_NET_TIMEOUT_MS 8000     /* silence before a peer counts as gone */
#define SX_NET_HELLO_MS 150        /* handshake resend */
#define SX_NET_PEERS (SX_MAX_PLAYERS - 1)

enum { SX_NET_OFF = 0, SX_NET_HOST, SX_NET_GUEST };
enum {
  SX_NET_IDLE = 0,  /* not started */
  SX_NET_WAITING,   /* host: listening; guest: saying HELLO */
  SX_NET_RUNNING,   /* lockstep */
  SX_NET_CLOSED,    /* the session ended (bye or timeout): play goes on solo */
  SX_NET_DESYNC,    /* state hashes differ: the session stops */
  SX_NET_REJECTED   /* guest: the host refused (version, mods or full) */
};
enum { SX_NETP_HELLO = 1, SX_NETP_WELCOME = 2, SX_NETP_REJECT = 3, SX_NETP_INPUT = 4, SX_NETP_BYE = 5 };

/* a datagram transport: send to peer `peer` (host: 0..PEERS-1, guest: 0 = host);
 * recv returns the length (0 = nothing waiting, <0 error) and the peer it came
 * from (a host transport hands out a new peer index for a new address) */
typedef struct sx_net_transport {
  void *ctx;
  int (*send)(void *ctx, int peer, const unsigned char *buf, int len);
  int (*recv)(void *ctx, int *peer, unsigned char *buf, int cap);
  void (*close)(void *ctx);
} sx_net_transport;

typedef struct sx_net_peer {
  int used;
  int slot;                    /* the peer's own slot (host: 2..4; a guest's peer 0 is the host, slot 1) */
  int64_t ack[SX_MAX_PLAYERS]; /* highest contiguous tick the peer holds, per slot */
  int64_t last_recv_ms;
  int64_t echo_ms;             /* the peer's clock from its last datagram (for RTT) */
  int gone;
} sx_net_peer;

typedef struct sx_net {
  int role, state;
  int local_slot, nslots;  /* nslots: slots in the session (host + guests) */
  int max_slots;           /* host: how many may join (2-4) */
  int delay;               /* input delay in ticks */
  int64_t start_tick;      /* first tick the session's frames cover */
  uint64_t seed, modset_hash;
  uint32_t api, nonce;
  sx_net_transport tr;
  sx_net_peer peers[SX_NET_PEERS];
  /* frames: ring per slot, have[] marks which ticks are here */
  sx_cmd frames[SX_MAX_PLAYERS][SX_NET_WINDOW];
  int64_t have_tick[SX_MAX_PLAYERS][SX_NET_WINDOW];
  int64_t upto[SX_MAX_PLAYERS];  /* highest contiguous tick held per slot */
  int64_t gone_from[SX_MAX_PLAYERS]; /* a slot whose peer left plays zero frames from here */
  /* hashes */
  int64_t own_tick[SX_NET_HASHES];
  uint64_t own_hash[SX_NET_HASHES];
  int64_t rem_tick[SX_NET_HASHES];
  uint64_t rem_hash[SX_NET_HASHES];
  int nown, nrem;
  int64_t desync_tick;
  int abandoned;           /* a desync ended the session: zero frames for the others */
  int64_t checks;          /* ticks whose hashes were compared and equal */
  int64_t checked_tick;
  int64_t now_ms, last_hello_ms, last_send_ms, last_recv_ms;
  int64_t sent, received, stalls;
  int64_t rtt_ms;
  char status[160];
} sx_net;

void sx_net_init(sx_net *n, int role, sx_net_transport tr, uint32_t api, uint64_t modset_hash);
/* host: seed and how many slots may join; guest: seed is learnt from WELCOME */
void sx_net_host_config(sx_net *n, uint64_t seed, int max_slots, int delay);
/* Read every waiting datagram and answer handshakes; now_ms is wall time. */
void sx_net_poll(sx_net *n, int64_t now_ms);
/* Schedule the local frame for `tick` (normally current tick + delay). */
void sx_net_push_local(sx_net *n, int64_t tick, const sx_cmd *cmd);
/* Send pending frames and hashes (call once per frame/tick). */
void sx_net_flush(sx_net *n);
/* 1 when every slot's frame for `tick` is here (or its peer is gone). */
int sx_net_ready(const sx_net *n, int64_t tick);
/* Fill the frames for `tick` (n = nslots, player = slot). */
int sx_net_frames(const sx_net *n, int64_t tick, sx_cmd *out);
/* Record our own state hash after a tick; returns 0 on a desync. */
int sx_net_add_hash(sx_net *n, int64_t tick, uint64_t hash);
/* Say goodbye (a few times: datagrams get lost) and close the transport. */
void sx_net_close(sx_net *n);
/* "running", "waiting", ... */
const char *sx_net_state_name(int state);

/* frame codec (exposed for tests) */
int sx_net_put_frame(unsigned char *p, const sx_cmd *c);
int sx_net_get_frame(const unsigned char *p, sx_cmd *c);

/* An in-memory datagram pair (tests, the web shell's queue): what one side
 * sends the other receives; drop_every > 0 loses every n-th datagram. */
typedef struct sx_net_pipe {
  unsigned char buf[64][SX_NET_MTU];
  int len[64];
  int head, count;
  int sent, drop_every;
} sx_net_pipe;
typedef struct sx_net_loop {
  sx_net_pipe *in, *out;
} sx_net_loop;
sx_net_transport sx_net_loop_transport(sx_net_loop *l);
int sx_net_pipe_push(sx_net_pipe *p, const unsigned char *buf, int len);

/* The web shell's data channel: the page pushes received datagrams in and
 * the platform layer installs the function that sends (one peer). */
void sx_net_web_set_send(int (*fn)(const unsigned char *buf, int len));
int sx_net_web_push(const unsigned char *buf, int len);
sx_net_transport sx_net_web_transport(void);
/* end a session after a desync: everyone else plays zero frames from now */
void sx_net_abandon(sx_net *n);

/* UDP (sx_net_udp.c; not on the web) */
sx_net_transport sx_net_udp_host(int port, char *err, int errlen);
sx_net_transport sx_net_udp_join(const char *host, int port, char *err, int errlen);
int64_t sx_net_clock_ms(void);
void sx_net_sleep_ms(int ms);
#endif
