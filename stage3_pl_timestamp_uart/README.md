# Stage 3 — PL Timestamp + UART → AXI Bridge

Stage 3 implements on-FPGA timestamping and a UART→AXI-Stream bridge that feeds later stages.

Functions:

- 64-bit PL timestamp counter (`pl_timestamp_counter.sv`).
- Latency measurement (`latency_measure.sv`) between record arrival and downstream consumption.
- UART receiver for fixed-size records (`uart_rx_serial.sv` / `.v`).
- Record unpacker (`event_record_unpack.sv`).
- AXI-Stream bridge / recorder (`uart_record_axis_bridge.sv`).
- Simple test record generator (`test_record_gen.sv`).
- Top-level harnesses:
  - `top_stage3_timestamp.sv`: timestamping path.
  - `top_stage3_serial.sv`: UART receive + unpack + AXIS output.

## Layout

- `rtl/`
  - `top_stage3_timestamp.sv`
  - `top_stage3_serial.sv`
  - `pl_timestamp_counter.sv`
  - `latency_measure.sv`
  - `event_record_unpack.sv`
  - `uart_record_axis_bridge.sv`
  - `uart_rx_serial.sv`, `uart_rx_serial.v`
  - `test_record_gen.sv`
- `constr/`
  - `ax7015b_stage3_timestamp.xdc`: clock / pin constraints for AX7015B.
- `sim/`
  - `tb_stage3_timestamp.sv`: basic simulation harness (extend as needed).
- `ip/`
  - `ila_0/ila_0.xci`: ILA configuration for probing stream and timestamp signals.

## Vivado (GUI) quick start

1. Create a new project targeting the AX7015B part/board.
2. Add all `rtl/*.sv` and `rtl/*.v` as design sources.
3. Add constraints: `constr/ax7015b_stage3_timestamp.xdc`.
4. Add IP:
   - Add `ip/ila_0/ila_0.xci` as IP source and “Generate Output Products”.
5. Set the top module:
   - For timestamp testing: `top_stage3_timestamp`.
   - For UART path: `top_stage3_serial`.
6. Run synthesis/implementation and generate a bitstream.
7. Program the board and use ILA to observe timestamps and record flow.

## Notes

- Only source-level artefacts and `.xci` are in Git; Vivado build outputs are not tracked.
- The same XDC is reused in later PL stages; clone and adjust if you need stage-specific constraints.
- Parameters (clock frequency, UART baud, widths) are set in RTL; adjust and rebuild as needed.
