# Third-party code

| Directory | Project | Version | License |
|---|---|---|---|
| `lua/` | [Lua](https://www.lua.org) (from the official `lua/lua` GitHub mirror) | 5.4.7 | MIT (`lua/LICENSE`) |
| `stb/` | [stb_image](https://github.com/nothings/stb), stb_image_write | 2.30 / 1.16 | MIT or public domain (see file headers) |

## Local patches

`lua/luaconf.h` — appended before the final `#endif` so every Lua state
behaves identically on every machine (required for deterministic replays,
co-op lockstep and stable state hashes, concept §14.1):

```c
#define luai_makeseed(L) ((unsigned int)0x5A0CE5u)  /* fixed string-hash seed */
#define l_randomizePivot() (0u)                     /* deterministic table.sort pivot */
```

Removed from the upstream tree: `testes/`, `manual/`, `makefile`, `all`,
`ltests.*`, `onelua.c`, `lua.c` (the standalone interpreter).
