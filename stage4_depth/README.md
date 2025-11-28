# Stage 4 — Depth Parsing & Normalization

Stage 4 is a standalone stage with:

- `sw_tools/`: host-side scripts to replay logs over UART, generate CPU reference CSVs, and compare FPGA vs CPU output.
- `pl_depth_parser/`: a self-contained Vivado project folder (source-first) for the PL depth parser and its ILA/constraints.

Although some RTL started life in Stage 3, copies are kept here and modified to meet Stage 4’s goal. You can treat this folder as an independent unit for bring-up, testing, and publishing.

## Structure

- `sw_tools/`
  - Python scripts and sample logs/CSVs for Stage 4 experiments.
  - See `sw_tools/README.md` for details and exact file counts.
- `pl_depth_parser/`
  - `rtl/` — SystemVerilog RTL for the depth parser, shared types, and a Stage-4-specific top harness.
  - `constr/` — AX7015B XDC constraints.
  - `ip/` — ILA IP configuration (`ila_0.xci`) only.
  - `iladata.csv` — example ILA CSV export used during testing.

## Typical usage

1. Use `sw_tools/replay_uart.py` with one of the included `binance_depth_*.log` files to drive Stage 4 via UART.
2. Capture the FPGA output via ILA into a CSV (e.g. `iladata.csv`).
3. Run `sw_tools/depth_ev_packed_decoder.py` and `depth_stage4_compare.py` to decode / compare against CPU reference CSVs.

Stage 4 is designed so that:

- PL can be tested on its own in Vivado using `pl_depth_parser/`.
- Host-side tools and sample logs in `sw_tools/` are sufficient to reproduce the tests without any external data.
