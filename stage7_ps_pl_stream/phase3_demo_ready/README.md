# Phase 3 – Demo-Ready (events.bin -> board replay + deterministic TAP checkpoint)

This folder packages a reproducible, deterministic “demo-ready” pipeline step:

1. A small Binance BTCUSDT depth sample is stored as NDJSON.
2. The NDJSON is converted into a fixed binary format `events.bin` (event_t v0).
3. The board replays `events.bin` through the PS->PL boundary using an AXI FIFO MM-S datapath.
4. A PL-side AXI-Lite “TAP” exposes deterministic observables (`last_hash`, `word_count`, `pkt_count`) that are checked before/after replay for a PASS/FAIL verdict.  

Current scope for this README: **PS replay -> FIFO -> TAP checkpoint PASS/FAIL (+ one metric)**. 

## Quick demo (default): TAP checkpoint (PASS/FAIL + metric)

```bash
cd stage7_ps_pl_stream/phase3_demo_ready
./scripts/run_demo_tap_checkpoint.sh
```

Expected lines:

* `PASS: TAP delta + last_hash matched.` 
* `metric: elapsed_s=... events_per_s=... (events=...)` (printed by the runner around the replay call)

Notes:

* The runner computes expectations from the `events.bin` header (no hard-coded record counts).  
* Defaults (override via env vars):

  * `FIFO_BASE=0x43C00000`
  * `TAP_BASE=0x40000000`
  * `CHUNK_RECORDS=40`
  * `EXPECTED_LAST_HASH=0x651E42BC` 

Example override:

```bash
FIFO_BASE=0x43C00000 TAP_BASE=0x40000000 CHUNK_RECORDS=40 EXPECTED_LAST_HASH=0x651E42BC \
  ./scripts/run_demo_tap_checkpoint.sh
```

## Folder layout

* `data/`

  * `sample_btcusdt_depth.ndjson` (input sample)
  * `sample_btcusdt_depth.events.bin` (converted binary, event_t v0)
  * `sample_btcusdt_depth.events.sha256` (reference hash)
  * `sample_btcusdt_depth.events.loopback.bin` (generated; ignored by git)
* `tools/`

  * `ndjson_to_events_v0.py` (NDJSON -> events.bin)
  * `events_dump_v0.py` (inspect events.bin)
  * `events_checksum_v0.py` (deterministic checksum checkpoints + final SHA-256)
  * `compare_events_bins.py` (byte-level mismatch classifier)
* `scripts/`

  * `run_demo_tap_checkpoint.sh` (one-shot demo: replay + TAP check + metric)  
  * `xsct_read_tap_regs.tcl` (read TAP regs via AXI-Lite)
  * `xsct_replay_events_loopback.tcl` (board replay loopback via AXI FIFO MM-S)
  * `run_demo_loopback.sh` (legacy: loopback + checksum proof)

## Prerequisites

* Python 3
* XSCT (Xilinx/AMD tools). Example output below is from XSCT v2025.1.
* Board programmed with a bitstream that provides:

  * AXI FIFO MM-S at `0x43C00000` (default) 
  * TAP AXI-Lite regs at `0x40000000` (default) 
  * TX->RX loopback path (FIFO replay writes produce RX reads and a loopback file)

## Data format: events.bin (event_t v0)

* File begins with a 64-byte header:

  * magic: `EVT0BIN\0`
  * version: 0
  * record_size: 48 bytes
  * price_scale: 100000000
  * qty_scale: 100000000
  * symbol: `BTCUSDT`
* Payload is a sequence of fixed-size records (48 bytes each).

## Quickstart: verify the committed sample

### 1) Convert NDJSON -> events.bin (optional if already present)

```bash
python3 stage7_ps_pl_stream/phase3_demo_ready/tools/ndjson_to_events_v0.py \
  --in  stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.ndjson \
  --out stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin
```

### 2) Run the default demo (recommended)

```bash
cd stage7_ps_pl_stream/phase3_demo_ready
./scripts/run_demo_tap_checkpoint.sh
```

What it does:

* Reads TAP regs before/after replay and asserts:

  * `delta_words == expected_delta_words`
  * `delta_pkts == expected_delta_pkts`
  * `last_hash == EXPECTED_LAST_HASH` 
* Writes the loopback file (`*.events.loopback.bin`) and runs optional software checks. 

### 3) (Optional) Determinism proof: checksum checkpoints + final SHA-256

The demo runner already runs this after PASS, but you can run it directly:

```bash
python3 stage7_ps_pl_stream/phase3_demo_ready/tools/events_checksum_v0.py \
  --in stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.loopback.bin \
  --every 500
```

Expected output (reference):

```text
symbol=BTCUSDT price_scale=100000000 qty_scale=100000000 every=500
records=500 bytes=24000 sha256=9f1f45975d4a05b46f5d4abb9d7062a3d3ba4b3bb68a462df8037d002729ad99
records=1000 bytes=48000 sha256=0236f7236776012410d0c9a993f3aa0dab69fd40248b530e4155ae38a569ddca
records=1500 bytes=72000 sha256=064581ff383964abb366812adca9bfa8f98998da76b33a8dd53ee93e16d25ef4
records=2000 bytes=96000 sha256=a5bd3077e9b55161d8765d997f60b7f41068c3a34f5b19832fce4a1a1b491166
records=2500 bytes=120000 sha256=92577f8c4643b8bc3e4e154d4a3b038aa0d3d213b07ad0c66cc24a479b19beb1
done records=2735 bytes=131280 sha256_final=0129743eda3ae1fdcb134128fba01055074164dd1bd9ed47416a7cd1416f1c24
```

If your output matches these checkpoints and final hash, the replay loopback is byte-identical and deterministic.

## Legacy demo: Phase 3 loopback only

If you want the original “replay -> loopback -> checksum proof” flow:

```bash
cd stage7_ps_pl_stream/phase3_demo_ready
./scripts/run_demo_loopback.sh
```

## Troubleshooting

### AHB AP transaction error during TX writes

Cause: writing more words into TX than the FIFO vacancy allows before committing/draining.
Fix: lower `CHUNK_RECORDS` (default is 40). 

### PASS fails due to counter/hash mismatch

* `delta_words` mismatch: data drop or unexpected record sizing vs header. 
* `delta_pkts` mismatch: `CHUNK_RECORDS`/packetization mismatch vs expected computation. 
* `last_hash` mismatch: you changed dataset or hash logic; update `EXPECTED_LAST_HASH` only intentionally.  

If you suspect loopback corruption, classify the mismatch:

```bash
python3 stage7_ps_pl_stream/phase3_demo_ready/tools/compare_events_bins.py \
  --a stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin \
  --b stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.loopback.bin
```

## Next milestone after Phase 3

Replace the loopback path with the real datapath:
PS normalizes -> PS->PL stream -> PL orderbook -> PS verify,
while preserving determinism and publishing at least one metric.