# ASAP7 Flow - mmmc.tcl
# Created by Matthew Nutt (and Gemini)
set PDK_DIR $env(PDK_DIR)

# Define the library search path for LIBs
#set_db init_lib_search_path [list $PDK_DIR/LIB/CCS/unzipped ]

# Define timing libraries (.lib) as a timing condition
# CCSA (timing + power) models, TT corner
create_library_set -name typical_lib \
    -timing {   asap7sc7p5t_AO_LVT_TT_ccsa_211120.lib \
                asap7sc7p5t_AO_RVT_TT_ccsa_211120.lib \
                asap7sc7p5t_AO_SLVT_TT_ccsa_211120.lib \
                asap7sc7p5t_AO_SRAM_TT_ccsa_211120.lib \
                asap7sc7p5t_INVBUF_LVT_TT_ccsa_220122.lib \
                asap7sc7p5t_INVBUF_RVT_TT_ccsa_220122.lib \
                asap7sc7p5t_INVBUF_SLVT_TT_ccsa_220122.lib \
                asap7sc7p5t_INVBUF_SRAM_TT_ccsa_220122.lib \
                asap7sc7p5t_OA_LVT_TT_ccsa_211120.lib \
                asap7sc7p5t_OA_RVT_TT_ccsa_211120.lib \
                asap7sc7p5t_OA_SLVT_TT_ccsa_211120.lib \
                asap7sc7p5t_OA_SRAM_TT_ccsa_211120.lib \
                asap7sc7p5t_SEQ_LVT_TT_ccsa_220123.lib \
                asap7sc7p5t_SEQ_RVT_TT_ccsa_220123.lib \
                asap7sc7p5t_SEQ_SLVT_TT_ccsa_220123.lib \
                asap7sc7p5t_SEQ_SRAM_TT_ccsa_220123.lib \
                asap7sc7p5t_SIMPLE_LVT_TT_ccsa_211120.lib \
                asap7sc7p5t_SIMPLE_RVT_TT_ccsa_211120.lib \
                asap7sc7p5t_SIMPLE_SLVT_TT_ccsa_211120.lib \
                asap7sc7p5t_SIMPLE_SRAM_TT_ccsa_211120.lib }
create_timing_condition -name typical_condition -library_set typical_lib

# Define constraints modes
create_constraint_mode -name sdc_constraints -sdc_files { ../constraints.sdc }

# Define the corner (TT)
create_rc_corner -name typical_rc -temperature 25
create_delay_corner -name typical_delay -timing_condition typical_condition -rc_corner typical_rc

# Bind everything into an analysis view
create_analysis_view -name view_typical -delay_corner typical_delay -constraint_mode sdc_constraints
set_analysis_view -setup view_typical -hold view_typical -leakage view_typical -dynamic view_typical
