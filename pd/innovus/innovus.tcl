# ASAP7 Flow - innovus.tcl
# Original from: https://github.com/Centre-for-Hardware-Security/tutorial_innovus/blob/main/scripts/innovus_step_by_step.tcl
# Modified by Matthew Nutt
set VERSION 25
set init_design_uniquify 1
set PDK_DIR /storage-home/m/mcn5/asap7_pdk_r1p7

# Configure Verilog inputs
# Set init_verilog to synthesized netlist
# Set init_top_cell to name of top cell in Verilog
set init_verilog {}
set init_top_cell {}
set init_design_netlisttype {Verilog}
set init_design_settop {1}

# Configure paths to LEF and Tech LEF files
# Using 4x scaled cells from ASAP7 PDK, due to limits on Innovus educational licenses
set TLEF_PATH "$PDK_DIR/asap7sc7p5t_28/techlef_misc"
set LEF_PATH "$PDK_DIR/asap7sc7p5t_28/LEF/scaled"
#set DB_PATH "../db/"

# Configure LEF files for the node and cell library
# NOTE: add SRAM LEF here or no?
set TECH_LEF "$TLEF_PATH/asap7_tech_4x_201209.lef"
set CELL_LEF "$LEF_PATH/asap7sc7p5t_28_L_4x_220121a.lef $LEF_PATH/asap7sc7p5t_28_SL_4x_220121a.lef $LEF_PATH/asap7sc7p5t_28_R_4x_220121a.lef"

# Tech LEF goes first, then cell LEFs
set init_lef_file "$TECH_LEF $CELL_LEF"

# Configure floorplan variables
set fp_core_cntl {aspect}
set fp_aspect_ratio {1.0000}
set extract_shrink_factor {1.0}
set init_assign_buffer {0}
set init_pwr_net {VDD}
set init_gnd_net {VSS}

# Configure timing libraries
# Empty CPF file since there's only one power domain
set init_cpf_file {}
# MMMC file sets constraints for the design
set init_mmmc_file {}

# Load the libraries and design, then suspend (can use resume to continue)
init_design
suspend
