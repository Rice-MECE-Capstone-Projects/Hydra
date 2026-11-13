class hydra_mode_c_basic_test extends uvm_test;
    `uvm_component_utils(hydra_mode_c_basic_test)

    hydra_integration_env m_env;

    function new(string name="hydra_mode_c_basic_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_c_basic_seq seq;
        phase.raise_objection(this);

        for(int i=0;i<4;i++)
            m_env.ram_model.write_word(32'h8000_0000+4*i,i+1);

        seq=hydra_mode_c_basic_seq::type_id::create("seq");
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;

        if($test$plusargs("RAM_WAIT"))
            m_env.m_ram_agent.m_driver.wait_cycles_after_first_read=2;
        seq.start(m_env.m_cpu_agent.m_sequencer);
        if($test$plusargs("RAM_WAIT")&&!m_env.m_ram_agent.m_driver.wait_injected)
            `uvm_error("WAIT_NOT_INJECTED","RAM wait state was not inserted")
        
        phase.drop_objection(this);
    endtask
endclass

