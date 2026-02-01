# Stage 2 — Host-Side Binance Depth Capture + UART Replay

Stage 2 is a **host-side** Python harness. It does not run on the FPGA. It:

1. Captures Binance BTCUSDT order book (depth) over WebSocket into a log file.
2. Replays the captured log as fixed-size 32-byte binary records over UART to the AX7015B.
3. Provides a simple inspection tool for sanity-checking the log content.

Depth log files (for example `binance_depth.log`) are **generated at runtime**. Capture writes to the path configured in `capture/config.py` (`LOG_FILE`) (unless you explicitly wire in a `LOG` override); replay/inspect always use the `LOG=` path you pass. The log itself does not need to be tracked in Git.

## Layout

- `capture/`
  - `capture_binance_depth.py`  
    Continuous Binance BTCUSDT depth capture over WebSocket. Writes events to a log file path configured in `capture/config.py`.
  - `config.py`  
    Symbol, REST/WebSocket endpoints, and default output log path.

- `replay/`
  - `replay_uart.py`  
    Replays a depth log file over UART as fixed-size 32-byte records, using timing derived from the `ts_ns` field.
  - `config.py`  
    Default UART settings (`UART_PORT`, `UART_BAUDRATE`, `UART_RTSCTS`, `DEFAULT_MODE`, `DEFAULT_SPEED`).

- `tools/`
  - `inspect_log.py`  
    Minimal inspection tool for a depth log (counts, sample lines, snapshot vs incremental events).

- `requirements.txt`  
  Python dependencies for capture/replay/tools.

- `makefile`  
  Convenience targets for install, capture, inspect, and replay. This is the *authoritative* interface.

## Setup

Use any Python 3.10+ environment. Example with Conda:

```bash
cd stage2_feed_replay

conda create -n stage2-replay python=3.10 pip -y
conda activate stage2-replay

pip install -r requirements.txt
```

Alternatively, use your existing Python environment and `pip install -r requirements.txt`.

## Usage via make (recommended)

The `makefile` exposes the key operations and parameters:

```make
# Key variables (defaults)
PYTHON ?= python
LOG ?= binance_depth.log
MODE ?= realtime       # realtime | accelerated
SPEED ?= 5.0           # used when MODE=accelerated
UART ?= /dev/ttyUSB0
BAUD ?=
```

### 1. Capture a depth log

```bash
cd stage2_feed_replay

# Install Python deps into the current env
make install

# Start continuous BTCUSDT depth capture
make capture
# This writes to the path from capture/config.py (LOG_FILE). LOG= does not affect capture unless you wire it in.
```

If you want a specific capture path, change `LOG_FILE` in `capture/config.py` (the capture script itself does not take a CLI `--log` argument; the path is configured in code).

### 2. Inspect a log

```bash
# Default: LOG = binance_depth.log
make inspect

# Or explicitly:
make inspect LOG=binance_depth.log
make inspect LOG=./logs/binance_depth_2025-11-28.log
```

Under the hood this runs:

```bash
python -m tools.inspect_log <LOG>
```

where `<LOG>` is the path you pass via `LOG=`.

### 3. Replay a log over UART

The `replay` target calls `replay/replay_uart.py` with parameters wired to your make variables:

```make
replay:
	$(PYTHON) -m replay.replay_uart \
	    --mode $(MODE) \
	    --speed $(SPEED) \
	    $(if $(UART),--port $(UART),) \
	    $(if $(BAUD),--baud $(BAUD),) \
	    $(LOG)
```

So you drive it like this:

```bash
# Simple realtime replay with default UART and log:
make replay

# Explicit log + UART + baud:
make replay LOG=binance_depth.log MODE=realtime UART=/dev/ttyS0 BAUD=115200

# Accelerated (shortened time gaps) with explicit speed:
make replay LOG=binance_depth.log MODE=accelerated SPEED=5.0 UART=/dev/ttyS0 BAUD=115200
```

There is also a convenience target for accelerated replay:

```bash
make replay-accel LOG=binance_depth.log SPEED=5.0
```

which internally calls `make replay` with `MODE=accelerated`.

## Direct Python usage (without make)

If you want to bypass `make`:

- Capture (no CLI flags; uses `capture/config.py`):
    

```bash
python -m capture.capture_binance_depth
```

- Inspect:
    

```bash
python -m tools.inspect_log binance_depth.log
```

- Replay:
    

```bash
# Realtime with defaults from replay/config.py and environment:
python -m replay.replay_uart binance_depth.log

# Explicit UART + baud + mode:
python -m replay.replay_uart \
    --mode realtime \
    --port /dev/ttyS0 \
    --baud 115200 \
    binance_depth.log

# Accelerated:
python -m replay.replay_uart \
    --mode accelerated \
    --speed 5.0 \
    --port /dev/ttyS0 \
    --baud 115200 \
    binance_depth.log
```

Environment variables (`UART_PORT`, `UART_BAUDRATE`, `UART_RTSCTS`) and `replay/config.py` values are used as fallbacks when CLI options are omitted.
