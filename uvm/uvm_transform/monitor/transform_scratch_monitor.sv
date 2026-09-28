//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_scratch_monitor.sv
//
// Author: Yulia Zhou
//
// Description:
// Observes scratchpad writes issued by hydra_transform.
// Captures the write address and data when SCRATCH_WE is asserted.
// Publishes each observed write for checking by the scoreboard.
// Does not drive interface signals.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_scratch_monitor extends uvm_monitor;

    virtual transform_scratch_if vif;
    uvm_analysis_port #(transform_scratch_transaction) ap;

    `uvm_component_utils(transform_scratch_monitor)

    function new(string name="transform_scratch_monitor", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        ap=new("ap",this);
        if(!uvm_config_db#(virtual transform_scratch_if)::get(this,"","vif",vif))begin
            `uvm_fatal("NO VIF","Transform scratch interface was not found")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);

        transform_scratch_transaction tr;
        
        forever begin
            @(vif.monitor_cb);

            // an unknown write enable should be reported 
            if ($isunknown(vif.monitor_cb.SCRATCH_WE))begin
                `uvm_error("SCRATCH_WE","Scratchpad write enable contains X or Z")
            end
            else if(vif.monitor_cb.reset===1'b1 && vif.monitor_cb.SCRATCH_WE===1'b1)begin
                tr=transform_scratch_transaction::type_id::create("tr");

                tr.address=vif.monitor_cb.SCRATCH_WADDR;
                tr.write_data=vif.monitor_cb.SCRATCH_WDATA;

                if($isunknown({tr.address, tr.write_data}))begin
                    `uvm_error("SCRATCH_UNKNOWN","Scratchpad write address or data contains X or Z")
                end
                
                ap.write(tr);
                `uvm_info("SCRATCH_MON",$sformatf("write address=0x%08h, write data=0x%08h", tr.address, tr.write_data),UVM_LOW)
            end
        end
        endtask
    
endclass