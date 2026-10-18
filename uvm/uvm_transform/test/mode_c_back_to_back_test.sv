class mode_c_back_to_back_test extends uvm_test;
    `uvm_component_utils(mode_c_back_to_back_test)

    transform_env m_env;

    function new(string name="mode_c_back_to_back_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env = transform_env::type_id::create("m_env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_c_basic_seq first_seq;
        mode_c_basic_seq second_seq;

        phase.raise_objection(this);

        // First operation: 1, 2, 3, 4 -> 0x04030201 at address 0
        m_env.ram_model.write_word(32'h8000_0000, 32'h0000_0001);
        m_env.ram_model.write_word(32'h8000_0004, 32'h0000_0002);
        m_env.ram_model.write_word(32'h8000_0008, 32'h0000_0003);
        m_env.ram_model.write_word(32'h8000_000C, 32'h0000_0004);

        // Second operation: 5, 6, 7, 8 -> 0x08070605 at address 0x100
        m_env.ram_model.write_word(32'h8000_0100, 32'h0000_0005);
        m_env.ram_model.write_word(32'h8000_0104, 32'h0000_0006);
        m_env.ram_model.write_word(32'h8000_0108, 32'h0000_0007);
        m_env.ram_model.write_word(32'h8000_010C, 32'h0000_0008);

        first_seq = mode_c_basic_seq::type_id::create("first_seq");
        first_seq.transfer_length = 4;
        first_seq.source_address = 32'h8000_0000;
        first_seq.destination_address = 32'h0000_0000;
        first_seq.start(m_env.m_ctrl_agent.m_sequencer);

        // Let DONE clear before issuing another START; do not reset the DUT.
        repeat (2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);

        second_seq = mode_c_basic_seq::type_id::create("second_seq");
        second_seq.transfer_length = 4;
        second_seq.source_address = 32'h8000_0100;
        second_seq.destination_address = 32'h0000_0100;
        second_seq.start(m_env.m_ctrl_agent.m_sequencer);

        repeat (2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass