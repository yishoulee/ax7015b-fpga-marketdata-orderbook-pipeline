# Stage 1 — AXI-Stream Loopback on AX7015B

Stage 1 is a pure-PL bring-up design for the AX7015B board. It validates:

- AXI-Stream source/sink wiring.
- A simple header-add transform in the AXI path.
- Clock/reset handling and basic simulation.

This stage does **not** use market data. It is a self-contained test harness to confirm that AXIS wiring and simple transforms work.

## Layout

- `rtl/`
  - `bram_axis_src.v`      : BRAM-backed AXI-Stream source.
  - `axis_test_src.v`      : Simple synthetic AXIS source (optional).
  - `axis_hdr_add.v`       : Adds a small header/marker into the AXIS stream.
  - `axis_sink.v`          : AXIS sink for observing data.
  - `reset_sync.v`         : Reset synchronizer.
  - `edge_pulse.v`         : Edge detector / pulse generator.
- `constr/`
  - `top.xdc`              : Clock / pin constraints for this simple bring-up design.
- `sim/`
  - `tb_axis_hdr_add.v`    : Testbench for `axis_hdr_add`.
  - `tb_axis_hdr_add_behav.wcfg` : Vivado waveform configuration.
- `ip/`
  - `payload_1k_32b.coe`   : BRAM initialization file for the AXIS payload.
- `bd/`
  - `design_1.bd`          : Vivado block design tying the blocks together and exposing pins.

## Vivado notes

- Create a new project targeting the AX7015B part/board.
- Import `bd/design_1.bd` into a block-design project (or manually instantiate the RTL in a top module if you prefer).
- Add `rtl/*.v` as design sources.
- Add `constr/top.xdc` as the constraint file.
- When you create a BRAM IP in Vivado, you can point it at `ip/payload_1k_32b.coe` for the initial payload contents.
- There is no ILA IP tracked for Stage 1. If you want ILA/VIO here, create the IP in your local Vivado project; do not commit the generated outputs.

This stage is intentionally minimal and source-only; the Vivado project (`.xpr`), IP outputs, and build artefacts are regenerated locally and not stored in Git.
