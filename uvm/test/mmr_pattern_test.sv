class mmr_pattern_test extends uvm_test;
    `uvm_component_utils(mmr_pattern_test)

    mmr_env m_env;

    function new(string name="mmr_pattern_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=mmr_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mmr_pattern_sequence seq;
        phase.raise_objection(this);

        seq=mmr_pattern_sequence::type_id::create("seq");
        seq.start(m_env.m_agent.m_sequencer);

        phase.drop_objection(this);
    endtask
endclass
