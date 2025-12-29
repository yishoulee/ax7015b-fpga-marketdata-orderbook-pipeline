# Phase 2: Integrated CDC + Timing Demo (inside trading infra)

Status: WIP=1 (each day ends with reproducible artifact + evidence)

Location in repo:
- stage7_ps_pl_stream/phase2_cdc_timing_demo/
- Uses the existing Stage-7 PS->PL stream boundary (not a separate project).

## Goal
Harden the real PS->PL stream boundary used by this trading infra with:
- A real two-clock structure
- Correct CDC primitives (stream + control)
- Clean timing/CDC reports committed as evidence
- Deterministic replay proof while clocks differ

## What changed in the actual datapath
### Clocks
- clk_src: PS->PL stream clock (FCLK_CLK0) = [TODO: e.g. 100 MHz]
- clk_proc: processing pipeline clock (FCLK_CLK1) = [TODO: e.g. 150 MHz]

### CDC strategy
1) Stream CDC (multi-bit, high throughput):
- Insert AXI4-Stream Clock Converter (async) on the exact PS->PL AXIS boundary:
  - s_axis_aclk = clk_src
  - m_axis_aclk = clk_proc
- No ad-hoc sampling of multi-bit AXIS payload across domains.

2) Control CDC (single-bit flags crossing domains):
- enable/mode/kill flags:
  - Use XPM 2FF sync (single-bit level) OR XPM handshake/pulse CDC as appropriate.
- No multi-bit config bus is sampled without handshake.

## Repo outputs (the evidence artifacts)
This folder contains the reproducible evidence required for Phase 2.

### Reports (commit these)
- stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/timing_summary.rpt
- stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/clock_interaction.rpt
- stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/cdc.rpt

### Replay proof logs (commit these)
- stage7_ps_pl_stream/phase2_cdc_timing_demo/logs/replay_run1_[clk_src]_[clk_proc].txt
- stage7_ps_pl_stream/phase2_cdc_timing_demo/logs/replay_run2_[clk_src]_[clk_proc].txt

Expected: identical counters across runs (and no corruption/drops):
- events_in
- drops
- checksum32
- last_seq
(Replace with the exact counters your system prints.)

## How to reproduce (end-to-end)
### Prerequisites
- Vivado version: [TODO: e.g. 2025.x]
- Board: AX7015B (Zynq-7015)
- XSA/bitstream flow: [TODO: describe briefly if needed]
- Host tools (if any): [TODO: e.g. xsct, scp, python3]

### 1) Build the Stage-7 Vivado design (with CDC integrated)
Open the existing Stage-7 project and generate bitstream:
- Vivado project path: [TODO: stage7_ps_pl_stream/.../vivado/<project>.xpr]
- Block design name: [TODO]
- The AXIS clock converter instance name: [TODO]
- Confirm both clocks exist and are used:
  - clk_src drives upstream AXIS source side
  - clk_proc drives downstream pipeline side

### 2) Generate timing + CDC reports (batch, reproducible)
Run:
```bash
vivado -mode batch -source stage7_ps_pl_stream/phase2_cdc_timing_demo/scripts/gen_reports.tcl
```