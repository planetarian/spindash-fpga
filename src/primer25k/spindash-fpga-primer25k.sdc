//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.9.03  Education (64-bit)
//Created Time: 2024-09-23 23:46:29
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
create_generated_clock -name clk_jt -source [get_ports {clk}] -master_clock clk -divide_by 27 -multiply_by 29 -duty_cycle 50 [get_pins {pll/PLLA_inst/CLKOUT0}]
create_generated_clock -name cen -source [get_pins {pll/PLLA_inst/CLKOUT0}] -master_clock clk_jt -divide_by 6 [get_nets {clk_jt_div6}]
create_generated_clock -name clk_en -source [get_pins {pll/PLLA_inst/CLKOUT0}] -master_clock clk_jt -divide_by 36 [get_regs {u_div/clk_en_s0}]
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
