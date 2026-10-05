//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ctrl_driver.sv
//
// Author: Yulia Zhou
//
// Description:
// Drives Transform configuration and a one-cycle start pulse.
// Keeps configuration stable while waiting for completion.
// Reports errors and stops the simulation on timeout.
//
// Scope:
// Initial directed tests use one operation per reset.
// Reset during an active operation is not supported in this version.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ctrl_driver extends uvm_driver #(transform_ctrl_transaction);
    `uvm_component_utils(transform_ctrl_driver)

    virtual transform_ctrl_if vif;

    function new(string name="transform_ctrl_driver", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    int unsigned timeout_cycles=1000;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual transform_ctrl_if)::get(this,"","vif",vif))begin
            `uvm_fatal("NO_VIF","Transform control interface was not found")
        end
    endfunction

    virtual task run_phase (uvm_phase phase);

        transform_ctrl_transaction tr;
        bit completed;

        // Initial configuration: no operation requested
        vif.driver_cb.start<=1'b0;
        vif.driver_cb.mode<=hydra_pkg::MODE_C;
        vif.driver_cb.src_addr<='0;
        vif.driver_cb.dst_addr<='0;
        vif.driver_cb.length<=4;
        vif.driver_cb.scale_shift<='0;
        vif.driver_cb.signed_out<=1'b1;
        vif.driver_cb.round_en<=1'b0;

        // Wait for startup reset to finish
        do begin
            @(vif.driver_cb);
        end while (vif.driver_cb.rst_n!==1'b1);

        forever begin
            seq_item_port.get_next_item(tr);
            @(vif.driver_cb);

        // Do not start over an existing completion/error status
        if(vif.driver_cb.done!==1'b0||vif.driver_cb.error!==1'b0)begin
            `uvm_fatal("CTRL_NOT_READY","done/error must be zero before starting an operation")
        end

        // Apply configuration first
        vif.driver_cb.start<=1'b0;
        vif.driver_cb.mode<=tr.mode;
        vif.driver_cb.src_addr<=tr.src_addr;
        vif.driver_cb.dst_addr<=tr.dst_addr;
        vif.driver_cb.length<=tr.length;
        vif.driver_cb.scale_shift<=tr.scale_shift;
        vif.driver_cb.signed_out<=tr.signed_out;
        vif.driver_cb.round_en<=tr.round_en;

        // Configuration is stable before START
        @(vif.driver_cb)
        vif.driver_cb.start<=1'b1;

        // Hold START for one clock cycle
        @(vif.driver_cb)
        vif.driver_cb.start<=1'b0;

        // Keep all configuration fields unchanged
        completed =1'b0;

        for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++)begin
            @(vif.driver_cb);
            if(vif.driver_cb.rst_n!==1'b1)begin
                `uvm_fatal("RESET_DURING_OP","Reset during an operation is not supported yet")
            end

            if(vif.driver_cb.error===1'b1)begin
                `uvm_error("TRANSFORM_ERROR","Transform reported an error")
                completed=1'b1;
                break;
            end
            else if (vif.driver_cb.done===1'b1)begin
                `uvm_info("TRANSFORM_DONE","Transform reported completion",UVM_LOW)
                completed=1'b1;
                break;
            end
        end

        if(!completed)begin
            `uvm_fatal("TRANSFORM_TIMEOUT",$sformatf("No completion or error within %0d clock cycles",timeout_cycles))
        end

        seq_item_port.item_done();
        end
    endtask
endclass

                











