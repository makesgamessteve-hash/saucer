/* SPDX-License-Identifier: MIT */
#include <stdlib.h>
#include "sx_log.h"
#include "test.h"

#define MAX_TESTS 512
static struct {
  const char *name;
  sx_test_fn fn;
} tests[MAX_TESTS];
static int ntests;
int sx_test_failures;
const char *sx_test_current;

void sx_test_register(const char *name, sx_test_fn fn) {
  if (ntests < MAX_TESTS) {
    tests[ntests].name = name;
    tests[ntests].fn = fn;
    ntests++;
  }
}

int main(int argc, char **argv) {
  int i, failed_tests = 0;
  const char *filter = argc > 1 ? argv[1] : NULL;
  sx_log_set_quiet(1);
  setvbuf(stdout, NULL, _IONBF, 0);
  for (i = 0; i < ntests; i++) {
    int before = sx_test_failures;
    if (filter && !strstr(tests[i].name, filter)) continue;
    sx_test_current = tests[i].name;
    tests[i].fn();
    if (sx_test_failures != before) {
      failed_tests++;
      printf("[FAIL] %s\n", tests[i].name);
    } else {
      printf("[ ok ] %s\n", tests[i].name);
    }
  }
  printf("%d tests, %d failed, %d failed checks\n", ntests, failed_tests, sx_test_failures);
  return failed_tests ? 1 : 0;
}
