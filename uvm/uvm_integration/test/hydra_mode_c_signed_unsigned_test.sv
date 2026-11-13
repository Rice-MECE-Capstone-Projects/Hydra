class hydra_mode_c_signed_unsigned_test extends uvm_test;
    `uvm_component_utils(hydra_mode_c_signed_unsigned_test)

    hydra_integration_env m_env;

    function new(string name="hydra_mode_c_signed_unsigned_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_c_signed_unsigned_seq seq;
        int signed_arg; // 0 or 1

        if(!$value$plusargs("SIGNED_OUT=%d",signed_arg))
            `uvm_fatal("TEST_CONFIG","Specify +SIGNED_OUT=0 or +SIGNED_OUT=1")
        
        if(signed_arg!=0 && signed_arg!=1)
            `uvm_fatal("TEST_CONFIG","SIGNED_OUT must be 0 or 1")

        phase.raise_objection(this);

        m_env.ram_model.write_word(32'h8000_0000,32'h0000_007F);
        m_env.ram_model.write_word(32'h8000_0004,32'h0000_0080);
        m_env.ram_model.write_word(32'h8000_0008,32'h0000_00FF);
        m_env.ram_model.write_word(32'h8000_000C,32'h0000_0100);

        seq=hydra_mode_c_signed_unsigned_seq::type_id::create("seq");
        seq.signed_output=signed_arg[0];
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;
        seq.start(m_env.m_cpu_agent.m_sequencer);

        phase.drop_objection(this);
    endtask
endclass