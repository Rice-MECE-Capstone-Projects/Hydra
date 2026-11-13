class mode_b_wait_state_test extends uvm_test;
    transform_env m_env;
    `uvm_component_utils(mode_b_wait_state_test)

    function new(string name="mode_b_wait_state_test",uvm_component parent=null);
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

        for(int i=0;i<256;i++)begin
            m_env.ram_model.write_word(seq.source_address+4*i,i+1);
        end

        // pause after the 128th accepted read, at the block boundary
        m_env.m_ram_agent.m_driver.wait_cycles_after_first_read=2;
        m_env.m_ram_agent.m_driver.stall_on_read_number=128;
        
        seq.start(m_env.m_ctrl_agent.m_sequencer);

        if(!m_env.m_ram_agent.m_driver.wait_injected)
            `uvm_error("WAIT_NOT_INJECTED","RAM wait states were not exercised")

        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass
