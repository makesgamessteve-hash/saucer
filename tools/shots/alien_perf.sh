#!/bin/sh
# Usage: tools/shots/alien_perf.sh BINARY ROOT WORKDIR [SEED]  -> frame stats per scene of tools/shots/alien_perf.lua
# (before/after: the same binary with the old and the new data root)
BIN=$1; ROOT=$2; WORK=$3; SEED=${4:-42}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$WORK"; cd "$WORK" || exit 1
for ph in orbit wide inside wing; do
  sed "s/^local PHASE = .*/local PHASE = \"$ph\"/" "$HERE/alien_perf.lua" > "$WORK/perf_$ph.lua"
  SAUCER_FRAME_CSV="$WORK/frames_$ph.csv" SDL_AUDIODRIVER=dummy xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" --root "$ROOT" --user-dir "$WORK/ud_$ph" --seed "$SEED" \
    --windowed --width 1280 --height 720 --frame-stats --script "$WORK/perf_$ph.lua" > "$WORK/perf_$ph.log" 2>&1
  # the scene's own frames: the last 600 (the walk-in before the on-foot scenes is left out)
  echo "$ph: $(tail -n 600 "$WORK/frames_$ph.csv" | sort -t, -k2 -g | awk -F, '{v[NR]=$2; s+=$2} END {if (NR) printf "frames=%d avg=%.2f p50=%.2f p95=%.2f max=%.2f ms", NR, s/NR, v[int(NR*0.5)+1], v[int(NR*0.95)], v[NR]}')  $(grep 'perf ' "$WORK/perf_$ph.log" | tr '\n' ' ')"
done
