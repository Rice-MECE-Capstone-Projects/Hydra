class hydra_mode_c_ram_error_test extends uvm_test;
    `uvm_component_utils(hydra_mode_c_ram_error_test)

    hydra_integration_env m_env;

    function new(string name="hydra_mode_c_ram_error_test",
                 uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env = hydra_integration_env::type_id::create("m_env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        hydra_mode_c_ram_error_seq seq;
        transform_ram_transaction ram_tr;
        bit failed = 0;

        phase.raise_objection(this);

        for (int i = 0; i < 4; i++) begin
            m_env.ram_model.write_word(32'h8000_0000 + 4*i, i + 1);
        end

        // Return ERROR for the fourth accepted RAM read.
        m_env.m_ram_agent.m_driver.error_on_read_number = 4;

        seq = hydra_mode_c_ram_error_seq::type_id::create("seq");
        seq.cpu_vif = m_env.m_cpu_agent.m_driver.vif;
        seq.start(m_env.m_cpu_agent.m_sequencer);

        repeat (4) @(seq.cpu_vif.driver_cb);

        if (!m_env.m_ram_agent.m_driver.error_response_complete) begin
            `uvm_error("ERROR_NOT_INJECTED",
                       "The two-cycle RAM ERROR response did not complete")
            failed = 1;
        end

        if (!seq.irq_seen || !seq.status_error_seen) begin
            `uvm_error("ERROR_STATUS",
                       "Expected interrupt and CPU STATUS error indication")
            failed = 1;
        end

        if (m_env.ram_read_fifo.used() != 4) begin
            `uvm_error("RAM_COUNT",
                $sformatf("Expected 4 RAM responses, observed %0d",
                          m_env.ram_read_fifo.used()))
            failed = 1;
        end
        else begin
            for (int i = 0; i < 4; i++) begin
                if (!m_env.ram_read_fifo.try_get(ram_tr)) begin
                    `uvm_error("RAM_RESPONSE",
                               "Could not retrieve RAM response")
                    failed = 1;
                end
                else if (ram_tr.address !== (32'h8000_0000 + 4*i) ||
                         ram_tr.response !== (i == 3)) begin
                    `uvm_error("RAM_RESPONSE",
                        $sformatf("Read %0d: address=0x%08h response=%b",
                                  i+1, ram_tr.address, ram_tr.response))
                    failed = 1;
                end
            end
        end

        if (m_env.scratch_write_fifo.used() != 0) begin
            `uvm_error("SCRATCH_WRITE",
                $sformatf("Unexpected scratchpad writes: %0d",
                          m_env.scratch_write_fifo.used()))
            failed = 1;
        end

        if (!failed)
            `uvm_info("PASS",
                      "RAM error reached Transform and CPU STATUS; no output was written",
                      UVM_LOW)

        phase.drop_objection(this);
    endtask
endclass