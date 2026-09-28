class cpu_ahb_sequencer extends uvm_sequencer #(cpu_ahb_transaction);
    `uvm_component_utils(cpu_ahb_sequencer)

    function new (string name = "cpu_ahb_sequencer", uvm_component parent=null);
        super.new(name,parent);
    endfunction

endclass