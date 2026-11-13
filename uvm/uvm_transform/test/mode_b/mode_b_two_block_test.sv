class mode_b_two_block_test extends uvm_test;
    transform_env m_env;
    `uvm_component_utils(mode_b_two_block_test)

    function new(string name="mode_b_two_block_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_b_basic_seq seq;
        phase.raise_objection(this);

        seq=mode_b_basic_seq::type_id::create("seq");
        seq.transfer_length=256;

        // two 8*16 blocks; all 256 input values are distinct
        for(int i=0; i<256; i++)begin
            m_env.ram_model.write_word(seq.source_address+4*i,i+1);
        end

        seq.start(m_env.m_ctrl_agent.m_sequencer);

        // allow final monitor observations to reach the scoreboard
        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass