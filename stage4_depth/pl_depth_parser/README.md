# Stage 4 — PL Depth Parser (source-first)

Core FPGA modules to parse packed depth events into typed fields suitable for downstream normalization/order book logic. This stage is organized as a source-only layout (no Vivado GUI artifacts) for reproducible builds.

## Layout
- `rtl/`
  - `binance_depth_parser.sv`
  - `binance_depth_types.sv`
  - `event_record_types.sv`
- `constr/`
  - `ax7015b_stage3_timestamp.xdc` (reused board/pin/clock constraints; update as needed)
- `ip/`
  - `ila_0/ila_0.xci` (ILA IP config; regenerate output products in Vivado)

## What it does
- Defines depth event record types and parsing utilities.
- Implements a hardware decoder for packed depth events (`binance_depth_parser`).
- Ships an ILA core configuration to probe internal signals on hardware.

## Vivado (GUI) quick start
1. Create a new project (no sources initially), target your AX7015B part/board.
2. Add design sources: all files in `rtl/`.
3. Add constraints: `constr/ax7015b_stage3_timestamp.xdc`.
4. Add IP: Add or create design sources → select `ip/ila_0/ila_0.xci`, then right-click the ILA core and “Generate Output Products”.
5. Integrate the parser into your top-level design (this stage does not include a standalone top).
6. Run synthesis/implementation and program the device.

## Notes
- Keep generated content out of Git: runs, gen, cache, .Xil, .dcp, logs. The repo `.gitignore` covers these.
- Constraints filename is inherited; rename and update internally if you maintain a separate constraints file for this stage.
- No testbench is provided here; reuse system-level testbenches or add one under a `sim/` folder if desired.
