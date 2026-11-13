/* Saucer - deterministic math for simulation code.
 * Only IEEE-754 +,-,*,/ and sqrt (correctly rounded everywhere) are used, so
 * results are bit-identical on x86-64, ARM and wasm when the compiler does not
 * contract FMAs (-ffp-contract=off, /fp:precise).
 * SPDX-License-Identifier: MIT */
#ifndef SX_MATH_H
#define SX_MATH_H
#include <stdint.h>

#define SX_PI 3.14159265358979323846
#define SX_TAU 6.28318530717958647692

double sx_sin(double x);
double sx_cos(double x);
double sx_sqrt(double x);
double sx_atan(double x);
double sx_atan2(double y, double x);
double sx_floor(double x);
/* Wrap an angle to (-pi, pi]. */
double sx_wrap_angle(double a);

/* 16.16 fixed point */
typedef int32_t sx_fx;
#define SX_FX_ONE 65536
sx_fx sx_fx_from(double v);
double sx_fx_to(sx_fx v);
sx_fx sx_fx_mul(sx_fx a, sx_fx b);
sx_fx sx_fx_div(sx_fx a, sx_fx b);

#endif
