class mode_b_basic_test extends uvm_test;
    transform_env m_env;
    `uvm_component_utils(mode_b_basic_test)

    function new(string name="mode_b_basic_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_b_basic_seq seq;
        phase.raise_objection(this);

        // One 8x16 block; every input position has a distinct value
        for(int i=0; i<128; i++)begin
            m_env.ram_model.write_word(32'h8000_0000+4*i,i+1);
        end

        seq=mode_b_basic_seq::type_id::create("seq");
        seq.start(m_env.m_ctrl_agent.m_sequencer);

        // Allow final monitor observations to reach the scoreboard
        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass