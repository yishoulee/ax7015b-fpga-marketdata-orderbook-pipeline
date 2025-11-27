# Stage 5 — Single-Symbol PL Order Book

This stage implements a single-symbol order book in PL, consuming normalized depth events from Stage 4 and maintaining best bid/ask state.

## Layout
- `rtl/`
  - `pl_order_book.sv`: core order book implementation.
  - Reused depth/parser/type modules from earlier stages (imported into this project).
- `constr/`
  - `ax7015b_stage3_timestamp.xdc`: board/pin/clock constraints (rename/update as needed).
- `ip/`
  - `ila_0/ila_0.xci`: ILA IP config for debug.
- `sim/`
  - (Add testbenches here if you create them.)

## Vivado (GUI) quick start
1. Create a new project targeting AX7015B (or your chosen board/part).
2. Add design sources: all files in `rtl/`.
3. Add constraints: `constr/*.xdc`.
4. Add IP: `ip/ila_0/ila_0.xci` and generate output products.
5. Set your top (e.g., a system-level top that instantiates `pl_order_book`).
6. Synthesize, implement, and generate bitstream.

## Notes
- This repo tracks only sources, constraints, and XCI; all generated runs/gen/cache/.Xil are ignored via `.gitignore`.
- If you refine this stage further, consider adding a dedicated top-level module and testbench under `sim/`.
