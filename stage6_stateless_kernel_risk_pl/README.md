# Stage 6 — Stateless Strategy Kernel and Risk Control (PL)

Stage 6 is a **standalone** PL stage. It hosts a simple stateless trading strategy kernel plus a basic risk limiter. It is designed to be driven by best-of-book outputs from Stage 5, but all required RTL is copied here so you can build and test Stage 6 in isolation.

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