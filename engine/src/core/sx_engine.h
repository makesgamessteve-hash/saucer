/* Engine orchestration: options, boot (mods -> VFS -> Lua), fixed tick,
 * per-viewport render, headless runner, Lua test runner, replays.
 * SPDX-License-Identifier: MIT */
#ifndef SX_ENGINE_H
#define SX_ENGINE_H
#include <stdint.h>
#include "lua.h"
#include "sx_input.h"
#include "sx_mod.h"
#include "sx_phys.h"
#include "sx_render.h"
#include "sx_replay.h"
#include "sx_touch.h"
#include "sx_vfs.h"
#include "sx_xr.h"

#define SX_VERSION "0.1.0"
#define SX_TICK_HZ 60
#define SX_MAX_TICKS_PER_FRAME 8

typedef struct sx_options {
  char root[512];     /* folder that holds data/ and mods/ */
  char user_dir[512]; /* saves, bindings, logs */
  char mods[256];     /* comma separated enabled mods, "" = all */
  char mods_dir[512]; /* default <root>/mods */
  uint64_t seed;
  int headless;
  int windowed; /* --windowed: run a --script in the window (screenshot tours) */
  char script[512];   /* game test script (VFS-independent path) */
  char test_lua[512]; /* folder with runner.lua + *_spec.lua */
  char filter[128];   /* only run spec files containing this */
  int coverage;       /* load luacov in test mode */
  int64_t max_ticks;  /* headless stop (0 = until script ends / 600) */
  int local_players;
  int viewports;
  char record[512];
  char play[512];
  char screenshot[512];
  int64_t screenshot_tick;
  int restore_every_tick;
  int width, height;
  int coop;
  int quiet;
  int test_mode; /* debug checks: render mutation guard, saucer.test */
  int show_help;
} sx_options;

typedef struct sx_audio_req {
  char path[128];
  float volume, pan;
  int handle;
} sx_audio_req;

typedef struct sx_mod_rt {
  int mod_index;  /* into modset */
  int env_ref;    /* registry ref of the mod environment */
  int strikes;
  int disabled;
} sx_mod_rt;

typedef struct sx_engine {
  sx_options opt;
  sx_vfs vfs;
  sx_modset mods;
  sx_mod_rt rt[SX_MAX_MODS];
  int nrt;
  uint64_t modset_hash;
  sx_input input;
  sx_touch touch;
  sx_xr xr;
  sx_phys phys;
  sx_render render;
  lua_State *L;
  int state_ref;    /* sim state table */
  int ro_state_ref; /* read-only proxy */
  int64_t tick;
  int in_render;
  int failed; /* fatal script error or failed assertion */
  char fail_msg[512];
  /* budget */
  long long budget_left;
  long long budget_tick;
  int budget_hook;
  /* replay */
  sx_replay rec;
  int recording;
  sx_replay play;
  int playing;
  int replay_failed;
  /* game-test script */
  lua_State *test_co;
  int test_co_ref;
  int test_wait;
  int test_done;
  struct {
    uint32_t buttons;
    int buttons_ticks[SX_MAX_BUTTON_ACTIONS];
    int16_t axes[SX_NUM_AXES];
    int axes_ticks[SX_NUM_AXES];
  } inject[SX_MAX_PLAYERS];
  uint32_t inject_prev[SX_MAX_PLAYERS];
  sx_cmd last_cmds[SX_MAX_PLAYERS];
  int nlast_cmds;
  /* audio */
  sx_audio_req audio[32];
  int naudio, audio_next_handle;
  int audio_played_total;
  /* screenshots requested by scripts */
  char shot_path[512];
  int shot_pending;
  /* events */
  int events_ref;
  int ticks_called;
} sx_engine;

void sx_options_default(sx_options *o);
/* Returns 1 ok, 0 on bad arguments (err filled). */
int sx_options_parse(sx_options *o, int argc, char **argv, char *err, int errlen);
const char *sx_usage(void);

sx_engine *sx_engine_create(const sx_options *o);
void sx_engine_destroy(sx_engine *e);
/* Build command frames from devices / replay / test injection and step once. */
int sx_engine_tick(sx_engine *e);
/* Step with explicit frames (n = player count). */
int sx_engine_step(sx_engine *e, const sx_cmd *cmds, int n);
void sx_engine_render(sx_engine *e, double alpha);
uint64_t sx_engine_state_hash(sx_engine *e);
/* Fixed-step scheduler: accumulate elapsed seconds and return ticks to run. */
int sx_ticks_for_frame(double *accumulator, double elapsed);
/* Snapshot/restore the sim state (returns malloc'd bytes). */
unsigned char *sx_engine_snapshot(sx_engine *e, size_t *len);
int sx_engine_restore(sx_engine *e, const unsigned char *data, size_t len);
/* Persisted per-player binding overrides. */
int sx_engine_save_bindings(sx_engine *e, int player);
int sx_engine_load_bindings(sx_engine *e, int player);
int sx_engine_finish(sx_engine *e); /* flush recordings; returns exit status */

/* Runners used by main(): return a process exit status. */
int sx_run_headless(const sx_options *o);
int sx_run_lua_tests(const sx_options *o);
int sx_main(int argc, char **argv);

/* Lua runtime (sx_script.c) */
int sx_script_open(sx_engine *e);
void sx_script_close(sx_engine *e);
int sx_script_load_mods(sx_engine *e);
/* Call hook `name` in every enabled mod; nargs values on top of stack are
 * passed to each (and popped). Returns 0 on error. */
int sx_script_call_hook(sx_engine *e, const char *name, int nargs, long long budget);
void sx_script_push_readonly(lua_State *L, int idx);
int sx_script_run_file_in_env(sx_engine *e, const char *path, int env_ref, int nresults);
#endif
