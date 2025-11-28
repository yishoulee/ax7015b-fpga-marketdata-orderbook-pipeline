# AX7015B FPGA Market Data + Order Book Pipeline

This repo contains a staged FPGA project for the ALINX AX7015B (Zynq-7015) board that implements a simplified market data → order book → strategy pipeline.

Data path (current working chain):

- Stage 2: Host Python captures Binance BTCUSDT depth via WebSocket and replays binary records over UART.
- Stage 3: PL timestamping plus UART → AXI-Stream bridge.
- Stage 4: Depth event normalization (`binance_depth_parser`) from unpacked events into a typed `depth_event_t`.
- Stage 5: Single-symbol in-FPGA order book (best bid/ask, quantities).
- Stage 6: Stateless strategy + simple risk limiter consuming book state.

The goal is a realistic, interview-grade pipeline, not a production trading system.

## Stage independence

Each numbered stage is a **standalone** project:

- Every stage has its own `rtl/`, `constr/`, and (if needed) `ip/` and `sim/`.
- Some RTL originally comes from earlier stages, but copies are kept and modified locally so each stage can be built and demonstrated on its own.
- You can open any stage in Vivado independently, without needing the others present.

## Repo structure

- `stage1_axis_loopback/`  
  Pure-PL AXI-Stream bring-up:
  - BRAM/AXI source (`bram_axis_src`), simple header adder, AXIS sink.
  - Used for early AXIS + ILA/VIO validation.

- `stage2_feed_replay/`  
  Host-side tools:
  - Capture Binance BTCUSDT depth via WebSocket (`capture/`).
  - Replay captured `.log` over UART as fixed-size records (`replay/`).
  - Simple inspection tool for log sanity checks (`tools/`).

- `stage3_pl_timestamp_uart/`  
  PL timestamping + UART bridge:
  - 64-bit timestamp counter and latency measurement.
  - UART receiver, record unpacking, UART→AXIS bridge.
  - Top modules: `top_stage3_timestamp` and `top_stage3_serial`.

- `stage4_depth/`  
  Depth parser and supporting tools:
  - `sw_tools/`: UART replay + CSV compare against CPU reference.
  - `pl_depth_parser/`: `binance_depth_parser.sv` plus shared type/utility modules used by later stages.

- `stage5_single_symbol_orderbook_pl/`  
  Single-symbol order book:
  - `pl_order_book.sv` implements a simple best-bid/best-ask book driven by `binance_depth_types::depth_event_t`.
  - Top: `top_stage5_orderbook.sv`.

- `stage6_stateless_kernel_risk_pl/`  
  Stateless strategy + risk limiter:
  - `strategy_kernel_simple.sv` and `risk_limiter_simple.sv`.
  - Top: `top_stage6_strategy.sv` consuming book outputs from Stage 5.

Each PL stage has a similar layout:

- `rtl/` – synthesizable SystemVerilog/Verilog.
- `constr/` – XDC constraints (clock, pins).
- `ip/` – `.xci` IP configuration (e.g. ILA); Vivado regenerates outputs.
- `sim/` – optional testbenches and simulation artefacts.
- (Some stages also reuse earlier RTL files for types and helpers.)

## Vivado / source-control conventions

- `.xpr`, `*.runs/`, `.Xil/`, caches, generated DCP/bit/logs are intentionally not tracked.
- Only **source** artefacts are in Git:
  - `.sv` / `.v`
  - `.xdc`
  - `.xci`
  - scripts (`.py`, `.tcl`) and notes.
- If you want fully scripted builds, add per-stage `create_project.tcl` that:
  - Creates a project under a local `proj/` folder.
  - Adds `rtl/`, `constr/`, and `ip/*.xci`.
  - Sets the appropriate top module and runs synthesis.
