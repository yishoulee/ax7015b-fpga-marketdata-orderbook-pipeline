# Stage 6 — Stateless Kernel and Risk Control (PL)

This stage hosts a simple stateless trading kernel and risk limiter in PL, consuming book/market data from earlier stages and producing strategy outputs.

## Layout
- `rtl/`
  - `strategy_kernel_simple.sv`: basic strategy kernel.
  - `risk_limiter_simple.sv`: simple risk control.
  - Reused depth/book/type modules from earlier stages as needed.
- `constr/`
  - `ax7015b_stage3_timestamp.xdc`: board/pin/clock constraints (update for your design).
- `ip/`
  - `ila_0/ila_0.xci`: ILA IP config for on-chip debug.
- `sim/`
  - (Place simulation testbenches here.)

## Vivado (GUI) quick start
1. Create a new project targeting your board/part.
2. Add design sources: all files in `rtl/`.
3. Add constraints: `constr/*.xdc`.
4. Add IP: `ip/ila_0/ila_0.xci` and generate output products.
5. Set your top module, e.g. `top_stage6_strategy`.
6. Run synthesis/implementation and generate bitstream.

## Notes
- Only source/config artifacts are tracked; Vivado outputs remain untracked.
- Expand this stage with more complex strategies or additional risk checks as needed.
