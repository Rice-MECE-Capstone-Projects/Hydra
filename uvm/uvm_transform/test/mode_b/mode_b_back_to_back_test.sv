class mode_b_back_to_back_test extends uvm_test;
    transform_env m_env;
    `uvm_component_utils(mode_b_back_to_back_test)

    function new(string name="mode_b_back_to_back_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_b_basic_seq seq1,seq2;
        phase.raise_objection(this);

        seq1=mode_b_basic_seq::type_id::create("seq1");
        seq1.transfer_length=128;
        seq1.source_address=32'h8000_0000;
        seq1.destination_address=32'h0000_0000;

        seq2=mode_b_basic_seq::type_id::create("seq2");
        seq2.transfer_length=128;
        seq2.source_address=32'h8000_0200;
        seq2.destination_address=32'h0000_0200;

        for(int i=0; i<128;i++)begin
            m_env.ram_model.write_word(seq1.source_address+4*i,i+1);
            m_env.ram_model.write_word(seq2.source_address+4*i,32'h0000_1000+i);
        end

        seq1.start(m_env.m_ctrl_agent.m_sequencer);
        // allow the first completion indication to clear before START #2
        repeat (2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);

        seq2.start(m_env.m_ctrl_agent.m_sequencer);
        repeat (2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);

        phase.drop_objection(this);
    endtask
endclass
