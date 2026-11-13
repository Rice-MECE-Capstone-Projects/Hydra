class hydra_mode_c_random_test extends uvm_test;
    `uvm_component_utils(hydra_mode_c_random_test)

    hydra_integration_env m_env;

    function new(string name="hydra_mode_c_random_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=hydra_integration_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_c_random_seq seq;
        int signed sample;
        int override_value;
        bit counts_ok=1;

        phase.raise_objection(this);

        seq=hydra_mode_c_random_seq::type_id::create("seq");
        seq.cpu_vif=m_env.m_cpu_agent.m_driver.vif;

        seq.transfer_length=4*$urandom_range(1,4);
        if($value$plusargs("C_LENGTH=%d", override_value))begin
            if(override_value<4||override_value>132||override_value%4!=0)
                `uvm_fatal("TEST_CONFIG","C_LENGTH must be a multiple of 4 from 4 to 32")
            seq.transfer_length=override_value;
        end
        seq.sample_words=new[seq.transfer_length];
        seq.shift_amount=$urandom_range(1,4);
        seq.round_enable=$urandom_range(0,1);
        seq.signed_output=$urandom_range(0,1);

        // small aligned offsets stay inside the tested RAM/scratchpad regions
        seq.source_address=32'h8000_0000+4*$urandom_range(0,16);
        seq.destination_address=32'h2001_0000+4*$urandom_range(0,16);

        if($value$plusargs("C_SIGNED=%d",override_value))begin
            if(!(override_value inside{0,1}))
                `uvm_fatal("TEST_CONFIG","C_SIGNED must be 0 or 1")
            seq.signed_output=bit'(override_value);
        end
        if($value$plusargs("C_ROUND=%d",override_value))begin
            if(!(override_value inside{0,1}))
                `uvm_fatal("TEST_CONFIG","C_ROUND must be 0 or 1")
            seq.round_enable=bit'(override_value);
        end
        if($value$plusargs("C_SHIFT=%d",override_value))begin
            if(!(override_value inside{[0:4]}))
                `uvm_fatal("TEST_CONFIG","C_SHIFT must be 0 or 4")
            seq.shift_amount=override_value;
        end
        
        `uvm_info("RANDOM_CFG",
            $sformatf("length=%0d shift=%0d signed=%0b round=%0b src=0x%08h dst=0x%08h",
              seq.transfer_length, seq.shift_amount,
              seq.signed_output, seq.round_enable,
              seq.source_address, seq.destination_address),
            UVM_LOW)

        for(int i=0;i<seq.transfer_length;i++)begin
            sample=int'($urandom_range(0,1023))-512;
            seq.sample_words[i]=sample;
            m_env.ram_model.write_word(seq.source_address+4*i,sample);
        end

        seq.start(m_env.m_cpu_agent.m_sequencer);
        repeat(2) @(seq.cpu_vif.driver_cb);

        if(m_env.ram_read_fifo.used()!=seq.transfer_length)begin
            `uvm_error("RAM_COUNT",$sformatf("Expected %0d reads, got %0d", seq.transfer_length,m_env.ram_read_fifo.used()))
            counts_ok=0;
        end

        if(m_env.scratch_write_fifo.used()!=seq.transfer_length/4)begin
            `uvm_error("SCRATCH_COUNT",$sformatf("Expected %0d writes,got %0d",seq.transfer_length/4,m_env.scratch_write_fifo.used()))
            counts_ok=0;
        end

        if(!seq.failed && counts_ok)
            `uvm_info("PASS","Randomized Mode C integration result matched",UVM_LOW)
        
        phase.drop_objection(this);
    endtask
endclass
