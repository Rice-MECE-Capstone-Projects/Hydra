//////////////////////////////////////////////////////////////////////////////////////////////////
// File: mode_c_basic_test.sv
//
// Author: Yulia Zhou
//
// Description:
// Tests one basic Mode C operation using four input words.
// Preloads RAM with 1, 2, 3, and 4, then starts the control sequence.
// The scoreboard checks the observed transfers and packed output.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class mode_c_basic_test extends uvm_test;
    transform_env m_env;
    `uvm_component_utils(mode_c_basic_test)

    function new(string name="mode_c_basic_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_c_basic_seq seq;

        phase.raise_objection(this);

        // preload four consecutive 32-bit input words
        m_env.ram_model.write_word(32'h8000_0000, 32'h0000_0001);
        m_env.ram_model.write_word(32'h8000_0004, 32'h0000_0002);
        m_env.ram_model.write_word(32'h8000_0008, 32'h0000_0003);
        m_env.ram_model.write_word(32'h8000_000C, 32'h0000_0004);
        /*m_env.ram_model.write_word(32'h8000_0010, 32'h0000_0005);
        m_env.ram_model.write_word(32'h8000_0014, 32'h0000_0006);*/
        

        seq=mode_c_basic_seq::type_id::create("seq");
        seq.start(m_env.m_ctrl_agent.m_sequencer);

        // allow final monitor observations to be published 
        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);

        endtask
endclass