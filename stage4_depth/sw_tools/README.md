
# Stage 4 — Depth Normalization (CPU reference and comparison)

This folder contains the host-side tools and sample data for Stage 4. It is used to:

- Replay Binance depth logs over UART into the FPGA.
- Capture and normalize CPU-side depth events.
- Compare FPGA-captured events (from ILA CSV) against a CPU reference CSV.

All scripts and data here are Stage-4 specific and standalone.

## Contents

Scripts:

- `config.py`  
  Default UART settings for replay (`UART_PORT`, `UART_BAUDRATE`, `UART_RTSCTS`, default mode/speed).

- `depth_ev_packed_decoder.py`  
  Decoder for packed depth events from an ILA CSV (e.g. `pl_depth_parser/iladata.csv`). Produces a more readable CSV or prints decoded fields.

- `depth_cpu_normalizer.py`  
  CPU-side helpers to iterate and normalize Binance depth events. This is a library module (no CLI); import from other scripts.

- `depth_stage4_compare.py`  
  Main comparison harness between:
  - FPGA ILA export (CSV),
  - CPU reference CSV (`depth_cpu_ref.csv`),
  using `depth_cpu_normalizer.py`.

- `replay_uart.py`  
  Replays a `binance_depth_*.log` file over UART and can emit a CPU reference CSV for comparison.

Sample logs and CSVs (intentionally committed):

- `binance_depth.log`  
  Full Binance depth log (large).  
  Lines: **542,023**

- `binance_depth_ask_only.log`  
  Small ask-only slice for quick tests.  
  Lines: **20**

- `binance_depth_small.log`  
  Reduced log used during early experiments.  
  Lines: **600**

- `binance_depth_tiny.log`  
  Minimal log that reliably fits into a single ILA capture window.  
  Lines: **50**  
  This is the only log that works cleanly end-to-end with the current FPGA + ILA setup.

- `depth_cpu_ref.csv`  
  CPU reference events corresponding to the tiny log.  
  Lines: **50** (1 header + 49 data rows).

- `depth_stage4_small.csv`  
  Example FPGA ILA export (CSV) for a “small” run.  
  Lines: **1,026** (Vivado header / radix rows + data rows).

The row counts are there so you can:

- Sanity-check that you are using the right file.
- Detect partial captures or truncated transfers immediately.

## ILA capture limitation (why tiny log only)

The Stage-4 ILA is configured with a capture depth of 1024 samples. That means:

- Large logs (`binance_depth.log`, `binance_depth_small.log`) cannot be fully captured in one window; you only see a slice of the stream.
- The “tiny” log (`binance_depth_tiny.log`, 50 lines) is small enough that:
  - The UART replay finishes,
  - The FPGA processes all events,
  - A single ILA capture window can cover the entire sequence for comparison.

In practice:

- Use `binance_depth_tiny.log` + `depth_cpu_ref.csv` for full CPU vs FPGA comparisons.
- Use larger logs only for spot-checking behaviour in the ILA, not for full 1-to-1 comparisons.

## Prerequisites

- Python 3.9+
- Packages:
  - `pyserial`
  - `pandas`

Install (example):

```bash
cd stage4_depth/sw_tools
pip install pyserial pandas
```

(or use the Stage-2 `requirements.txt` if you want a shared environment).

## Typical workflows

1. **Replay a tiny log and compare**
    
    - Replay tiny log over UART into the FPGA:
        
        ```bash
        python replay_uart.py binance_depth_tiny.log
        ```
        
        (or use your own CLI flags / config for UART port and baud from `config.py`.)
        
    - Capture FPGA output via ILA to `iladata.csv`.
        
    - Decode and compare:
        
        ```bash
        python depth_ev_packed_decoder.py --ila_csv ../pl_depth_parser/iladata.csv \
                                          --out decoded_fpga.csv
        
        python depth_stage4_compare.py --fpga decoded_fpga.csv \
                                       --cpu depth_cpu_ref.csv
        ```
        
2. **Use your own log**
    
    - Generate your own `*.log` using Stage 2 or another tool.
        
    - Count lines and keep it within what the ILA window can realistically see if you want full coverage (tiny log scale).
        
    - Replay it with `replay_uart.py` and repeat the ILA capture + decoder + compare steps.
        

This folder is meant to be reproducible: you can run the scripts directly against the committed logs and CSVs without needing any external data.
