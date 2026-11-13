class mode_b_random_test extends uvm_test;
    `uvm_component_utils(mode_b_random_test)

    transform_env m_env;

    function new(string name="mode_b_random_test",
                 uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_b_random_seq seq;
        int unsigned block_size;
        int unsigned blocks;
        bit [31:0] base;
        bit [31:0] step;

        phase.raise_objection(this);

        block_size=hydra_pkg::BLOCK_ROWS*hydra_pkg::BLOCK_COLS;
        blocks=$urandom_range(1,3);
        base=$urandom();
        step=$urandom()|32'h1;

        seq=mode_b_random_seq::type_id::create("seq");
        seq.transfer_length=block_size*blocks;

        for(int i=0;i<seq.transfer_length;i++)
            m_env.ram_model.write_word(
                seq.source_address+4*i,
                base+step*i
            );

        `uvm_info("RANDOM_CFG",$sformatf("blocks=%0d length=%0d base=0x%08h step=0x%08h", blocks,seq.transfer_length,base,step),UVM_LOW)

        seq.start(m_env.m_ctrl_agent.m_sequencer);
        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass