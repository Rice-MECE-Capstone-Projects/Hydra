//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ctrl_agent.sv
//
// Author: Yulia Zhou
//
// Description:
// Groups the Transform control sequencer, driver, and monitor.
// In active mode, drives configuration and START.
// In passive mode, only observes the control interface.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_ctrl_agent extends uvm_agent;
    `uvm_component_utils(transform_ctrl_agent)

    transform_ctrl_driver m_driver;
    transform_ctrl_sequencer m_sequencer;
    transform_ctrl_monitor m_monitor;

    function new(string name="transform_ctrl_agent",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_monitor=transform_ctrl_monitor::type_id::create("m_monitor",this);

        if(get_is_active()==UVM_ACTIVE)begin
            m_sequencer=transform_ctrl_sequencer::type_id::create("m_sequencer",this);
            m_driver=transform_ctrl_driver::type_id::create("m_driver",this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(get_is_active()==UVM_ACTIVE)begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction
endclass
