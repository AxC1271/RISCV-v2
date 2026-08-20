read_liberty /data/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog /data/core_riscv_cached_synth.v
link_design core_riscv_cached
read_sdc /data/constraints.sdc
report_wns
report_tns
report_checks -path_delay max -fields {slew cap input_pins} -digits 3
report_checks -path_delay max -group_path_count 5 -digits 3
report_checks -path_delay min -digits 3