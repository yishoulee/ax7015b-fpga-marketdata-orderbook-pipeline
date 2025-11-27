# Stage 4 — Depth Parsing & Normalization

Stage 4 contains two parts:

- `sw_tools/`: reference tools to replay logs over UART, decode ILA exports, and compare CPU vs FPGA outputs.
- `pl_depth_parser/`: synthesizable RTL for parsing packed depth events, plus ILA IP config and constraints.

## Structure
- `sw_tools/`
  - replay, compare, and decoder scripts; see its README for usage
- `pl_depth_parser/`
  - `rtl/` (SV/V sources), `constr/` (XDC), `ip/` (XCI only)

## Build notes
- Python: install `pyserial` and `pandas`; run scripts from `sw_tools/`.
- PL (Vivado): create a project, add `pl_depth_parser/rtl/*` as design sources, add `pl_depth_parser/constr/*.xdc`, add `pl_depth_parser/ip/ila_0/ila_0.xci` then “Generate Output Products”.

## Rationale
This layout keeps Stage 4 self-contained while separating software utilities from PL sources. It avoids cross-stage coupling and preserves any Stage 3–derived modifications used in Stage 4.
