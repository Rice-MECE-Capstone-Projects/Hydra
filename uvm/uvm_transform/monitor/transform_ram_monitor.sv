//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ram_monitor.sv
//
// Author: Yulia Zhou
//
// Description:
// Observes RAM read requests and responses without driving signals.
// Saves each accepted read address and pairs it with the following data-phase response.
// Publishes completed reads to the scoreboard.
//
// Scope:
// Initial implementation matches the zero-wait-state RAM responder.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ram_monitor extends uvm_monitor;
    `uvm_component_utils(transform_ram_monitor)

    virtual transform_ram_if vif;

    uvm_analysis_port #(transform_ram_transaction) ap;

    function new(string name="transform_ram_monitor", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ap=new("ap", this);

        if(!uvm_config_db#(virtual transform_ram_if)::get(this,"","vif",vif))begin
            `uvm_fatal("NO_VIF", "Transform RAM interface was not found")
            end
    endfunction

    virtual task run_phase(uvm_phase phase);
        transform_ram_transaction tr;
        
        logic [hydra_pkg::ADDR_WIDTH-1:0] pending_address;
        bit pending_valid;

        pending_address='0; // last read request address
        pending_valid=1'b0; // read request waiting for returned data

        forever begin
            @(vif.monitor_cb);

            if(vif.monitor_cb.rst_n!==1'b1)begin
                pending_address = '0;
                pending_valid = 1'b0;
            end
            else begin
                // This version expects the responder to remain ready
                if(vif.monitor_cb.HREADY!==1'b1) begin
                    `uvm_fatal("RAM_READY", "This monitor expects zero-wait-state response")
                end

                // Complete the previous read's data phase
                if (pending_valid) begin
                    tr=transform_ram_transaction::type_id::create("tr");

                    tr.address = pending_address;
                    tr.read_data = vif.monitor_cb.HRDATA;
                    tr.response = vif.monitor_cb.HRESP;

                    ap.write(tr);

                    `uvm_info("RAM_MON",$sformatf("Read address=0x%08h data=0x%08h response=%b", tr.address, tr.read_data, tr.response), UVM_MEDIUM)
                end

                // The previous read is now complete
                pending_valid=1'b0;

                // Capture a new read's address phase
                if(vif.monitor_cb.hydra_grant===1'b1 && 
                vif.monitor_cb.HTRANS[1]===1'b1)begin
                    if(vif.monitor_cb.HWRITE!==1'b0)begin
                        `uvm_fatal("RAM_REQUEST","Expected a read request with HWRITE=0")
                    end

                    if($isunknown(vif.monitor_cb.HADDR))begin
                            `uvm_fatal("RAM_ADDRESS","Read address contains X or Z")
                    end

                    pending_address=vif.monitor_cb.HADDR;
                    pending_valid=1'b1;
                end
            end
        end
    endtask
endclass
        
