
# Stage 4 — PL Depth Parser (Standalone Stage)

This folder contains the PL-side depth parser and a Stage-4-specific top-level harness. It is a **standalone** Vivado stage:

- You can create a project with just this folder.
- It has its own top modules, constraints, and ILA IP config.
- Utility modules originally from Stage 3 are copied and modified here so Stage 4 is self-contained.

## Layout

- `rtl/`
  - `binance_depth_parser.sv`  
    Core parser that converts unpacked fields into a `binance_depth_types::depth_event_t`.

  - `binance_depth_types.sv`  
    Package defining `depth_event_t`, side enums, and flags used by Stage 4 and later stages.

  - `event_record_types.sv`  
    Type definitions for the raw record format (timestamp, update id, side, price, qty, etc).

  - `event_record_unpack.sv`  
    Unpacks fixed-size records from Stage 3 / UART replay into typed fields for the parser.

  - `pl_timestamp_counter.sv`  
    64-bit PL timestamp counter used for measuring latency and tagging events.

  - `latency_measure.sv`  
    Simple latency measurement block using the timestamp.

  - `uart_record_axis_bridge.sv`  
    UART→AXI-Stream bridge used in this standalone harness.

  - `uart_rx_serial.sv`  
    UART receiver core.

  - `test_record_gen.sv`  
    Local test record generator for standalone PL tests.

  - `top_stage3_timestamp.sv`  
    Stage-4 variant of the timestamp top (reused here as part of the harness).

  - `top_stage3_serial.sv`  
    Stage-4 top-level harness:
    - UART RX → record unpack → depth parser → ILA/monitored signals.

- `constr/`
  - `ax7015b_stage3_timestamp.xdc`  
    AX7015B clock/pin constraints used for the Stage-4 harness. Name is inherited; you can duplicate/rename if you want a Stage-4-specific filename.

- `ip/`
  - `ila_0/ila_0.xci`  
    ILA IP configuration used to capture parser inputs/outputs.

- `iladata.csv`  
  Example Vivado ILA CSV export for this stage.  
  Lines: **1,026** (header/radix rows + captured samples).  
  This capture is limited by the ILA depth of **1024** samples.

## What it does

- Receives fixed-size records over UART (via `uart_rx_serial` + `uart_record_axis_bridge`).
- Unpacks the records into typed fields (`event_record_unpack`).
- Parses these into `depth_event_t` (`binance_depth_parser`).
- Provides timestamp and latency measurement.
- Exposes internal signals to the ILA (`ila_0`).

You can run this alone as “Stage-4 PL bring-up” without Stage 1–3 present, as long as you feed it a UART stream in the expected format.

## Vivado (GUI) quick start

1. Create a new Vivado project (empty initially) targeting the AX7015B part/board.
2. Add design sources:
   - All files in `rtl/`.
3. Add constraints:
   - `constr/ax7015b_stage3_timestamp.xdc`.
4. Add IP:
   - Add `ip/ila_0/ila_0.xci` as IP, then “Generate Output Products”.
5. Set the top module for standalone Stage-4 bring-up:
   - `top_stage3_serial`
     (this is the Stage-4 UART + parser harness).
6. Run synthesis / implementation and generate a bitstream.
7. Program the AX7015B and:
   - Replay `binance_depth_tiny.log` from `sw_tools/` via UART.
   - Use ILA to capture a window of data.
   - Export the capture to CSV (`iladata.csv`) and use `sw_tools` to decode/compare.

## Notes

- Only source, constraints, ILA config, and one reference ILA CSV are kept in this folder.
- Vivado outputs (`*.runs/`, `.Xil/`, `.dcp`, generated bitstreams) should be kept out of Git.
- The ILA depth is 1024 samples, so only small inputs (tiny log) can be fully captured in one window; larger logs will produce partial captures only.