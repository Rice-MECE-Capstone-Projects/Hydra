# ASAP7 Flow - constraints.sdc
# Created by Matthew Nutt (and Gemini)

# Clock definition (0.5 GHz)
# clk_port_name should match the name in the design
set clk_period 2000
set clk_name core_clock
set clk_port_name in_clka

# Create clock
set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

# Input/Output delays (20% of clock period as an example)
# Can get more detailed in the future
set_input_delay  [expr $clk_period * 0.2] -clock $clk_name [all_inputs]
set_output_delay [expr $clk_period * 0.2] -clock $clk_name [all_outputs]

# Drive strength and loads (optional basic load constraints)
set_load 0.002 [all_outputs]
