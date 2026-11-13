class mode_c_random_test extends uvm_test;
    `uvm_component_utils(mode_c_random_test)

    transform_env m_env;

    function new (string name="mode_c_random_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_c_basic_seq seq;
        int signed sample;

        phase.raise_objection(this);

        seq=mode_c_basic_seq::type_id::create("seq");

        // Only generate valid Mode C configurations
        seq.transfer_length=4*$urandom_range(1,4); 
        seq.shift_amount=$urandom_range(1,4);
        seq.round_enable=$urandom_range(0,1);
        seq.signed_output=$urandom_range(0,1);

        `uvm_info("RANDOM_CFG",$sformatf("length=%0d shift=%0d signed=%0b round=%0b", seq.transfer_length,seq.shift_amount,seq.signed_output,seq.round_enable),UVM_LOW)

        // Prepare exactly the number of inputs by LEN
        for(int i=0;i<seq.transfer_length;i++)begin
            sample=int'($urandom_range(0,1023))-512;
            m_env.ram_model.write_word(seq.source_address+4*i,sample);
        end        

        seq.start(m_env.m_ctrl_agent.m_sequencer);
        
        repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        phase.drop_objection(this);
    endtask
endclass