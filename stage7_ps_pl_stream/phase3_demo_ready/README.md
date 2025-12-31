# Phase 3 – Demo-Ready (Binance capture -> events.bin -> board replay loopback)

This folder packages a reproducible, deterministic “demo-ready” pipeline step:

1. A small Binance BTCUSDT depth sample is stored as NDJSON.
2. The NDJSON is converted into a fixed binary format `events.bin` (event_t v0).
3. The board replays `events.bin` through the PS->PL boundary using an AXI FIFO MM-S datapath (currently in loopback mode).
4. The loopback output is verified via checksum checkpoints and final SHA-256.

Current scope for this README: **PS replay -> FIFO loopback -> output file -> checksum proof**.

## Quick demo (Phase 3 loopback)

```bash
cd stage7_ps_pl_stream/phase3_demo_ready
./scripts/run_demo_loopback.sh
```

## Folder layout

- `data/`
  - `sample_btcusdt_depth.ndjson` (input sample)
  - `sample_btcusdt_depth.events.bin` (converted binary, event_t v0)
  - `sample_btcusdt_depth.events.sha256` (reference hash)
  - `sample_btcusdt_depth.events.loopback.bin` (generated; ignored by git)
- `tools/`
  - `ndjson_to_events_v0.py` (NDJSON -> events.bin)
  - `events_dump_v0.py` (inspect events.bin)
  - `events_checksum_v0.py` (deterministic checksum checkpoints + final SHA-256)
  - `compare_events_bins.py` (byte-level mismatch classifier)
- `scripts/`
  - `xsct_replay_events_loopback.tcl` (board replay loopback via AXI FIFO MM-S)

## Prerequisites

- Python 3
- XSCT (Xilinx/AMD tools). Example output below is from **XSCT v2025.1**.
- Board programmed with a bitstream that provides the AXI FIFO MM-S at `0x43C00000` and a **TX->RX loopback** path.

## Data format: events.bin (event_t v0)

- File begins with a 64-byte header:
  - magic: `EVT0BIN\0`
  - version: 0
  - record_size: 48 bytes
  - price_scale: 100000000
  - qty_scale: 100000000
  - symbol: `BTCUSDT`
- Payload is a sequence of fixed-size records (48 bytes each).

## Quickstart: verify the committed sample

### 1) Convert NDJSON -> events.bin (optional if already present)

```bash
python3 stage7_ps_pl_stream/phase3_demo_ready/tools/ndjson_to_events_v0.py \
  --in  stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.ndjson \
  --out stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin
````

### 2) Board replay loopback (events.bin -> loopback.bin)

```bash
xsct stage7_ps_pl_stream/phase3_demo_ready/scripts/xsct_replay_events_loopback.tcl \
  -base 0x43C00000 \
  -in  stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin \
  -out stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.loopback.bin \
  -chunk_records 40
```

Notes:

* `chunk_records=40` is chosen to fit typical FIFO TX vacancy (`TDFV ~ 0x1FC` words).
* Output file `*.loopback.bin` is a generated artifact and should not be committed.

### 3) Determinism proof: checksum checkpoints + final SHA-256

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

## Troubleshooting

### AHB AP transaction error during TX writes

Cause: writing more words into TX than the FIFO vacancy allows before committing/draining.
Fix: lower `-chunk_records` (default here is 40).

### Checksum mismatch between input and loopback

Use the comparator to classify the mismatch:

```bash
python3 stage7_ps_pl_stream/phase3_demo_ready/tools/compare_events_bins.py \
  --a stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin \
  --b stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.loopback.bin
```

If the first mismatch happens at byte 0 and the “data” looks like register addresses, your XSCT `mrd` parsing is wrong (script already includes robust parsing, but XSCT output formatting can vary).

## Next milestone after loopback

Replace the loopback path with the real datapath:
PS normalizes -> PS->PL stream -> PL orderbook -> PS verify,
while preserving determinism and publishing one metric (events/s or proxy).
