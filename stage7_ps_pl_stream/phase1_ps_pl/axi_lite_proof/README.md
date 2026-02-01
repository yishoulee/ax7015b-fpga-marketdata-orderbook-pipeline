# Phase 1 – Day 1: PS/PL AXI-Lite Proof (LED + Counter)

Date: 2025-12-17

This folder contains the Day 1 proof that the Zynq PS can reliably control and observe PL logic through an AXI4-Lite register block.

Outcome:
- PS writes toggle a PL LED via AXI-Lite register `reg0`.
- PS reads a free-running PL counter via AXI-Lite register `reg1`.
- Verified using XSCT over JTAG (no Linux required).

## What was built

A custom AXI4-Lite slave IP in PL with:
- `reg0[0]` -> `led_out` (drives a board PL LED)
- `reg1` -> read-only mirror of a free-running counter

Block design (`design_1.bd`) includes:
- `processing_system7_0` (Zynq PS)
- AXI GP0 path to PL (`M_AXI_GP0`)
- AXI clocking driven from `FCLK_CLK0`
- `proc_sys_reset` providing synchronized active-low resets
- `dcm_locked` tied to constant `1` (required because no clocking wizard lock signal is used)  
  Reference: [Processor System Reset IP](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/proc_sys_reset.html)

## Address map

Base address assigned by Vivado Address Editor:
- `BASE = 0x43C00000`

Registers:
- `0x43C00000` (`BASE + 0x00`): `reg0` (RW)
  - bit0: LED control (`1` = on, `0` = off)
- `0x43C00004` (`BASE + 0x04`): `reg1` (RO)
  - free-running counter (increments continuously)

## Constraints (XDC)

Bitstream generation requires the external LED port to have:
- A physical pin location (`PACKAGE_PIN`)
- An I/O standard (`IOSTANDARD`)

The actual top-level port name created by Vivado in this design is:
- `led_out_0`

Example constraint:

```tcl
set_property PACKAGE_PIN A5 [get_ports {led_out_0}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out_0}]
```

Pin selection depends on which AX7015B PL LED you want to use.

## How to reproduce

### 1) Build the bitstream in Vivado

* Open the project and block design.
* Validate Design.
* Run Implementation.
* Generate Bitstream.

### 2) Program the FPGA

Program the PL with the generated `.bit` via Vivado Hardware Manager (JTAG).

### 3) Verify PS/PL access using XSCT (no Linux)

Open XSCT and run:

```tcl
connect
targets
targets -set 2  ;# ARM Cortex-A9 MPCore #0

# LED on/off (reg0)
mwr 0x43C00000 0x00000001
mwr 0x43C00000 0x00000000

# Counter read twice (reg1)
mrd 0x43C00004
mrd 0x43C00004
```

Expected:

* LED visibly turns on and off.
* The second `mrd` returns a larger value than the first.

Observed on Day 1:

* LED toggles correctly.
* Counter increments:

  * `0x43C00004: 0x6F9C71AF`
  * `0x43C00004: 0x6FA36EF8`

## Notes / gotchas (things that actually mattered)

1. Do not edit BD-generated wrapper files (e.g. `myip_0.v`).

   * Those are regenerated. Edit the IP sources, then re-package.

2. After adding a new IP port (e.g. `led_out`), it must be merged into the packaged IP metadata.

   * In IP Packager: update/merge ports, then Re-Package IP.
   * Back in the main project: upgrade/refresh the IP and regenerate BD output products.

3. AXI-Lite clock must come from a valid clock source.

   * Use `processing_system7_0/FCLK_CLK0` to drive:

     * `processing_system7_0/M_AXI_GP0_ACLK`
     * AXI interconnect clocks (if present)
     * `myip_0/s00_axi_aclk`
     * `proc_sys_reset_0/slowest_sync_clk`

4. `proc_sys_reset/dcm_locked` must be driven high if you are not using a DCM/MMCM lock signal.

   * Tied to constant `1` in this design.
     Reference: [Processor System Reset IP](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/proc_sys_reset.html)

## References

* Zynq-7000 Technical Reference Manual (clock/reset + AXI GP context): [UG585](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM)
* Processor System Reset IP: [proc_sys_reset](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/proc_sys_reset.html)
* Vivado pin/property constraints (PACKAGE_PIN / IOSTANDARD): [UG912](https://docs.amd.com/r/en-US/ug912-vivado-properties/PACKAGE_PIN)
