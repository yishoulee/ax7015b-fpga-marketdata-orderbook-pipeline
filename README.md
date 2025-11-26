# AX7015B FPGA Market Data + Order Book Pipeline

This repo contains a staged FPGA project on the AX7015B (Zynq-7015) board implementing:

- Market data replay from a captured Binance-like feed via host → FPGA streaming
- Depth / event parsing and packing on FPGA
- In-FPGA limit order book maintenance (best bid/ask, depth levels)
- A simple stateless trading rule kernel and PnL event output
- ILA/VIO instrumentation for latency and correctness checks

The goal is not to build full trading “infrastructure”, but a focused, low-latency market-data/order-book/strategy pipeline that is realistic enough to discuss in an FPGA/low-latency interview.

## Repo structure

- `stage1_axis_loopback/` – BRAM → AXI-Stream FIFO → header adder → sink, with ILA/VIO bring-up.
- `stage2_.../` – [to be added]
- `stage3_.../` – [to be added]
- `...`

Each stage has the same internal layout:

- `rtl/` – synthesizable Verilog for that stage
- `sim/` – testbenches and waveform configs
- `constr/` – XDC constraints
- `ip/` – `.xci` IP configuration and `.coe` init data
- `bd/` – `.bd` block design files
- `vivado/` – `.xpr` project and Tcl; Vivado-generated build dirs are ignored via `.gitignore`.
