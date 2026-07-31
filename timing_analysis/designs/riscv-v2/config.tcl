set ::env(DESIGN_NAME) "core_riscv_cacheless"

# Grab both SV (RTL) and V (Yosys synthesized)
set ::env(VERILOG_FILES) "[glob $::env(DESIGN_DIR)/../../*.sv] [glob $::env(DESIGN_DIR)/../../*.v]"

set ::env(PDK) "sky130A"
set ::env(CLOCK_PERIOD) "10"
set ::env(CLOCK_NET) "clk"
set ::env(CLOCK_PORT) "clk"

set ::env(DIE_AREA) "0 0 500 500"
set ::env(CORE_UTILIZATION) "40"
set ::env(PLACEMENT_DENSITY) "0.55"
set ::env(RUN_OPENSTA) "1"