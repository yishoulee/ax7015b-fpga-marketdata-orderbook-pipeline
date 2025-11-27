# Stage 3 — PL Timestamp Determination & UART Bridging

This stage implements on-FPGA timestamping and latency measurement for incoming records, plus a UART bridge for serial ingress/egress. It is organized for a source-first flow (no GUI project files), so you can recreate Vivado projects deterministically.

## Layout
- `rtl/`: Synthesizable RTL
  - `top_stage3_timestamp.sv`, `top_stage3_serial.sv`
  - `pl_timestamp_counter.sv`, `latency_measure.sv`
  - `event_record_unpack.sv`, `uart_record_axis_bridge.sv`
  - `uart_rx_serial.sv`, `uart_rx_serial.v`, `test_record_gen.sv`
- `constr/`: Constraints
  - `ax7015b_stage3_timestamp.xdc`
- `sim/`: Testbenches
  - `tb_stage3_timestamp.sv`
- `ip/`: IP configuration
  - `ila_0/ila_0.xci` (Vivado will regenerate outputs)

## What it does
- Timestamp incoming records in PL using a free-running counter.
- Measure pipeline latency between record ingress and processed output.
- Bridge UART serial input to internal streams for testing or live feed integration.
- Include an ILA core for on-chip debugging (re-generate products in Vivado).

## Top modules
- `top_stage3_timestamp.sv`: Primary integration top for timestamp + latency path.
- `top_stage3_serial.sv`: Variant top emphasizing UART serial integration.

## Quick start (Vivado GUI)
1. Create a new Vivado project (no sources initially), target your AX7015B board/part.
2. Add sources: all files in `rtl/` as design sources; `sim/tb_stage3_timestamp.sv` as simulation source.
3. Add constraints: `constr/ax7015b_stage3_timestamp.xdc`.
4. Add IP: right-click IP Catalog → Add Repository (optional) or simply Add Sources → Add Or Create Design Sources → select `ip/ila_0/ila_0.xci`. Then “Generate Output Products”.
5. Set top: choose `top_stage3_timestamp` (or `top_stage3_serial` as needed).
6. Run Synthesis/Implementation and generate bitstream.

## Simulation (xsim, non-GUI)
From the repo root or this folder, you can run a minimal xsim flow (adjust paths if running from root):

```bash
# From stage3_timestamp_pl/
mkdir -p build && cd build
xvlog -sv ../rtl/*.sv ../sim/tb_stage3_timestamp.sv
xvlog ../rtl/*.v
xelab tb_stage3_timestamp -s tb
xsim tb -run all
```

Notes:
- If your Vivado version requires explicit include orders, pass files individually instead of globs.
- Check module parameters (e.g., clock freq, baud rate, counter width) in RTL and set as needed.

## Constraints
`constr/ax7015b_stage3_timestamp.xdc` contains clock/IO constraints for the target board. Ensure UART pins and clock sources match your hardware. Update as required for your variant.

## IP (ILA)
The `ila_0.xci` is source-controlled. After opening the project, right-click the ILA core and “Generate Output Products”. No DCPs or generated files are committed by design.

## Development tips
- Keep source-only: do not commit `*.runs/`, `*.gen/`, `.Xil/`, `*.dcp`, logs, etc. The repo’s `.gitignore` already excludes them.
- Prefer scripting (Tcl) for reproducible builds if you formalize this stage further.

## Status
Initial import with working RTL, XDC, testbench, and ILA config. Use `tb_stage3_timestamp.sv` as a starting point for simulation; use ILA in hardware for signal capture.
