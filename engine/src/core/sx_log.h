/* SPDX-License-Identifier: MIT */
#ifndef SX_LOG_H
#define SX_LOG_H
#include <stdarg.h>

typedef enum { SX_LOG_INFO = 0, SX_LOG_WARN = 1, SX_LOG_ERROR = 2 } sx_log_level;
typedef void (*sx_log_sink)(sx_log_level level, const char *msg, void *user);

void sx_log(sx_log_level level, const char *fmt, ...);
void sx_logv(sx_log_level level, const char *fmt, va_list ap);
/* Replace the sink (NULL restores stderr). Returns nothing; counters reset. */
void sx_log_set_sink(sx_log_sink sink, void *user);
/* Suppress stderr output (sink still receives messages). */
void sx_log_set_quiet(int quiet);
int sx_log_count(sx_log_level level);
void sx_log_reset_counts(void);
const char *sx_log_last(void);

#define SX_INFO(...) sx_log(SX_LOG_INFO, __VA_ARGS__)
#define SX_WARN(...) sx_log(SX_LOG_WARN, __VA_ARGS__)
#define SX_ERROR(...) sx_log(SX_LOG_ERROR, __VA_ARGS__)
#endif
