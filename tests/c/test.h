/* Tiny unit test harness (MIT). Tests register via TEST(name) and run from
 * test_main.c; names mirror OpenSpec scenarios where one applies. */
#ifndef SX_TEST_H
#define SX_TEST_H
#include <stdio.h>
#include <string.h>

typedef void (*sx_test_fn)(void);
void sx_test_register(const char *name, sx_test_fn fn);
extern int sx_test_failures;
extern const char *sx_test_current;

#if defined(_MSC_VER)
#pragma section(".CRT$XCU", read)
#define SX_CONSTRUCTOR(f)                                                                                              \
  static void f(void);                                                                                                 \
  __declspec(allocate(".CRT$XCU")) void (*f##_)(void) = f;                                                             \
  static void f(void)
#else
#define SX_CONSTRUCTOR(f)                                                                                              \
  static void f(void) __attribute__((constructor));                                                                    \
  static void f(void)
#endif

#define TEST(name)                                                                                                     \
  static void test_##name(void);                                                                                       \
  SX_CONSTRUCTOR(reg_##name) { sx_test_register(#name, test_##name); }                                                 \
  static void test_##name(void)

#define CHECK(cond)                                                                                                    \
  do {                                                                                                                 \
    if (!(cond)) {                                                                                                     \
      printf("  FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);                                                         \
      sx_test_failures++;                                                                                              \
    }                                                                                                                  \
  } while (0)
#define CHECK_EQ_INT(a, b)                                                                                             \
  do {                                                                                                                 \
    long long _a = (long long)(a), _b = (long long)(b);                                                                \
    if (_a != _b) {                                                                                                    \
      printf("  FAIL %s:%d: %s == %s (%lld vs %lld)\n", __FILE__, __LINE__, #a, #b, _a, _b);                           \
      sx_test_failures++;                                                                                              \
    }                                                                                                                  \
  } while (0)
#define CHECK_STR(a, b) CHECK(strcmp((a), (b)) == 0)
#define CHECK_NEAR(a, b, eps) CHECK(((a) - (b)) < (eps) && ((b) - (a)) < (eps))
#endif
