class cpu_agent extends uvm_agent;
  `uvm_component_utils(cpu_agent)

  cpu_driver    driver;
  cpu_sequencer sequencer;
  cpu_monitor   monitor;

  function new(string name="cpu_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create driver and sequencer only in active mode
    if (is_active == UVM_ACTIVE) begin
      driver    = cpu_driver   ::type_id::create("driver", this);
      sequencer = cpu_sequencer::type_id::create("sequencer", this);
    end

    // Monitor is required in both active and passive modes
    monitor = cpu_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect driver to sequencer in active mode
    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      `uvm_info("AGENT", "Driver connected to Sequencer", UVM_LOW)
    end
  endfunction
endclass