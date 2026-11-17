/* Audio: WAV clips loaded through the VFS, one SDL audio stream per voice
 * (one-shots, or loops topped up every frame until stopped by handle),
 * mixed by SDL. Audio is presentation only and never feeds the sim.
 * SPDX-License-Identifier: MIT */
#include <SDL3/SDL.h>
#include <stdlib.h>
#include <string.h>
#include "sx_log.h"
#include "sx_platform.h"

#define MAX_CLIPS 64
#define MAX_VOICES 24

typedef struct clip {
  char path[128];
  SDL_AudioSpec spec;
  Uint8 *data;
  Uint32 len;
  int failed;
} clip;

typedef struct voice {
  SDL_AudioStream *s;
  clip *c;
  int handle, loop;
} voice;

static struct {
  SDL_AudioDeviceID dev;
  SDL_AudioSpec dev_spec;
  clip clips[MAX_CLIPS];
  int nclips;
  voice voices[MAX_VOICES];
} A;

int sx_audio_init(void) {
  memset(&A, 0, sizeof A);
  A.dev = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, NULL);
  if (!A.dev) {
    SX_WARN("no audio device: %s", SDL_GetError());
    return 0;
  }
  SDL_GetAudioDeviceFormat(A.dev, &A.dev_spec, NULL);
  return 1;
}

void sx_audio_shutdown(void) {
  int i;
  for (i = 0; i < MAX_VOICES; i++)
    if (A.voices[i].s) SDL_DestroyAudioStream(A.voices[i].s);
  for (i = 0; i < A.nclips; i++) SDL_free(A.clips[i].data);
  if (A.dev) SDL_CloseAudioDevice(A.dev);
  memset(&A, 0, sizeof A);
}

static clip *get_clip(sx_engine *e, const char *path) {
  int i;
  size_t n = 0;
  char *bytes;
  clip *c;
  for (i = 0; i < A.nclips; i++)
    if (strcmp(A.clips[i].path, path) == 0) return A.clips[i].failed ? NULL : &A.clips[i];
  if (A.nclips >= MAX_CLIPS) return NULL;
  c = &A.clips[A.nclips++];
  memset(c, 0, sizeof *c);
  SDL_strlcpy(c->path, path, sizeof c->path);
  bytes = sx_vfs_read(&e->vfs, path, &n);
  if (!bytes || !SDL_LoadWAV_IO(SDL_IOFromConstMem(bytes, n), true, &c->spec, &c->data, &c->len)) {
    SX_WARN("cannot load sound '%s'", path);
    c->failed = 1;
    free(bytes);
    return NULL;
  }
  free(bytes);
  return c;
}

static void drop_voice(voice *v) {
  if (v->s) SDL_DestroyAudioStream(v->s);
  memset(v, 0, sizeof *v);
}

static voice *find_voice(int handle) {
  int k;
  for (k = 0; k < MAX_VOICES; k++)
    if (A.voices[k].s && A.voices[k].handle == handle) return &A.voices[k];
  return NULL;
}

void sx_audio_flush(sx_engine *e) {
  int i, k;
  if (!A.dev) {
    e->naudio = 0;
    return;
  }
  /* reap finished one-shots; top up loops so they never run dry */
  for (k = 0; k < MAX_VOICES; k++) {
    voice *v = &A.voices[k];
    if (!v->s) continue;
    if (v->loop) {
      if (SDL_GetAudioStreamQueued(v->s) < (int)v->c->len) SDL_PutAudioStreamData(v->s, v->c->data, (int)v->c->len);
    } else if (SDL_GetAudioStreamQueued(v->s) == 0) {
      drop_voice(v);
    }
  }
  for (i = 0; i < e->naudio; i++) {
    const sx_audio_req *r = &e->audio[i];
    clip *c;
    SDL_AudioStream *s;
    voice *v;
    if (r->op == SX_AUDIO_SET) {
      if ((v = find_voice(r->handle)) != NULL) SDL_SetAudioStreamGain(v->s, r->volume);
      continue;
    }
    if (r->op == SX_AUDIO_STOP) {
      if ((v = find_voice(r->handle)) != NULL) drop_voice(v);
      continue;
    }
    c = get_clip(e, r->path);
    if (!c) continue;
    for (k = 0; k < MAX_VOICES && A.voices[k].s; k++) {
    }
    if (k == MAX_VOICES) continue;
    s = SDL_CreateAudioStream(&c->spec, &A.dev_spec);
    if (!s) continue;
    SDL_SetAudioStreamGain(s, r->volume);
    SDL_PutAudioStreamData(s, c->data, (int)c->len);
    if (r->loop) SDL_PutAudioStreamData(s, c->data, (int)c->len);
    else SDL_FlushAudioStream(s);
    SDL_BindAudioStream(A.dev, s);
    A.voices[k].s = s;
    A.voices[k].c = c;
    A.voices[k].handle = r->handle;
    A.voices[k].loop = r->loop;
  }
  e->naudio = 0;
}
