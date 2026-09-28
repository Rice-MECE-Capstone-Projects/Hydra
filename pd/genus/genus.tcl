# ASAP7 Flow - genus.tcl
# Created by Matthew Nutt (and Gemini)
set PDK_DIR /storage-home/m/mcn5/asap7_pdk_r1p7
set asap7sc7p5t $PDK_DIR/asap7sc7p5t_28
set_db common_ui true

# Set search paths for LIBs, LEFs, and RTL
set_db init_lib_search_path [list   $asap7sc7p5t/LIB/CCS/unzipped \
                                    $asap7sc7p5t/LEF/scaled/ \
                                    $asap7sc7p5t/techlef_misc/ ]
set_db init_hdl_search_path /storage-home/m/mcn5/elec422/snake/source/verilog/

# Set library LEFs, using the 4x scaled versions
set_db lef_library [list    asap7_tech_4x_201209.lef \
                            asap7sc7p5t_28_L_4x_220121a.lef \
                            asap7sc7p5t_28_R_4x_220121a.lef \
                            asap7sc7p5t_28_SL_4x_220121a.lef \
                            asap7sc7p5t_28_SRAM_4x_220121a.lef ]

# Read MMMC
read_mmmc ./mmmc.tcl

# Read RTL and elaborate
read_hdl -language v2001 { top.v controller.v logic.v prng.v }
elaborate top

# Init design
init_design

# Check constraints
check_timing_intent

# Enable power optimization - important for multi-Vt
#set_db max_leakage_power 0
#set_db lp_power_optimization_weight 1
#set_db leak_power_effort high

# Explicitly tag Vt categories
#set_db [get_libs *RVT*] .vt_type RVT
#set_db [get_libs *LVT*] .vt_type LVT
#set_db [get_libs *SLVT*] .vt_type SLVT

# Synthesize - first into generic gates, then into library gates, then optimize
# Use only RVT for the first syn_map pass, then allow Vt swaps during opt
#set_db [get_libs *LVT*] .dont_use true
#set_db [get_libs *SLVT*] .dont_use true
syn_generic
syn_map

#set_db [get_libs *LVT*] .dont_use false
#set_db [get_libs *SLVT*] .dont_use false
syn_opt

# Write outputs for Innovus - synthesized netlist and SDC constraints
write_hdl > ./out/top_synth.v
write_sdc -view view_typical > ./out/top_synth.sdc

# Generate reports
report_timing > ./rpt/timing.rpt
report_area   > ./rpt/area.rpt
report_power  > ./rpt/power.rpt
#report_leakage_power -by_vt_type > ./rpt/power_leakage_vt.rpt
