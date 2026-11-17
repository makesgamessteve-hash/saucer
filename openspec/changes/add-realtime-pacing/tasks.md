## 1. Real-time pacing

- [x] 1.1 `sx_pace_wait`: the seconds to sleep so a frame of N ticks is due N/60 s after the previous one
- [x] 1.2 `--realtime` and `SAUCER_REALTIME` options, usage text
- [x] 1.3 `frame()` sleeps after presenting when the run is fixed-step and `--realtime` is set
- [x] 1.4 C unit test `realtime_pacing`; README section
