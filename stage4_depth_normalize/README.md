# Stage 4 — Depth Normalization (CPU reference and comparison)

This stage includes reference scripts to decode packed depth events, replay logs over UART to feed hardware, and compare FPGA-captured events against a CPU reference CSV.

## Contents
- `config.py`: UART defaults for replay (port, baud, RTS/CTS, timing mode).
- `depth_ev_packed_decoder.py`: Simple decoder for packed depth events from an ILA CSV.
- `depth_cpu_normalizer.py`: CPU-side depth event iterator/utilities (no CLI; import and use).
- `depth_stage4_compare.py`: Comparison harness between FPGA ILA CSV and CPU reference CSV.
- `replay_uart.py`: Replay a binance_depth.log over UART; also emits `depth_cpu_ref.csv` for comparison.
- `depth_cpu_ref.csv`, `depth_stage4_small.csv`: Sample CSV files for quick testing.

## Prerequisites
- Python 3.9+
- Packages: `pyserial`, `pandas` (for compare/decoder)

```bash
pip install pyserial pandas
```

## Usage

1) UART replay (produces CPU reference CSV)

`replay_uart.py` sends 32-byte records over UART from a text log. It also writes `depth_cpu_ref.csv` in the current folder, with columns `[update_id, price_fp, qty_fp]` matching FPGA float bit patterns.

```bash
cd stage4_depth_normalize
python3 replay_uart.py path/to/binance_depth.log \
	--mode accelerated --speed 5 \
	--port /dev/ttyUSB0 --baud 921600 [--rtscts]
```

Notes:
- CLI overrides `config.py` defaults. ENV vars `UART_PORT`, `UART_BAUDRATE`, `UART_RTSCTS` are also honored.
- Input log lines should be: `ts_ns,updateId,side,price,qty` (lines starting with `#SNAP` are ignored).

2) Compare FPGA ILA CSV vs CPU reference

`depth_stage4_compare.py` reads filenames from constants at the top of the file:

- `ILA_CSV = "depth_stage4_small.csv"`
- `CPU_REF_CSV = "depth_cpu_ref.csv"`

Run it directly (ensure both CSVs are present in this folder), or edit the constants to point elsewhere:

```bash
python3 depth_stage4_compare.py
```

It prints total compared, matches, match rate, and the first mismatches.

3) Decode packed depth field from an ILA CSV

`depth_ev_packed_decoder.py` expects a file named `depth_stage4.csv`. Either rename/copy your CSV or change the script to your file name:

```bash
cp depth_stage4_small.csv depth_stage4.csv
python3 depth_ev_packed_decoder.py
```

4) CPU normalizer utilities (no CLI)

`depth_cpu_normalizer.py` currently exposes helpers like `iter_binance_depth_events(path)` and fixed-point conversions. Import it from another script or notebook to build a normalized CSV:

```python
from depth_cpu_normalizer import iter_binance_depth_events
for ev in iter_binance_depth_events("binance_depth.jsonl"):
		# ev.update_id, ev.side, ev.price_fp, ev.qty_fp
		pass
```

## Notes
- Keep `__pycache__/` out of version control (repo root .gitignore already excludes it).
- Large datasets should live outside the repo or under a `data/` folder referenced by your scripts.
- If you standardize this stage further, consider adding a small CLI wrapper and `requirements.txt` to pin versions.
