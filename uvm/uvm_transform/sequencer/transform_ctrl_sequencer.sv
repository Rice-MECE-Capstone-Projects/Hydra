//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ctrl_sequencer.sv
//
// Author: Yulia Zhou
//
// Description:
// Provides the sequencer for Transform configuration transactions.
// Used by control sequences and the control driver.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ctrl_sequencer extends uvm_sequencer #(transform_ctrl_transaction);
    `uvm_component_utils(transform_ctrl_sequencer)

    function new(string name ="transform_ctrl_sequencer", uvm_component parent=null);
        super.new(name,parent);
    endfunction

endclass