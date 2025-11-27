# Stage 2 — Host-Side Binance Data Feed + Replay Harness

This repo provides:

1. `capture/` — Capture BTCUSDT depth from Binance into a `.log` file.
2. `replay/` — Replay the `.log` as fixed-size binary records over UART.
3. `tools/` — Simple inspection script for sanity checks.

## 1. Setup (Conda)

```bash
# Create and activate a fresh Conda env (Python 3.10+)
conda create -n stage2-replay python=3.10 pip -y
conda activate stage2-replay

# Install Python deps via pip inside the Conda env
pip install -r requirements.txt
```

Packages used: `websockets`, `requests`, `pyserial`.

## 2. Capture Binance Depth

Edit `capture/config.py` if needed, then run (recommended):

```bash
# From repo root
python -m stage2_feed_replay.capture.capture_binance_depth
```

Alternatively, run as a script:

```bash
# From repo root
python stage2_feed_replay/capture/capture_binance_depth.py
# or from inside the folder (also works)
cd stage2_feed_replay/capture && python capture_binance_depth.py
```

This will:

- Fetch a depth snapshot via REST
- Start a WebSocket connection to `wss://stream.binance.com:9443/ws/btcusdt@depth@100ms`
- Append records to `../binance_depth.log` until you Ctrl+C

## 3. Inspect the Log

```bash
cd tools
python inspect_log.py ../binance_depth.log
```

You should see:

- Total record count
- Sample lines
- Unique `updateId` count

## 4. Replay over UART

Set the correct serial port in `replay/config.py`, then run:

```bash
# From repo root (recommended)
python -m stage2_feed_replay.replay.replay_uart --mode realtime --speed 1.0 stage2_feed_replay/binance_depth.log

# Override UART from CLI or env
python -m stage2_feed_replay.replay.replay_uart --port /dev/ttyS0 --baud 115200 --mode accelerated --speed 5.0 stage2_feed_replay/binance_depth.log

# Or Makefile shortcuts from stage2_feed_replay/
make replay LOG=binance_depth.log UART=/dev/ttyS0 BAUD=115200 MODE=realtime
make replay-accel LOG=binance_depth.log SPEED=5.0
```

If the port cannot open, the tool will list detected serial ports. You can also set env vars instead of CLI flags: `UART_PORT`, `UART_BAUDRATE`, `UART_RTSCTS`.

## 5. Binary Record Format (fixed)

The replay sends a fixed 32-byte (256-bit) record. This schema is frozen for Stage 2 to ensure compatibility:

- Struct pack string: `"<QQBffxxxxxxx"`
- Field types and order:
	- `uint64 ts_ns`
	- `uint64 updateId`
	- `uint8  side`        (0 = bid, 1 = ask)
	- `float32 price`
	- `float32 qty`
	- `7 bytes padding`

Bit mapping on a 256-bit AXI-Stream word:

```
bits [ 63:  0] = ts_ns      (uint64)
bits [127: 64] = updateId   (uint64)
bits [135:128] = side       (uint8)
bits [167:136] = price_f32
bits [199:168] = qty_f32
bits [255:200] = padding
```

Any pack/unpack code (tests, sims, PL) must use this exact layout.

## 6. Stage 2 KPIs

- ≥ 30 minutes of BTCUSDT depth captured without WebSocket disconnects (continuous session).
- Log is parsable by `tools/inspect_log.py` with non-zero event count.

## 7. Quick Tips

- If your corporate network blocks WebSockets, try from a different network or set the `HTTPS_PROXY`/`HTTP_PROXY` for REST; WS must be allowed.
- Makefile shortcuts available inside `stage2_feed_replay/`:
	- `make install`
	- `make capture`
	- `make inspect LOG=binance_depth.log`
	- `make replay LOG=binance_depth.log UART=/dev/ttyS0 BAUD=115200 MODE=realtime`
	- `make replay-accel LOG=binance_depth.log SPEED=5.0`
