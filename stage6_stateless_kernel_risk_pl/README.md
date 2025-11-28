# Stage 6 — Stateless Strategy Kernel and Risk Control (PL)

Stage 6 is the first **integration stage** of this project.

It functionally combines:
- UART depth record ingest and framing (as in Stage 2),
- record unpack and timestamping (as in Stage 3),
- depth event parsing (Stage 4),
- single-symbol order book best bid/ask (Stage 5),
- plus a stateless imbalance strategy and a simple risk limiter.

All required RTL is kept locally under `stage6_stateless_kernel_risk_pl/rtl/`,
so Stage 6 remains a standalone Vivado project even though it integrates the
logic of the earlier stages.

## Quick reproduction

1. Build and program Stage 6 bitstream in Vivado with `top_stage6_strategy`.
2. On the host, replay the tiny depth log over UART:

   cd stage2_feed_replay
   make replay LOG=../stage4_depth/sw_tools/binance_depth_tiny.log \
        MODE=realtime UART=/dev/ttyUSB0 BAUD=115200

3. Export the ILA capture as `scripts/stage6_ila_tiny.csv`.

4. From `stage6_stateless_kernel_risk_pl/scripts`:

   python stage6_actions_compare.py

The script prints CPU and FPGA action counts and a match ratio
(first action currently: 1.000 match ratio).

## Layout

- `rtl/`
  - `strategy_kernel_simple.sv`:
    - Stateless strategy based on bid/ask imbalance.
    - Input:
      - `best_bid_price`, `best_bid_qty`
      - `best_ask_price`, `best_ask_qty`
      - optional `book_ready` or equivalent.
    - Output:
      - `strat_valid`, `strat_side`, `strat_price`, `strat_qty`.
  - `risk_limiter_simple.sv`:
    - Simple risk control around the raw strategy outputs.
    - Takes `strat_*` and enforces basic size/side limits before emitting final actions.
  - Shared RTL imported from earlier stages as needed (types, helpers).
  - `top_stage6_strategy.sv`:
    - Stage-6 top-level integrating book inputs and risk-checked outputs.
- `constr/`
  - `ax7015b_stage3_timestamp.xdc`:
    - Reused AX7015B constraints from Stage 3 (clock, reset, IO).
    - Clone and edit for Stage 6 if your IO set differs.
- `ip/`
  - `ila_0/ila_0.xci`:
    - ILA configuration to probe book inputs and strategy outputs.
- `sim/`
  - Add testbenches here if you simulate the strategy in isolation.

## Vivado (GUI) quick start

1. Create a new project targeting AX7015B.
2. Add design sources: all `rtl/*.sv` required by `top_stage6_strategy.sv`.
3. Add constraints: `constr/ax7015b_stage3_timestamp.xdc` or a Stage-6-specific copy.
4. Add IP: `ip/ila_0/ila_0.xci` and generate output products if you want ILA probing.
5. Set the top module to `top_stage6_strategy`.
6. Run synthesis/implementation and generate a bitstream.

## Notes

- Strategy and risk logic are intentionally simple; you can replace `strategy_kernel_simple` and `risk_limiter_simple` with more complex modules without changing the stage structure.
- Only source/config artefacts are tracked; do not commit Vivado outputs.

## Verification

Stage 6 is checked against a CPU reference using a fixed tiny Binance depth log.

- `scripts/depth_cpu_normalizer.py` builds a fixed-point order book and depth events.
- `scripts/stage6_actions_compare.py`:
  - replays `scripts/binance_depth_tiny.log` into the CPU model,
  - decodes Stage 6 ILA captures (`stage6_ila_tiny_*.csv`) into scaled price/qty,
  - compares CPU vs FPGA strategy outputs `(side, price_fp, qty_fp)`.

Due to ILA depth vs UART speed, the current capture only contains a single
`strat_valid` pulse. The compare script reports:

- CPU actions: 49
- FPGA actions: 1
- Match ratio: 1.000 (first FPGA action == first CPU action)

This gives a deterministic sanity check that the Stage 6 strategy kernel
is wired and scaled consistently between CPU and FPGA.
