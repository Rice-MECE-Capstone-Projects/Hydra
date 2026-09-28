# ASAP7 Flow - mmmc.tcl
# Created by Matthew Nutt (and Gemini)

# Define the constraints
create_constraint_mode -name sdc_constraints -sdc_files { ../constraints.sdc }

# Define timing libraries (.lib) as timing conditions
# CCS models instead of CCSA, to save memory and run time
create_library_set -name slow_lib \
    -timing {   asap7sc7p5t_AO_LVT_SS_ccs_211120.lib \
                asap7sc7p5t_AO_RVT_SS_ccs_211120.lib \
                asap7sc7p5t_AO_SLVT_SS_ccs_211120.lib \
                asap7sc7p5t_AO_SRAM_SS_ccs_211120.lib \
                asap7sc7p5t_INVBUF_LVT_SS_ccs_220122.lib \
                asap7sc7p5t_INVBUF_RVT_SS_ccs_220122.lib \
                asap7sc7p5t_INVBUF_SLVT_SS_ccs_220122.lib \
                asap7sc7p5t_INVBUF_SRAM_SS_ccs_220122.lib \
                asap7sc7p5t_OA_LVT_SS_ccs_211120.lib \
                asap7sc7p5t_OA_RVT_SS_ccs_211120.lib \
                asap7sc7p5t_OA_SLVT_SS_ccs_211120.lib \
                asap7sc7p5t_OA_SRAM_SS_ccs_211120.lib \
                asap7sc7p5t_SEQ_LVT_SS_ccs_220123.lib \
                asap7sc7p5t_SEQ_RVT_SS_ccs_220123.lib \
                asap7sc7p5t_SEQ_SLVT_SS_ccs_220123.lib \
                asap7sc7p5t_SEQ_SRAM_SS_ccs_220123.lib \
                asap7sc7p5t_SIMPLE_LVT_SS_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_RVT_SS_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_SLVT_SS_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_SRAM_SS_ccs_211120.lib }
create_timing_condition -name slow_condition -library_set slow_lib

create_library_set -name typical_lib \
    -timing {   asap7sc7p5t_AO_LVT_TT_ccs_211120.lib \
                asap7sc7p5t_AO_RVT_TT_ccs_211120.lib \
                asap7sc7p5t_AO_SLVT_TT_ccs_211120.lib \
                asap7sc7p5t_AO_SRAM_TT_ccs_211120.lib \
                asap7sc7p5t_INVBUF_LVT_TT_ccs_220122.lib \
                asap7sc7p5t_INVBUF_RVT_TT_ccs_220122.lib \
                asap7sc7p5t_INVBUF_SLVT_TT_ccs_220122.lib \
                asap7sc7p5t_INVBUF_SRAM_TT_ccs_220122.lib \
                asap7sc7p5t_OA_LVT_TT_ccs_211120.lib \
                asap7sc7p5t_OA_RVT_TT_ccs_211120.lib \
                asap7sc7p5t_OA_SLVT_TT_ccs_211120.lib \
                asap7sc7p5t_OA_SRAM_TT_ccs_211120.lib \
                asap7sc7p5t_SEQ_LVT_TT_ccs_220123.lib \
                asap7sc7p5t_SEQ_RVT_TT_ccs_220123.lib \
                asap7sc7p5t_SEQ_SLVT_TT_ccs_220123.lib \
                asap7sc7p5t_SEQ_SRAM_TT_ccs_220123.lib \
                asap7sc7p5t_SIMPLE_LVT_TT_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_RVT_TT_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_SLVT_TT_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_SRAM_TT_ccs_211120.lib }
create_timing_condition -name typical_condition -library_set typical_lib

create_library_set -name fast_lib \
    -timing {   asap7sc7p5t_AO_LVT_FF_ccs_211120.lib \
                asap7sc7p5t_AO_RVT_FF_ccs_211120.lib \
                asap7sc7p5t_AO_SLVT_FF_ccs_211120.lib \
                asap7sc7p5t_AO_SRAM_FF_ccs_211120.lib \
                asap7sc7p5t_INVBUF_LVT_FF_ccs_220122.lib \
                asap7sc7p5t_INVBUF_RVT_FF_ccs_220122.lib \
                asap7sc7p5t_INVBUF_SLVT_FF_ccs_220122.lib \
                asap7sc7p5t_INVBUF_SRAM_FF_ccs_220122.lib \
                asap7sc7p5t_OA_LVT_FF_ccs_211120.lib \
                asap7sc7p5t_OA_RVT_FF_ccs_211120.lib \
                asap7sc7p5t_OA_SLVT_FF_ccs_211120.lib \
                asap7sc7p5t_OA_SRAM_FF_ccs_211120.lib \
                asap7sc7p5t_SEQ_LVT_FF_ccs_220123.lib \
                asap7sc7p5t_SEQ_RVT_FF_ccs_220123.lib \
                asap7sc7p5t_SEQ_SLVT_FF_ccs_220123.lib \
                asap7sc7p5t_SEQ_SRAM_FF_ccs_220123.lib \
                asap7sc7p5t_SIMPLE_LVT_FF_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_RVT_FF_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_SLVT_FF_ccs_211120.lib \
                asap7sc7p5t_SIMPLE_SRAM_FF_ccs_211120.lib }
create_timing_condition -name fast_condition -library_set fast_lib

# Define the corners
create_rc_corner -name slow_rc -temperature 125
create_delay_corner -name slow_delay -timing_condition slow_condition -rc_corner slow_rc

create_rc_corner -name typical_rc -temperature 25
create_delay_corner -name typical_delay -timing_condition typical_condition -rc_corner typical_rc

create_rc_corner -name fast_rc -temperature -40
create_delay_corner -name fast_delay -timing_condition fast_condition -rc_corner fast_rc

# Bind everything into analysis views
create_analysis_view -name slow_view -delay_corner slow_delay -constraint_mode sdc_constraints
create_analysis_view -name typical_view -delay_corner typical_delay -constraint_mode sdc_constraints
create_analysis_view -name fast_view -delay_corner fast_delay -constraint_mode sdc_constraints

# Set the views for synthesis
# Note that hold is not actually supported by Genus, but let's leave it in for consistency
set_analysis_view -setup slow_view -hold fast_view -leakage typical_view -dynamic typical_view
