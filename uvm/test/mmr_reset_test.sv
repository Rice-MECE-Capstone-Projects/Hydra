class mmr_reset_test extends uvm_test;
    `uvm_component_utils(mmr_reset_test)

    function new (string name="mmr_reset_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    mmr_env m_env;
    virtual cpu_ahb_if vif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

    m_env=mmr_env::type_id::create("m_env",this);

    if(!uvm_config_db#(virtual cpu_ahb_if)::get(this,"","vif",vif))begin
        `uvm_fatal("NO_VIF","Interface was not found")
    end
    endfunction

    virtual task run_phase(uvm_phase phase);
        mmr_reset_sequence reset_seq; // read SRC DST LEN is zero
        mmr_rw_sequence rw_seq; // write nonzero and check

        phase.raise_objection(this);

        // wait for startup reset, then check reset values
        wait(vif.rst_n===1'b1);
        @(negedge vif.clk);

        m_env.m_scoreboard.reset_model();

        reset_seq=mmr_reset_sequence::type_id::create("startup_check");
        reset_seq.start(m_env.m_agent.m_sequencer);

        // write and read back nonzero values
        rw_seq=mmr_rw_sequence::type_id::create("nonzero_rw");
        rw_seq.start(m_env.m_agent.m_sequencer);

        // let the final transfer finish before resetting
        @(negedge vif.clk);

        // reset DUT and update the scoreboard model
        vif.apply_reset(); 
        m_env.m_scoreboard.reset_model();

        // read again and check that the registers are zero
        reset_seq=mmr_reset_sequence::type_id::create("recovery_check");
        reset_seq.start(m_env.m_agent.m_sequencer);

        // allow the monitor to finish publishing
        @(negedge vif.clk);

        phase.drop_objection(this);

    endtask
endclass