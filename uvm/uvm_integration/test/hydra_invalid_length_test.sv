class hydra_invalid_length_test extends uvm_test;
    `uvm_component_utils(hydra_invalid_length_test)

    hydra_integration_env m_env;
    function new(string name="hydra_invalid_length_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_invalid_length_seq seq;
        int mode_number;

        phase.raise_objection(this);

        if(!$value$plusargs("INVALID_MODE=%d",mode_number)||!(mode_number inside{2,3}))
            `uvm_fatal("TEST_CONFIG","Use +INVALID_MODE=2 or +INVALID_MODE=3")
        
        seq=hydra_invalid_length_seq::type_id::create("seq");
        seq.mode_number=mode_number;
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;
        seq.start(m_env.m_cpu_agent.m_sequencer);

        repeat(2) @(seq.cpu_vif.driver_cb);
        if(m_env.ram_read_fifo.used()!=0)
            `uvm_error("UNEXPECTED_RAM_READ",$sformatf("Observed %d RAM reads", m_env.ram_read_fifo.used()))

        if(m_env.scratch_write_fifo.used()!=0)
            `uvm_error("UNEXPECTED_SCRATCH_WRITE",$sformatf("Observed %0d scratchpad writes", m_env.scratch_write_fifo.used()))
        
        if(m_env.ram_read_fifo.used()==0 && m_env.scratch_write_fifo.used()==0)
            `uvm_info("NO_DATA_TRAFFIC","Invalid configuration caused no RAM reads or scratchpad writes",UVM_LOW)

        phase.drop_objection(this);
    endtask
endclass