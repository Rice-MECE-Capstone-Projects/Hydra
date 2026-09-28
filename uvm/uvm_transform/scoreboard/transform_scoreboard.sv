//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_scoreboard.sv
//
// Author: Yulia Zhou
//
// Description:
// Receives configuration, RAM read, and scratchpad write transactions.
// Stores copies of the observed transactions for Mode C checking.
//
// Scope:
// Reception framework for one operation per simulation.
// Reference calculations and result comparisons will be added next.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

// declare separate analysis input types
`uvm_analysis_imp_decl(_ctrl)
`uvm_analysis_imp_decl(_ram)
`uvm_analysis_imp_decl(_scratch)

class transform_scoreboard extends uvm_scoreboard;

    // receive configuration from the control monitor
    uvm_analysis_imp_ctrl #(transform_ctrl_transaction,transform_scoreboard) ctrl_imp;

    // receive completed reads from the RAM monitor
    uvm_analysis_imp_ram #(transform_ram_transaction,transform_scoreboard) ram_imp;

    // receive writes from the scratchpad monitor
    uvm_analysis_imp_scratch #(transform_scratch_transaction,transform_scoreboard) scratch_imp;

    // store the configuration of one operation
    transform_ctrl_transaction cfg;
    bit cfg_valid = 1'b0;

    // store observed reads and writes
    transform_ram_transaction ram_queue[$];
    transform_scratch_transaction scratch_queue[$];

    `uvm_component_utils(transform_scoreboard)

    function new(string name="transform_scoreboard", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ctrl_imp = new("ctrl_imp",this);
        ram_imp = new("ram_imp",this);
        scratch_imp = new("scratch_imp",this);
    endfunction

    // receive one operation's configuration
    virtual function void write_ctrl(transform_ctrl_transaction tr);
        if(cfg_valid)begin
            `uvm_error("MULTIPLE_OPS","This scoreboard supports one operation per simulation")
            return;
        end

    cfg=transform_ctrl_transaction::type_id::create("cfg");
    cfg.copy(tr);
    cfg_valid=1'b1;

    `uvm_info("CTRL_RECEIVED",$sformatf("Configuration received: mode=%0d length=%0d", cfg.mode, cfg.length),UVM_LOW)
    endfunction

    // save one completed RAM read
    virtual function void write_ram(transform_ram_transaction tr);

        transform_ram_transaction saved_tr;
        saved_tr=transform_ram_transaction::type_id::create("saved_ram_tr");

        saved_tr.copy(tr);
        ram_queue.push_back(saved_tr);
    endfunction

    // saved one scratchpad write
    virtual function void write_scratch(transform_scratch_transaction tr);
        transform_scratch_transaction saved_tr;
        saved_tr=transform_scratch_transaction::type_id::create("saved_scratch_tr");

        saved_tr.copy(tr);
        scratch_queue.push_back(saved_tr);
    endfunction

    // calculate one expected Mode C output byte
    function automatic logic [7:0] predict_mode_c_byte(
        
    )

    // report reception counts only
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SB_COUNTS",$sformatf("Configuration received=%0b, RAM reads=%0d, scratchpad writes=%0d", cfg_valid,ram_queue.size(),scratch_queue.size()),UVM_LOW)
    endfunction

endclass 



