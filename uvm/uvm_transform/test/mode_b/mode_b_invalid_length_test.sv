class mode_b_invalid_length_test extends uvm_test;
    transform_env m_env;
    `uvm_component_utils(mode_b_invalid_length_test)

    function new(string name="mode_b_invalid_length_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_b_basic_seq seq;
        int unsigned test_length;

        phase.raise_objection(this);

        // default case: 64. Use +B06_LENGTH=0 for the other case.
        if(!$value$plusargs("B06_LENGTH=%d",test_length))
            test_length=0;

        if(test_length!=0&&test_length!=64)
            `uvm_fatal("B06_LENGTH","Run B06 with length 0 or 64")

        m_env.m_ctrl_agent.m_driver.expect_error=1'b1;
        m_env.m_scoreboard.expect_invalid_length=1'b1;

        seq=mode_b_basic_seq::type_id::create("seq");
        seq.transfer_length=test_length;
        seq.start(m_env.m_ctrl_agent.m_sequencer);

        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass