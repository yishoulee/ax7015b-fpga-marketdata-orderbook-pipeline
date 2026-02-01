# Phase 2: Integrated CDC + Timing Demo (inside trading infra)

Status: DONE (phase2 demo proven on hardware + committed timing/CDC evidence)

Location in repo:
- `stage7_ps_pl_stream/phase2_cdc_timing_demo/`
- This is Phase-2 “hardening” work: CDC + timing discipline for the PS->PL streaming boundary used in this repo.

## Goal

Harden the PS->PL stream boundary with:
- A real two-clock structure
- Correct CDC primitives (stream + control)
- Clean timing/CDC evidence committed
- Deterministic proof on hardware while clocks differ

## Summary of the proven setup (evidence in reports/)

### Clocks (PS7 FCLK)
- `clk_src` = `FCLK_CLK0` = 100 MHz (10.000 ns)
- `clk_proc` = `FCLK_CLK1` = 125 MHz (8.000 ns)

### CDC strategy

1) Stream CDC (multi-bit, high throughput)
- Use an async AXI4-Stream CDC primitive (AXI4-Stream Clock Converter / XPM async FIFO inside it) on the exact stream boundary.
- No ad-hoc sampling of multi-bit `TDATA/TLAST/etc` across domains.

2) Control CDC (single-bit flags crossing domains)
- For single-bit enable/mode/kill flags:
  - Use 2FF sync for level signals, or XPM handshake/pulse CDC for pulses.
- Do not sample multi-bit config buses across domains without a handshake.

## Evidence artifacts in this folder

### Reports (committed as .txt exports)
These are generated from the implemented (Routed) design:

- `reports/timing_summary.txt`
  - `report_timing_summary` output (WNS/TNS summary + checks)
- `reports/clock_interaction.txt`
  - `report_clock_interaction` output (shows per-clock timing groups and cross-clock classification)
- `reports/cdc.txt`
  - `report_cdc` output (CDC endpoints classified Safe/Unsafe)

Expected (what “PASS” means):
- Intra-clock groups are Clean/Timed with positive slack.
- Cross-clock paths are handled as CDC (classified Ignored with CDC-style constraints), not timed as synchronous paths.
- CDC report shows 0 Unsafe / 0 Unknown.

### Scripts
- `scripts/fifo_loopback_smoke_min.tcl`
  - Minimal XSCT smoke test for FIFO loopback validation (used as on-hardware proof).
- (Optional) Any helper scripts used to generate the text report exports.

### Logs
Store your on-hardware proof logs under `logs/`:
- FIFO smoke test PASS logs from XSCT runs (with both clocks enabled and different).

If you have multiple runs, keep at least one PASS log for the 100/125 configuration.

### Minimal BD (diagnostic reproducer)
- `min_bd_fifo_loopback_singleclk/`
  - Minimal design used to isolate FIFO/stream behavior during bring-up and smoke testing.

## Results (from committed reports)

- Two clocks differ: 100 MHz / 125 MHz.
- Timing constraints met (positive slack in each timed group).
- CDC analysis shows endpoints are Safe (0 Unsafe / 0 Unknown).

## How to reproduce

### Prerequisites
- Vivado: v2025.1
- Board: AX7015B (Zynq-7015)
- Host tool: `xsct` (Vivado/Vitis install)

### 1) Build and program the bitstream
Open the Phase-2 design/project, build implementation, and program the PL bitstream.

### 2) Run the on-hardware FIFO smoke test (XSCT)
Run the minimal smoke test script and capture the output into a log file under `logs/`.

Example:
```bash
xsct stage7_ps_pl_stream/phase2_cdc_timing_demo/scripts/fifo_loopback_smoke_min.tcl -base <FIFO_BASE_ADDR>
```

PASS condition:

* RX receives the expected words and payload matches the TX pattern.

### 3) Generate the report exports (Vivado Tcl, implemented design)

In Vivado Tcl (with the project opened and `impl_1` implemented):

```tcl
open_run impl_1

report_timing_summary -max_paths 20 \
  -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/timing_summary.txt

report_clock_interaction \
  -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/clock_interaction.txt

report_cdc \
  -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/cdc.txt

report_exceptions \
  -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/exceptions.txt
```

Commit the updated report exports as the Phase-2 evidence bundle.

## References (vendor docs)

* AXI4-Stream Infrastructure: Clocking / clock conversion (PG085)
* Xilinx Parameterized Macros: XPM CDC (UG953)
* Vivado Constraints: False Paths / Exceptions (UG903)

(Links omitted here to keep repo README simple; see AMD docs by doc ID.)
