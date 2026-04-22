class cpu_test extends uvm_test;
  `uvm_component_utils(cpu_test)

  cpu_env env;

  function new(string name="cpu_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the verification environment
    env = cpu_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    cpu_sequence seq;

    // Raise objection to keep simulation running
    phase.raise_objection(this);

    // Create sequence instance
    seq = cpu_sequence::type_id::create("seq");

    // Start sequence on the agent's sequencer
    seq.start(env.agent.sequencer);

    // Drop objection after sequence completes
    phase.drop_objection(this);

    // Allow some extra cycles for final transactions to complete
    #100;
    $finish;

  endtask

endclass