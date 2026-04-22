class cpu_env extends uvm_env;
  `uvm_component_utils(cpu_env)

  cpu_agent      agent;
  cpu_scoreboard scoreboard;

  function new(string name="cpu_env", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create agent and scoreboard components
    agent      = cpu_agent     ::type_id::create("agent", this);
    scoreboard = cpu_scoreboard::type_id::create("scoreboard", this);

    // Configure agent to operate in ACTIVE mode
    uvm_config_db#(uvm_active_passive_enum)::set(this, "agent", "is_active", UVM_ACTIVE);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis port to scoreboard
    agent.monitor.monitor_port.connect(scoreboard.imp);
  endfunction
endclass