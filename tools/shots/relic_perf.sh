#!/bin/sh
# Usage: tools/shots/relic_perf.sh BINARY ROOT WORKDIR [SEED] -> work-time stats of tools/shots/relic_perf.lua with
# materials off and full, and the full/off ratio of the p95 (the budget: p95 <= 16.6 ms and full <= 1.1 x off).
# On a software GL (llvmpipe) the absolute numbers mean little; the ratio is the gate.
BIN=$1; ROOT=$2; WORK=$3; SEED=${4:-42}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$WORK"; cd "$WORK" || exit 1
for m in ${MODES:-off full}; do
  SAUCER_FRAME_CSV="$WORK/frames_$m.csv" SDL_AUDIODRIVER=dummy xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" --root "$ROOT" \
    --user-dir "$WORK/ud_$m" --seed "$SEED" --relic-slice --windowed --width 1280 --height 720 --frame-stats \
    --script "$HERE/relic_perf.lua" --script-arg "$m" > "$WORK/perf_$m.log" 2>&1
  grep -o "work(sim+render).*" "$WORK/perf_$m.log" | sed "s/^/$m /"
  tail -n 580 "$WORK/frames_$m.csv" | sort -t, -k2 -g | awk -F, -v m="$m" '{v[NR]=$2; s+=$2} END {if (NR) printf "%s frames=%d avg=%.2f p50=%.2f p95=%.2f max=%.2f ms\n", m, NR, s/NR, v[int(NR*0.5)+1], v[int(NR*0.95)], v[NR]}' | tee "$WORK/stats_$m.txt"
done
if [ -f "$WORK/stats_off.txt" ] && [ -f "$WORK/stats_full.txt" ]; then
  off=$(sed 's/.*p95=\([0-9.]*\).*/\1/' "$WORK/stats_off.txt"); full=$(sed 's/.*p95=\([0-9.]*\).*/\1/' "$WORK/stats_full.txt")
  awk -v o="$off" -v f="$full" 'BEGIN { printf "full/off p95 ratio %.3f (%s)\n", f / o, (f / o <= 1.1) ? "within 1.1x" : "OVER 1.1x" }'
fi
