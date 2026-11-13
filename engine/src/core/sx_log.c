/* SPDX-License-Identifier: MIT */
#include "sx_log.h"
#include <stdio.h>
#include <string.h>

static sx_log_sink g_sink;
static void *g_user;
static int g_quiet;
static int g_counts[3];
static char g_last[1024];

void sx_logv(sx_log_level level, const char *fmt, va_list ap) {
  static const char *names[3] = {"info", "warn", "error"};
  if ((int)level < 0 || (int)level > 2) level = SX_LOG_ERROR;
  vsnprintf(g_last, sizeof g_last, fmt, ap);
  g_counts[level]++;
  if (g_sink) g_sink(level, g_last, g_user);
  if (!g_quiet) fprintf(stderr, "[%s] %s\n", names[level], g_last);
}

void sx_log(sx_log_level level, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  sx_logv(level, fmt, ap);
  va_end(ap);
}

void sx_log_set_sink(sx_log_sink sink, void *user) {
  g_sink = sink;
  g_user = user;
}

void sx_log_set_quiet(int quiet) { g_quiet = quiet; }
int sx_log_count(sx_log_level level) { return ((int)level >= 0 && (int)level <= 2) ? g_counts[level] : 0; }
void sx_log_reset_counts(void) { memset(g_counts, 0, sizeof g_counts); }
const char *sx_log_last(void) { return g_last; }
