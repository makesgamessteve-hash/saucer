/* Deterministic serializer for Lua data (nil/bool/int/float/string/table).
 * Table keys are written in a canonical sorted order, so equal data always
 * produces identical bytes - which makes the bytes usable as a state hash.
 * SPDX-License-Identifier: MIT */
#ifndef SX_SER_H
#define SX_SER_H
#include <stddef.h>
#include <stdint.h>
#include "lua.h"

typedef struct sx_buf {
  unsigned char *data;
  size_t len, cap;
} sx_buf;

void sx_buf_put(sx_buf *b, const void *p, size_t n);
void sx_buf_free(sx_buf *b);

#define SX_SER_MAX_DEPTH 64
/* Serialize value at idx. Returns 1, or 0 with message in err (functions,
 * userdata, cycles/depth are rejected). */
int sx_ser_write(lua_State *L, int idx, sx_buf *out, char *err, size_t errlen);
/* Parse bytes and push the value. Returns 1, or 0 (nothing pushed) on corrupt data. */
int sx_ser_read(lua_State *L, const unsigned char *data, size_t len, char *err, size_t errlen);
/* Hash of the canonical serialization (0 when not serializable). */
uint64_t sx_ser_hash(lua_State *L, int idx);
#endif
