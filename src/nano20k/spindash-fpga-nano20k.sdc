//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.9.03  Education (64-bit)
//Created Time: 2024-09-05 05:57:18
create_clock -name baseCLK -period 20 -waveform {0 10} [get_ports {clk}]
