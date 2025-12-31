#!/usr/bin/env bash
set -euo pipefail

BASE=0x43C00000
IN=stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin
OUT=stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.loopback.bin
EVERY=500
CHUNK=40

xsct stage7_ps_pl_stream/phase3_demo_ready/scripts/xsct_replay_events_loopback.tcl \
  -base "$BASE" -in "$IN" -out "$OUT" -chunk_records "$CHUNK"

python3 stage7_ps_pl_stream/phase3_demo_ready/tools/events_checksum_v0.py \
  --in "$OUT" --every "$EVERY"
