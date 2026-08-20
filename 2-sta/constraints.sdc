create_clock -name clk -period 30.0 [get_ports clk]

set_input_delay  -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports cpu_enable]
