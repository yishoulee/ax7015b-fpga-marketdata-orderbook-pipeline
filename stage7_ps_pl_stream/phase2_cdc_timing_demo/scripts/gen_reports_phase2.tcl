set script_dir [file dirname [file normalize [info script]]]

# scripts/ -> phase2_cdc_timing_demo/ -> phase7_ps_pl_stream/ -> (then) phase1_ps_pl/...
set xpr [file normalize [file join $script_dir .. .. .. phase1_ps_pl axi_lite_proof axi_lite_proof_vivado axi_lite_proof_vivado.xpr]]

if {![file exists $xpr]} {
  puts "ERROR: .xpr not found: $xpr"
  exit 1
}

open_project $xpr

# Ensure we are looking at implemented design
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1

file mkdir stage7_ps_pl_stream/phase2_cdc_timing_demo/reports

check_timing
report_timing_summary -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/timing_summary.txt
report_clock_interaction -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/clock_interaction.txt
report_cdc -file stage7_ps_pl_stream/phase2_cdc_timing_demo/reports/cdc.txt

exit
