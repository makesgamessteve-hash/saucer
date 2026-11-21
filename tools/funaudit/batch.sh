#!/bin/sh
# SPDX-License-Identifier: MIT
# tools/funaudit/batch.sh OUTDIR LIMIT_TICKS "personas" "seeds" [jobs]
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$1; LIMIT=$2; PERS=$3; SEEDS=$4; J=${5:-7}
mkdir -p "$OUT"
for p in $PERS; do for s in $SEEDS; do
  [ -f "$OUT/${p}_s${s}.log" ] && grep -q PTTIME "$OUT/${p}_s${s}.log" && continue
  echo "$p $s"
done; done | xargs -P "$J" -n 2 sh -c "\"$HERE/run.sh\" \$0 \$1 $LIMIT \"$OUT\""
echo BATCH_DONE
