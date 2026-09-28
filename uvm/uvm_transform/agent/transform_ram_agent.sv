//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ram_agent.sv
//
// Author: Yulia Zhou
//
// Description:
// Groups the RAM responder driver and RAM monitor.
// In active mode, the driver responds to read requests from hydra_transform.
// The monitor observes RAM transfers in both active and passive modes.
// No sequencer is required because the driver responds directly to DUT requests.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ram_agent extends uvm_agent;
    `uvm_component_utils(transform_ram_agent)

    transform_ram_driver m_driver;
    transform_ram_monitor m_monitor;

    function new(string name="transform_ram_agent", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create the responder only in active mode
        if(get_is_active()==UVM_ACTIVE)begin
            m_driver=transform_ram_driver::type_id::create("m_driver",this);
        end

        // always create the monitor
        m_monitor=transform_ram_monitor::type_id::create("m_monitor",this);
    endfunction

endclass