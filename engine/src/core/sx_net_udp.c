/* UDP datagrams for networked co-op (desktop). The host binds a port and
 * hands each new sender address a peer index; a guest talks to one address.
 * The web build has no UDP: it uses a WebRTC data channel (web/saucer_net.js)
 * through the same sx_net protocol.
 * SPDX-License-Identifier: MIT */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sx_net.h"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h>
sx_net_transport sx_net_udp_host(int port, char *err, int errlen) {
  sx_net_transport t;
  (void)port;
  memset(&t, 0, sizeof t);
  snprintf(err, (size_t)errlen, "UDP is not available on the web: use the WebRTC offer code");
  return t;
}
sx_net_transport sx_net_udp_join(const char *host, int port, char *err, int errlen) {
  (void)host;
  return sx_net_udp_host(port, err, errlen);
}
int64_t sx_net_clock_ms(void) { return (int64_t)emscripten_get_now(); }
void sx_net_sleep_ms(int ms) { (void)ms; }
#else
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
typedef SOCKET sock_t;
#define BAD_SOCK INVALID_SOCKET
#define closesock closesocket
#else
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
typedef int sock_t;
#define BAD_SOCK (-1)
#define closesock close
#endif

typedef struct udp_ctx {
  sock_t s;
  int host;
  struct sockaddr_in peers[SX_NET_PEERS];
  int npeers;
} udp_ctx;

static int net_started;
static int start_net(void) {
#ifdef _WIN32
  if (!net_started) {
    WSADATA w;
    if (WSAStartup(MAKEWORD(2, 2), &w) != 0) return 0;
  }
#else
  /* a session's summary goes to stdout and stderr; a closed pipe on the
   * other end (a loopback test's partner exited first) must not kill us */
  signal(SIGPIPE, SIG_IGN);
#endif
  net_started = 1;
  return 1;
}

static int set_nonblocking(sock_t s) {
#ifdef _WIN32
  u_long on = 1;
  return ioctlsocket(s, FIONBIO, &on) == 0;
#else
  int fl = fcntl(s, F_GETFL, 0);
  return fl >= 0 && fcntl(s, F_SETFL, fl | O_NONBLOCK) == 0;
#endif
}

static int udp_send(void *ctx, int peer, const unsigned char *buf, int len) {
  udp_ctx *u = (udp_ctx *)ctx;
  if (peer < 0 || peer >= u->npeers) return -1;
  return (int)sendto(u->s, (const char *)buf, len, 0, (const struct sockaddr *)&u->peers[peer], sizeof u->peers[peer]);
}

static int udp_recv(void *ctx, int *peer, unsigned char *buf, int cap) {
  udp_ctx *u = (udp_ctx *)ctx;
  struct sockaddr_in from;
  socklen_t fl = sizeof from;
  int i, len = (int)recvfrom(u->s, (char *)buf, cap, 0, (struct sockaddr *)&from, &fl);
  if (len <= 0) return 0; /* would block (or an ICMP error on Windows: ignore) */
  for (i = 0; i < u->npeers; i++)
    if (u->peers[i].sin_addr.s_addr == from.sin_addr.s_addr && u->peers[i].sin_port == from.sin_port) {
      *peer = i;
      return len;
    }
  if (!u->host || u->npeers >= SX_NET_PEERS) return 0; /* a stranger: ignore */
  u->peers[u->npeers] = from;
  *peer = u->npeers++;
  return len;
}

static void udp_close(void *ctx) {
  udp_ctx *u = (udp_ctx *)ctx;
  closesock(u->s);
  free(u);
}

static sx_net_transport make(udp_ctx *u) {
  sx_net_transport t;
  t.ctx = u;
  t.send = udp_send;
  t.recv = udp_recv;
  t.close = udp_close;
  return t;
}

static sx_net_transport fail_t(char *err, int errlen, const char *what, sock_t s) {
  sx_net_transport t;
  memset(&t, 0, sizeof t);
  snprintf(err, (size_t)errlen, "%s", what);
  if (s != BAD_SOCK) closesock(s);
  return t;
}

sx_net_transport sx_net_udp_host(int port, char *err, int errlen) {
  sock_t s;
  struct sockaddr_in a;
  udp_ctx *u;
  if (!start_net()) return fail_t(err, errlen, "cannot start networking", BAD_SOCK);
  s = socket(AF_INET, SOCK_DGRAM, 0);
  if (s == BAD_SOCK) return fail_t(err, errlen, "cannot open a UDP socket", BAD_SOCK);
  memset(&a, 0, sizeof a);
  a.sin_family = AF_INET;
  a.sin_addr.s_addr = htonl(INADDR_ANY);
  a.sin_port = htons((unsigned short)port);
  if (bind(s, (struct sockaddr *)&a, sizeof a) != 0) return fail_t(err, errlen, "cannot bind the UDP port", s);
  if (!set_nonblocking(s)) return fail_t(err, errlen, "cannot make the socket non-blocking", s);
  u = (udp_ctx *)calloc(1, sizeof *u);
  u->s = s;
  u->host = 1;
  return make(u);
}

sx_net_transport sx_net_udp_join(const char *host, int port, char *err, int errlen) {
  sock_t s;
  struct addrinfo hints, *res = NULL;
  udp_ctx *u;
  char ps[16];
  if (!start_net()) return fail_t(err, errlen, "cannot start networking", BAD_SOCK);
  memset(&hints, 0, sizeof hints);
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_DGRAM;
  snprintf(ps, sizeof ps, "%d", port);
  if (getaddrinfo(host, ps, &hints, &res) != 0 || !res) return fail_t(err, errlen, "cannot resolve the host", BAD_SOCK);
  s = socket(AF_INET, SOCK_DGRAM, 0);
  if (s == BAD_SOCK) {
    freeaddrinfo(res);
    return fail_t(err, errlen, "cannot open a UDP socket", BAD_SOCK);
  }
  if (!set_nonblocking(s)) {
    freeaddrinfo(res);
    return fail_t(err, errlen, "cannot make the socket non-blocking", s);
  }
  u = (udp_ctx *)calloc(1, sizeof *u);
  u->s = s;
  memcpy(&u->peers[0], res->ai_addr, sizeof u->peers[0]);
  u->npeers = 1;
  freeaddrinfo(res);
  return make(u);
}

int64_t sx_net_clock_ms(void) {
#ifdef _WIN32
  return (int64_t)GetTickCount64();
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
#endif
}

void sx_net_sleep_ms(int ms) {
#ifdef _WIN32
  Sleep((DWORD)ms);
#else
  struct timespec ts;
  ts.tv_sec = ms / 1000;
  ts.tv_nsec = (long)(ms % 1000) * 1000000L;
  nanosleep(&ts, NULL);
#endif
}
#endif
