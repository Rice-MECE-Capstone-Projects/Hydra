# ASAP7 Flow - genus.tcl
# Created by Matthew Nutt (and Gemini)
set PDK_DIR $env(PDK_DIR)
set_db common_ui true

# Set search paths for LIBs, LEFs, and RTL
set_db init_lib_search_path [list   $PDK_DIR/asap7sc7p5t_28/LIB/CCS/ \
                                    $PDK_DIR/asap7sc7p5t_28/LEF/scaled/ \
                                    $PDK_DIR/asap7sc7p5t_28/techlef_misc/ \
                                    $PDK_DIR/asap7_sram_0p0/generated/LIB/ \
                                    $PDK_DIR/asap7_sram_0p0/generated/LEF/4xLEF/ ]
set_db init_hdl_search_path [list   ../../src/hydra/ \
                                    ../../wally/src/ \
                                    ../../wally/config/shared/ \
                                    ../../wally/config/rv32gc/ ]

# Read MMMC
read_mmmc ./mmmc.tcl

# Read LEFs, using the 4x scaled versions
# The cell LEFs will evoke a warning about duplicated sites - ignore this
# The sites should be identical, and it's still necessary to read all files for other information
# TODO: add specific SRAM LEFs here?
read_physical -lefs [list   asap7_tech_4x_201209.lef \
                            asap7sc7p5t_28_R_4x_220121a.lef \
                            asap7sc7p5t_28_L_4x_220121a.lef \
                            asap7sc7p5t_28_SL_4x_220121a.lef \
                            asap7sc7p5t_28_SRAM_4x_220121a.lef ]

# Read RTL and elaborate
read_hdl -language sv -f rtl_list.f
#elaborate wallypipelinedsoc
elaborate hydra_top

# # Fetch all instances directly from the module object
# set module_name "*ram*p1rw*e*"
# set module_instances [get_db [get_db modules $module_name] .instances]

# # Iterate through each instance and print its assigned parameters
# foreach inst $module_instances {

#     # Print instance and the module that it's an instance of
#     puts "Instance: [get_db $inst .name]"
#     set inst_module [get_db [lindex $module_instances 0] .module]
#     puts "  Module: [get_db $inst_module .name]"
    
#     # Get all module params and print them (there may or may not be parameters)
#     set module_params [get_db $inst_module .hdl_parameters]
#     foreach param $module_params {
#         set p_name  [lindex $param 0]
#         set p_value [lindex $param 1]
#         puts "  Parameter: $p_name = $p_value"
#     }
    
# }

# Init design
init_design

# Check constraints
check_timing_intent

# Synthesize - first into generic gates, then into library gates, then optimize
syn_generic
syn_map
syn_opt

# Use physical synthesis to get more accurate results for PnR
#set_db physical_aware_mapping true
#syn_generic -physical
#syn_map -physical
#syn_opt -physical

# Write outputs for Innovus - synthesized netlist and SDC constraints
write_hdl > ./out/top_synth.v
write_sdc -view typical_view > ./out/top_synth.sdc

# Generate reports
report_timing > ./rpt/timing.rpt
report_area   > ./rpt/area.rpt
report_power  > ./rpt/power.rpt
