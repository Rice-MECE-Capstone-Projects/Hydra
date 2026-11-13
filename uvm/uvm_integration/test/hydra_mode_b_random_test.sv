class hydra_mode_b_random_test extends uvm_test;
    `uvm_component_utils(hydra_mode_b_random_test)

    hydra_integration_env m_env;
    function new(string name="hydra_mode_b_random_test",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_b_random_seq seq;
        int unsigned base_value;
        int unsigned odd_step;
        bit counts_ok=1;

        phase.raise_objection(this);
        seq=hydra_mode_b_random_seq::type_id::create("seq");
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;
        seq.transfer_length=128*$urandom_range(2,1);
        seq.source_address=32'h8000_0000+4*$urandom_range(16,0);

        // A 256-word transfer already fills the tested output range
        seq.destination_address =32'h2001_0000;
        if(seq.transfer_length==128)
            seq.destination_address+=4*$urandom_range(16,0);

        base_value=$urandom();
        odd_step=2*$urandom_range(2047,1)+1;
        `uvm_info("RANDOM_CFG",$sformatf("length=%0d src=0x%08h dst=0x%08h base=0x%08h step=%0d",
                      seq.transfer_length, seq.source_address,
                      seq.destination_address, base_value, odd_step),UVM_LOW)
                    
        for(int i=0;i<seq.transfer_length;i++)begin
            seq.sample_words[i]=base_value+odd_step*i;
            m_env.ram_model.write_word(seq.source_address+4*i,seq.sample_words[i]);
        end 

        seq.start(m_env.m_cpu_agent.m_sequencer);
        repeat(2) @(seq.cpu_vif.driver_cb);

        if(m_env.ram_read_fifo.used()!=seq.transfer_length)begin
            `uvm_error("RAM_COUNT",$sformatf("Expected %0d reads, got %0d", seq.transfer_length,m_env.ram_read_fifo.used()))
            counts_ok=0;
        end

        if(m_env.scratch_write_fifo.used()!=seq.transfer_length)begin
            `uvm_error("SCRATCH_COUNT",$sformatf("Expected %0d writes, got %0d", seq.transfer_length, m_env.scratch_write_fifo.used()))
            counts_ok=0;
        end

        if(!seq.failed&&counts_ok)
            `uvm_info("PASS","Randomized Mode B integration result matched",UVM_LOW)
        
        phase.drop_objection(this);
    endtask
endclass



