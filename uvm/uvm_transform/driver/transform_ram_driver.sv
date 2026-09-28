/////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ram_driver.sv
//
// Author: Yulia Zhou
//
// Description:
// Automatically responds to RAM read requests issued by hydra_transform.
// Uses a virtual transform_ram_if and a shared transform_ram_model handle to look up requested data and drive HRDATA, HREADY, and HRESP.
// Observes HADDR and request signals without driving them.
// Does not use get_next_item() or require a RAM sequencer.
//
// Scope:
// Initial implementation supports zero-wait-state, successful read responses.
// Wait-state insertion and error injection will be added later.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ram_driver extends uvm_component;
    `uvm_component_utils (transform_ram_driver)

    function new(string name="transform_ram_driver", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual transform_ram_if vif;
    transform_ram_model ram_model;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual transform_ram_if)::get(this,"","vif",vif))begin
            `uvm_fatal("NO_VIF","Transform RAM interface was not found")
        end

        // get the shared RAM storage model
        if(!uvm_config_db#(transform_ram_model)::get(this,"","ram_model",ram_model))begin
            `uvm_fatal("NO_RAM_MODEL","Transform RAM model was not found")
        end

        if(ram_model==null)begin
            `uvm_fatal("NULL_RAM_MODEL","RAM model handle is null")
        end
    endfunction

    virtual task run_phase (uvm_phase phase);
        logic [hydra_pkg::DATA_WIDTH-1:0] read_data;

        // Zero-wait-state, successful responses
        vif.driver_cb.HREADY<=1'b1;
        vif.driver_cb.HRESP<=1'b0;
        vif.driver_cb.HRDATA<='0;

        forever begin
            @(vif.driver_cb);

            if(vif.driver_cb.rst_n!==1'b1)begin
                vif.driver_cb.HREADY<=1'b1;
                vif.driver_cb.HRESP<=1'b0;
                vif.driver_cb.HRDATA<='0;
            end
            else begin
                if(vif.driver_cb.hydra_grant===1'b1 && vif.driver_cb.HTRANS[1]===1'b1)begin

                    // this responder supports reads only
                    if(vif.driver_cb.HWRITE!==1'b0)begin
                        `uvm_fatal("RAM_REQUEST","Expected a read request with HWRITE=0")
                    end

                    // only 32-bit word accesses are supported
                    if(vif.driver_cb.HSIZE!==3'b010)begin
                        `uvm_fatal("RAM_SIZE","Expected a 32-bit word access")
                    end

                    // check before converting to the model's 2-state address
                    if($isunknown(vif.driver_cb.HADDR))begin
                        `uvm_fatal("RAM_ADDRESS","Read address contains X or Z")
                    end

                    read_data=ram_model.read_word(vif.driver_cb.HADDR);

                    // provide data for the following data phase
                    vif.driver_cb.HRDATA<=read_data;
                    `uvm_info("RAM_READ",$sformatf("Address=0x%08h data=0x%08h", vif.driver_cb.HADDR,read_data),UVM_MEDIUM)
                end
                else begin
                    // no valid new address; the next data phase is inactive
                    vif.driver_cb.HRDATA<='0;
                end
            end
        end
    endtask

endclass


        