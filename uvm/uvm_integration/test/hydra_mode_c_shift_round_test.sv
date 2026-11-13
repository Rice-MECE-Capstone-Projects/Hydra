class hydra_mode_c_shift_round_test extends uvm_test;
    `uvm_component_utils(hydra_mode_c_shift_round_test)

    hydra_integration_env m_env;

    function new(string name="hydra_mode_c_shift_round_test",uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_c_shift_round_seq seq;
        phase.raise_objection(this);

        for(int i=0;i<8;i++)
            m_env.ram_model.write_word(32'h8000_0000+4*i,i);

        seq=hydra_mode_c_shift_round_seq::type_id::create("seq");
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;
        seq.start(m_env.m_cpu_agent.m_sequencer);

        phase.drop_objection(this);
    endtask
endclass

