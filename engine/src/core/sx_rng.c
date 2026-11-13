/* SPDX-License-Identifier: MIT */
#include "sx_rng.h"

uint64_t sx_mix64(uint64_t x) {
  uint64_t z = x + 0x9E3779B97F4A7C15ull;
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
  return z ^ (z >> 31);
}

uint64_t sx_splitmix64(uint64_t *state) {
  uint64_t v = sx_mix64(*state);
  *state += 0x9E3779B97F4A7C15ull;
  return v;
}

uint64_t sx_hash64(const void *data, size_t len) {
  const unsigned char *p = (const unsigned char *)data;
  uint64_t h = 0xCBF29CE484222325ull;
  size_t i;
  for (i = 0; i < len; i++) {
    h ^= p[i];
    h *= 0x100000001B3ull;
  }
  return sx_mix64(h);
}

uint64_t sx_hash64_str(const char *s) {
  size_t n = 0;
  if (!s) return sx_hash64("", 0);
  while (s[n]) n++;
  return sx_hash64(s, n);
}

uint64_t sx_hash64_combine(uint64_t h, uint64_t v) {
  return sx_mix64(h ^ (v + 0x9E3779B97F4A7C15ull + (h << 6) + (h >> 2)));
}

uint64_t sx_seed_child(uint64_t parent, const char *tag, uint64_t index) {
  return sx_mix64(parent ^ sx_hash64_str(tag) ^ index);
}

void sx_pcg32_seed(sx_pcg32 *r, uint64_t seed, uint64_t seq) {
  r->state = 0u;
  r->inc = (seq << 1u) | 1u;
  (void)sx_pcg32_next(r);
  r->state += seed;
  (void)sx_pcg32_next(r);
}

uint32_t sx_pcg32_next(sx_pcg32 *r) {
  uint64_t old = r->state;
  uint32_t xorshifted, rot;
  r->state = old * 6364136223846793005ull + r->inc;
  xorshifted = (uint32_t)(((old >> 18u) ^ old) >> 27u);
  rot = (uint32_t)(old >> 59u);
  return (xorshifted >> rot) | (xorshifted << ((32u - rot) & 31u));
}

uint32_t sx_pcg32_bounded(sx_pcg32 *r, uint32_t bound) {
  uint32_t threshold;
  if (bound == 0) return 0;
  threshold = (uint32_t)(0u - bound) % bound;
  for (;;) {
    uint32_t v = sx_pcg32_next(r);
    if (v >= threshold) return v % bound;
  }
}

int64_t sx_pcg32_range(sx_pcg32 *r, int64_t lo, int64_t hi) {
  uint64_t span;
  if (hi < lo) {
    int64_t t = lo;
    lo = hi;
    hi = t;
  }
  span = (uint64_t)hi - (uint64_t)lo;
  if (span < 0xFFFFFFFFull) {
    return lo + (int64_t)sx_pcg32_bounded(r, (uint32_t)(span + 1u));
  }
  /* wide range: rejection sampling on 64-bit draws */
  for (;;) {
    uint64_t v = ((uint64_t)sx_pcg32_next(r) << 32) | sx_pcg32_next(r);
    uint64_t n = span + 1u; /* wraps to 0 for the full 64-bit range */
    if (n == 0) return (int64_t)((uint64_t)lo + v);
    if (v >= (0u - n) % n) return (int64_t)((uint64_t)lo + v % n);
  }
}

int32_t sx_pcg32_fixed(sx_pcg32 *r) { return (int32_t)(sx_pcg32_next(r) >> 16); }
