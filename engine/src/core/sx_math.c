/* SPDX-License-Identifier: MIT */
#include "sx_math.h"
#include <math.h>

double sx_floor(double x) {
  /* floor() is exact in IEEE-754 on every libm, but keep one entry point. */
  return floor(x);
}

double sx_sqrt(double x) {
  if (!(x > 0.0)) return 0.0; /* negative, zero and NaN -> 0 */
  return sqrt(x);             /* IEEE-754 requires correct rounding */
}

/* Taylor kernels on [-pi/4, pi/4]; truncation error < 1e-17. */
static double sin_kernel(double x) {
  double x2 = x * x;
  double r = -7.6471637318198164759e-13; /* -1/15! */
  r = r * x2 + 1.6059043836821614599e-10; /* 1/13! */
  r = r * x2 - 2.5052108385441718775e-08; /* -1/11! */
  r = r * x2 + 2.7557319223985890653e-06; /* 1/9! */
  r = r * x2 - 1.9841269841269841270e-04; /* -1/7! */
  r = r * x2 + 8.3333333333333333333e-03; /* 1/5! */
  r = r * x2 - 1.6666666666666666667e-01; /* -1/3! */
  return x + x * x2 * r;
}

static double cos_kernel(double x) {
  double x2 = x * x;
  double r = 4.7794773323873852974e-14; /* 1/16! */
  r = r * x2 - 1.1470745597729724714e-11; /* -1/14! */
  r = r * x2 + 2.0876756987868098979e-09; /* 1/12! */
  r = r * x2 - 2.7557319223985890653e-07; /* -1/10! */
  r = r * x2 + 2.4801587301587301587e-05; /* 1/8! */
  r = r * x2 - 1.3888888888888888889e-03; /* -1/6! */
  r = r * x2 + 4.1666666666666666667e-02; /* 1/4! */
  r = r * x2 - 0.5;
  return 1.0 + x2 * r;
}

static double reduce(double x, int *quadrant) {
  /* x = k * (pi/2) + r with |r| <= pi/4, using a two-part pi/2 */
  const double pio2_hi = 1.57079632673412561417e+00;
  const double pio2_lo = 6.07710050650619224932e-11;
  double k = sx_floor(x * 0.63661977236758134308 + 0.5);
  double r = (x - k * pio2_hi) - k * pio2_lo;
  long long q = (long long)k;
  *quadrant = (int)(((q % 4) + 4) % 4);
  return r;
}

double sx_sin(double x) {
  int q;
  double r;
  if (x != x) return 0.0;
  if (x > 1e9 || x < -1e9) return 0.0; /* out of sim range: defined, not useful */
  r = reduce(x, &q);
  switch (q) {
  case 0: return sin_kernel(r);
  case 1: return cos_kernel(r);
  case 2: return -sin_kernel(r);
  default: return -cos_kernel(r);
  }
}

double sx_cos(double x) {
  int q;
  double r;
  if (x != x) return 1.0;
  if (x > 1e9 || x < -1e9) return 1.0;
  r = reduce(x, &q);
  switch (q) {
  case 0: return cos_kernel(r);
  case 1: return -sin_kernel(r);
  case 2: return -cos_kernel(r);
  default: return sin_kernel(r);
  }
}

double sx_atan(double x) {
  int neg = 0, inv = 0, i;
  double r, x2, t, sum;
  if (x != x) return 0.0;
  if (x < 0) {
    neg = 1;
    x = -x;
  }
  if (x > 1.0) {
    inv = 1;
    x = 1.0 / x;
  }
  /* two half-angle reductions: atan(x) = 2 atan(x / (1 + sqrt(1 + x^2))) */
  x = x / (1.0 + sx_sqrt(1.0 + x * x));
  x = x / (1.0 + sx_sqrt(1.0 + x * x));
  /* now |x| <= tan(pi/16) ~ 0.199; series converges fast */
  x2 = x * x;
  t = x;
  sum = 0.0;
  for (i = 0; i < 12; i++) {
    double term = t / (double)(2 * i + 1);
    sum = (i & 1) ? sum - term : sum + term;
    t = t * x2;
  }
  r = 4.0 * sum;
  if (inv) r = SX_PI / 2.0 - r;
  return neg ? -r : r;
}

double sx_atan2(double y, double x) {
  if (x > 0) return sx_atan(y / x);
  if (x < 0) {
    if (y >= 0) return sx_atan(y / x) + SX_PI;
    return sx_atan(y / x) - SX_PI;
  }
  if (y > 0) return SX_PI / 2.0;
  if (y < 0) return -SX_PI / 2.0;
  return 0.0;
}

double sx_wrap_angle(double a) {
  if (a != a) return 0.0;
  a = a - SX_TAU * sx_floor((a + SX_PI) / SX_TAU);
  if (a <= -SX_PI) a += SX_TAU;
  return a;
}

sx_fx sx_fx_from(double v) {
  double s = v * 65536.0;
  if (s >= 2147483647.0) return INT32_MAX;
  if (s <= -2147483648.0) return INT32_MIN;
  return (sx_fx)sx_floor(s);
}

double sx_fx_to(sx_fx v) { return (double)v / 65536.0; }

sx_fx sx_fx_mul(sx_fx a, sx_fx b) {
  int64_t p = (int64_t)a * (int64_t)b;
  /* arithmetic shift of negatives: divide with floor semantics */
  if (p < 0) return (sx_fx)(-((-p + 65535) >> 16));
  return (sx_fx)(p >> 16);
}

sx_fx sx_fx_div(sx_fx a, sx_fx b) {
  int64_t n;
  if (b == 0) return a >= 0 ? INT32_MAX : INT32_MIN;
  n = ((int64_t)a * 65536) / b;
  if (n > INT32_MAX) return INT32_MAX;
  if (n < INT32_MIN) return INT32_MIN;
  return (sx_fx)n;
}
