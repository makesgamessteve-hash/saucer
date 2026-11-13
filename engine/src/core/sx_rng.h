/* Saucer - deterministic integer random numbers and hashing.
 * SPDX-License-Identifier: MIT */
#ifndef SX_RNG_H
#define SX_RNG_H
#include <stddef.h>
#include <stdint.h>

/* Stateless SplitMix64 finalizer of (x + golden gamma). */
uint64_t sx_mix64(uint64_t x);
/* Stateful SplitMix64: advances *state and returns the next value. */
uint64_t sx_splitmix64(uint64_t *state);
/* 64-bit FNV-1a over bytes, finished with sx_mix64. */
uint64_t sx_hash64(const void *data, size_t len);
uint64_t sx_hash64_str(const char *s);
/* Fold another 64-bit value into an existing hash (order dependent). */
uint64_t sx_hash64_combine(uint64_t h, uint64_t v);
/* child = mix64(parent ^ hash64(tag) ^ index) */
uint64_t sx_seed_child(uint64_t parent, const char *tag, uint64_t index);

typedef struct sx_pcg32 {
  uint64_t state;
  uint64_t inc;
} sx_pcg32;

void sx_pcg32_seed(sx_pcg32 *r, uint64_t seed, uint64_t seq);
uint32_t sx_pcg32_next(sx_pcg32 *r);
/* Unbiased value in [0, bound). bound == 0 returns 0. */
uint32_t sx_pcg32_bounded(sx_pcg32 *r, uint32_t bound);
/* Unbiased value in [lo, hi] (inclusive). If hi < lo the bounds are swapped. */
int64_t sx_pcg32_range(sx_pcg32 *r, int64_t lo, int64_t hi);
/* 16.16 fixed-point value in [0, 65536). */
int32_t sx_pcg32_fixed(sx_pcg32 *r);

#endif
