# ASAP7 Flow - genus.tcl
# Created by Matthew Nutt (and Gemini)
set PDK_DIR $env(PDK_DIR)
set_db common_ui true

# Set search paths for LIBs, LEFs, and RTL
set_db init_lib_search_path [list   $PDK_DIR/LIB/CCS/ \
                                    $PDK_DIR/LEF/scaled/ \
                                    $PDK_DIR/techlef_misc/ ]
set_db init_hdl_search_path ../../src/hydra/

# Set library LEFs, using the 4x scaled versions
set_db lef_library [list    asap7_tech_4x_201209.lef \
                            asap7sc7p5t_28_L_4x_220121a.lef \
                            asap7sc7p5t_28_R_4x_220121a.lef \
                            asap7sc7p5t_28_SL_4x_220121a.lef \
                            asap7sc7p5t_28_SRAM_4x_220121a.lef ]

# Read MMMC
read_mmmc ./mmmc.tcl

# Read RTL and elaborate
read_hdl -language sv { hydra_pkg.sv \
                        hydra_arbiter.sv \
                        hydra_mmr.sv \
                        hydra_scratchpad.sv \
                        hydra_transform.sv \
                        hydra_top.sv }
elaborate hydra_top

# Init design
init_design

# Check constraints
check_timing_intent

# Synthesize - first into generic gates, then into library gates, then optimize
syn_generic
syn_map
syn_opt

# Write outputs for Innovus - synthesized netlist and SDC constraints
write_hdl > ./out/top_synth.v
write_sdc -view view_typical > ./out/top_synth.sdc

# Generate reports
report_timing > ./rpt/timing.rpt
report_area   > ./rpt/area.rpt
report_power  > ./rpt/power.rpt
