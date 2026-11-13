class mode_c_combined_arithmetic_test extends uvm_test;
    `uvm_component_utils(mode_c_combined_arithmetic_test)

    transform_env m_env;

    function new(string name="mode_c_combined_arithmetic_test", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env=transform_env::type_id::create("m_env",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mode_c_basic_seq seq;
        logic [31:0] expected_data[8];
        logic [31:0] expected_address;

        phase.raise_objection(this);

        // eight consecutive signed 32-bit input words
        m_env.ram_model.write_word(32'h8000_0000, 32'hFFFF_FEFF); // -257
        m_env.ram_model.write_word(32'h8000_0004, 32'hFFFF_FF01); // -255
        m_env.ram_model.write_word(32'h8000_0008, 32'hFFFF_FFFD); // -3
        m_env.ram_model.write_word(32'h8000_000C, 32'hFFFF_FFFF); // -1

        m_env.ram_model.write_word(32'h8000_0010, 32'h0000_00FD); // 253
        m_env.ram_model.write_word(32'h8000_0014, 32'h0000_00FF); // 255
        m_env.ram_model.write_word(32'h8000_0018, 32'h0000_01FD); // 509
        m_env.ram_model.write_word(32'h8000_001C, 32'h0000_01FF); // 511

        // signed/no round, signed/round, unsigned/no round, unsigned/round
        expected_data[0] = 32'hFFFE_8080;
        expected_data[1] = 32'h7F7F_7F7E;
        expected_data[2] = 32'h00FF_8180;
        expected_data[3] = 32'h7F7F_7F7F;

        expected_data[4] = 32'h0000_0000;
        expected_data[5] = 32'hFFFE_7F7E;
        expected_data[6] = 32'h0000_0000;
        expected_data[7] = 32'hFFFF_807F;

        for(int case_index=0; case_index<4;case_index++)begin
            seq=mode_c_basic_seq::type_id::create($sformatf("seq_%0d",case_index));

            seq.transfer_length=8;
            seq.shift_amount=1;
            seq.signed_output=(case_index<2); // signed_output=0/1
            seq.round_enable=(case_index%2==1); // round_en=0/1/0/1
            seq.source_address=32'h8000_0000;
            seq.destination_address=case_index*32'h0000_0100;

            seq.start(m_env.m_ctrl_agent.m_sequencer);
            repeat(2) @(m_env.m_ctrl_agent.m_driver.vif.driver_cb);
        end

        if(m_env.m_scoreboard.scratch_queue.size()!=8)begin
            `uvm_error("C10_WRITE_COUNT",$sformatf("Expected 8 scratchpad writes, observed %0d", m_env.m_scoreboard.scratch_queue.size()))
        end
        else begin
            for(int i=0;i<8;i++)begin
                expected_address=(i/2)*32'h0000_0100+(i%2)*4;
                if(m_env.m_scoreboard.scratch_queue[i].address!==expected_address || m_env.m_scoreboard.scratch_queue[i].write_data!==expected_data[i])begin
                    `uvm_error("C10_OUTPUT",$sformatf("Write %0d: expected addr=0x%08h data=0x%08h; got addr=0x%08h data=0x%08h",i,expected_address,expected_data[i],m_env.m_scoreboard.scratch_queue[i].address,m_env.m_scoreboard.scratch_queue[i].write_data))
                end
            end
        end
        phase.drop_objection(this);
    endtask
endclass

