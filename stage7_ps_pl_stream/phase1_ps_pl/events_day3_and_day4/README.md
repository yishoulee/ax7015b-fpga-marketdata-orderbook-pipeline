# Phase 1 Day 3–4: PS/PL mailbox replay + determinism (Binance bookTicker)

This folder contains a reproducible PS→PL event streaming proof using a 4-register AXI-Lite mailbox:

- PC captures Binance `bookTicker` into a fixed binary file `events.bin`
- XSCT script replays `events.bin` into PL via AXI-Lite registers
- PL reports counters + checksum for correctness and determinism

Reference: [Binance Spot WebSocket Streams](https://developers.binance.com/docs/binance-spot-api-docs/web-socket-streams)

## 1. Files in this folder

- `capture_bookticker_events.py`: captures Binance `bookTicker` stream into `events.bin`
- `gen_events.py`: generates synthetic `events.bin` (used for Day 3 bring-up)
- `replay_events.tcl`: XSCT Tcl replayer that writes events into PL mailbox and prints stats
- `events.bin`: 32 bytes/event binary stream (8 x u32 little-endian)

## 2. PS/PL register map

Vivado Address Editor:
- Base address: `0x43C0_0000`
- Range: `64K` (covers `0x43C0_0000 .. 0x43C0_FFFF`)

AXI-Lite register offsets (from `replay_events.tcl` lines 35–39):
- REG0 @ `0x43C00000` (+0x00): LED control (Day 1)
- REG1 @ `0x43C00004` (+0x04): read-only free-running counter (Day 1)
- REG2 @ `0x43C00008` (+0x08): DATA (write W0..W7 staging) / STATS readback
- REG3 @ `0x43C0000C` (+0x0C): CTRL (write) / STATUS (read)

REG3 control bits (mailbox protocol):
- REG3[2:0]   = `idx` (0..7) selects W0..W7 staging index
- REG3[8]     = PUSH  (write 1 to commit the staged event)
- REG3[9]     = CLEAR (write 1 to clear `event_valid` / allow next event)
- REG3[11:10] = `stat_sel` for REG2 readback:
  - 0: events_in
  - 1: drops
  - 2: checksum32
  - 3: last_seq

STATUS read (REG3):
- `event_valid` is indicated by bit31 (example: `0x80000000` means valid)

## 3. `event_t v0` binary contract (bookTicker)

Binary format:
- 1 event = 32 bytes = 8 x uint32 little-endian (`<8I`)

Word mapping (from `capture_bookticker_events.py` line 48):
- W0: MAGIC = `0x30545645`  ("EVT0")  (`capture_bookticker_events.py` line 8)
- W1: seq (u32, increments per message)
- W2: update_id `u` from Binance bookTicker payload
- W3: reserved = 0
- W4: bid_price_pips  = round(bid_price * 1e4)
- W5: bid_qty_pips    = round(bid_qty   * 1e4)
- W6: ask_price_pips  = round(ask_price * 1e4)
- W7: ask_qty_pips    = round(ask_qty   * 1e4)

Scaling constants (from `capture_bookticker_events.py` lines 9–10):
- PRICE_SCALE = 1e4
- QTY_SCALE   = 1e4

Binance bookTicker fields referenced: `u, s, b, B, a, A`.
Reference: [Binance Spot WebSocket Streams](https://developers.binance.com/docs/binance-spot-api-docs/web-socket-streams)

## 4. How to reproduce

### 4.1 Program the FPGA bitstream
After power cycle, re-program the FPGA bitstream (Vivado Hardware Manager), or boot from SD if your BOOT.bin includes the bitstream.

### 4.2 Capture real Binance data to `events.bin`
Dependencies:
```bash
python3 -m pip install --user websockets
```

Capture:

```bash
python3 capture_bookticker_events.py --symbol BTCUSDT --count 1000 --out events.bin
```

Output should end with:

* `wrote 1000 events to events.bin (32000 bytes)`

### 4.3 Replay into PL mailbox (XSCT)

Run twice to prove determinism on identical file:

```bash
xsct replay_events.tcl events.bin 1000
xsct replay_events.tcl events.bin 1000
```

Expected properties (per run):

* `DELTA events_in=1000 drops=0`
* `checksum32_xor=0x........` must match between the two runs for the same `events.bin`

Notes:

* Counters in PL accumulate across runs unless you re-program the FPGA or add an explicit "reset stats" control bit in RTL.
* The script prints START baseline and DELTA values so you can compare per-run behavior.

## 5. Determinism definition used here

Determinism at the PS/PL boundary means:

* Same input file (`events.bin`) replayed twice produces the same `checksum32_xor` delta with:

  * zero drops
  * identical accepted event count

This is a minimal proof that the PS→PL interface and the event contract are stable and reproducible.
