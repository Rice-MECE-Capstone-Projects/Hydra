package hydra_integration_pkg;
    import uvm_pkg::*;
    import hydra_pkg::*;
    import hydra_uvm_pkg::*;
    import transform_pkg::*;

    `include "uvm_macros.svh"
    `include "../coverage/hydra_integration_coverage.sv"
    `include "../env/hydra_integration_env.sv"

    `include "../sequence/hydra_mode_c_basic_seq.sv"
    `include "../sequence/hydra_mode_b_basic_seq.sv"
    `include "../sequence/hydra_mode_c_shift_round_seq.sv"
    `include "../sequence/hydra_mode_c_signed_unsigned_seq.sv"
    `include "../sequence/hydra_mode_b_two_block_seq.sv"
    `include "../sequence/hydra_invalid_length_seq.sv"
    `include "../sequence/hydra_mode_c_to_b_seq.sv"
    `include "../sequence/hydra_mode_c_random_seq.sv"
    `include "../sequence/hydra_mode_b_random_seq.sv"
    
    `include "../test/hydra_mode_c_basic_test.sv"
    `include "../test/hydra_mode_b_basic_test.sv"
    `include "../test/hydra_mode_c_shift_round_test.sv"
    `include "../test/hydra_mode_c_signed_unsigned_test.sv"
    `include "../test/hydra_mode_b_two_block_test.sv"
    `include "../test/hydra_invalid_length_test.sv"
    `include "../test/hydra_mode_c_to_b_test.sv"
    `include "../test/hydra_mode_c_random_test.sv"
    `include "../test/hydra_mode_b_random_test.sv"
endpackage
