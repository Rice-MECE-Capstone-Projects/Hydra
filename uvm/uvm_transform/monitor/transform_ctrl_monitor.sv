//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ctrl_monitor.sv
//
// Author: Yulia Zhou
//
// Description:
// Observes the Transform control interface and captures configuration when START is first sampled high. 
// Publishes the configuration transaction through an analysis port.
//
// Scope:
// Captures configuration only. Completion and output-data checks are handled separately.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ctrl_monitor extends uvm_monitor;
    `uvm_component_utils (transform_ctrl_monitor)

    virtual transform_ctrl_if vif;

    uvm_analysis_port #(transform_ctrl_transaction) ap;

    function new(string name="transform_ctrl_monitor", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap=new("ap",this);

        if(!uvm_config_db#(virtual transform_ctrl_if)::get(this,"","vif",vif))begin
            `uvm_fatal("NO_VIF","Transform control interface was not found")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        transform_ctrl_transaction tr;
        bit previous_start;

        previous_start=1'b0;

        forever begin
            @(vif.monitor_cb);

            if(vif.monitor_cb.rst_n!==1'b1)begin
                previous_start=1'b0;
            end
            else begin
                // capture once when START changes from low to high
                if(vif.monitor_cb.start===1'b1&&!previous_start)begin
                    tr=transform_ctrl_transaction::type_id::create("observed_ctrl");

                    tr.mode=vif.monitor_cb.mode;
                    tr.src_addr=vif.monitor_cb.src_addr;
                    tr.dst_addr=vif.monitor_cb.dst_addr;
                    tr.length=vif.monitor_cb.length;
                    tr.scale_shift=vif.monitor_cb.scale_shift;
                    tr.signed_out=vif.monitor_cb.signed_out;
                    tr.round_en=vif.monitor_cb.round_en;

                    ap.write(tr);

                    `uvm_info("CTRL_CAPTURE",$sformatf("mode=%s src=0x%08h dst=0x%08h length=%0d shift=%0d signed=%0b round=%0b",
                                tr.mode.name(),tr.src_addr,tr.dst_addr,tr.length,tr.scale_shift,tr.signed_out,tr.round_en),UVM_LOW)
                end

                previous_start=(vif.monitor_cb.start===1'b1);
            end
        end
    endtask
endclass

