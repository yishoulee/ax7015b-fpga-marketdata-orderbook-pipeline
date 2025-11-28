# Stage 5 — Single-Symbol Order Book (PL)

Stage 5 implements a simple single-symbol order book on the FPGA. It consumes normalized depth events from Stage 4 and maintains best bid/ask and quantities.

The design is intentionally limited (no full depth ladder), but sufficient to demonstrate a working book and feed a strategy kernel.

## Layout

- `rtl/`
  - `pl_order_book.sv`:
    - Core order book implementation.
    - Input:
      - `depth_valid`
      - `binance_depth_types::depth_event_t depth_ev`
    - Outputs:
      - `best_bid_price`, `best_bid_qty`
      - `best_ask_price`, `best_ask_qty`
      - optional book-ready flag(s).
  - Shared RTL imported from earlier stages:
    - `binance_depth_types.sv`
    - `event_record_types.sv`
    - `event_record_unpack.sv`
    - `latency_measure.sv`, `pl_timestamp_counter.sv` (if reused)
    - `uart_rx_serial.sv` etc., depending on your top.
  - `top_stage5_orderbook.sv`:
    - Stage-5 top-level harness connecting parser output into `pl_order_book` and exposing book outputs.
- `constr/`
  - `ax7015b_stage3_timestamp.xdc`:
    - Reused AX7015B clock/IO constraints from Stage 3.
    - Duplicate/rename if you want a dedicated Stage-5 XDC.
- `ip/`
  - `ila_0/ila_0.xci`:
    - ILA configuration for probing book inputs/outputs.
- `sim/`
  - (Empty or user-defined testbenches; add simulation harnesses here if needed.)

## Vivado (GUI) quick start

1. Create a new project targeting the AX7015B.
2. Add design sources: all `rtl/*.sv` required by `top_stage5_orderbook.sv`:
   - `pl_order_book.sv`
   - `binance_depth_types.sv`, `event_record_types.sv`
   - Any shared Stage-3/4 RTL you instantiate.
3. Add constraints: `constr/ax7015b_stage3_timestamp.xdc` (or your cloned Stage-5 XDC).
4. Add IP: `ip/ila_0/ila_0.xci` and “Generate Output Products” if you want ILA.
5. Set the top module to `top_stage5_orderbook`.
6. Run synthesis/implementation and generate a bitstream.
7. Use ILA to verify that `depth_valid/depth_ev` update the best bid/ask outputs as expected.

## Notes

- This stage depends on the types defined in Stage 4 (`binance_depth_types.sv`).
- The same XDC is reused from earlier stages; if you need different pins/IO, clone and modify the file.