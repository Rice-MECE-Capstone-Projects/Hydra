class hydra_mode_c_to_b_test extends uvm_test;
    `uvm_component_utils(hydra_mode_c_to_b_test)

    hydra_integration_env m_env;

    function new(string name="hydra_mode_c_to_b_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_c_to_b_seq seq;
        phase.raise_objection(this);

        for(int i=0;i<4;i++)
            m_env.ram_model.write_word(32'h8000_0000+4*i,i+1);
        
        for(int i=0;i<128;i++)
            m_env.ram_model.write_word(32'h8000_0100+4*i,i+1);
        
        seq=hydra_mode_c_to_b_seq::type_id::create("seq");
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;
        seq.start(m_env.m_cpu_agent.m_sequencer);

        repeat (2) @(seq.cpu_vif.driver_cb);

        if(m_env.ram_read_fifo.used()!=132)
            `uvm_error("RAM_COUNT",$sformatf("Expected 129 writes, got %0d",m_env.scratch_write_fifo.used()))
        phase.drop_objection(this);
    endtask
endclass
