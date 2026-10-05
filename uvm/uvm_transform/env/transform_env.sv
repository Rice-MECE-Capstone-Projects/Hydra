//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_env.sv
//
// Author: Yulia Zhou
//
// Description:
// Builds and connects the Transform verification components.
// Creates a shared RAM model for input-data storage.
// Connects control, RAM, and scratchpad observations to the scoreboard.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

class transform_env extends uvm_env;
    transform_ctrl_agent m_ctrl_agent;
    transform_ram_agent m_ram_agent;
    transform_scratch_monitor m_scratch_monitor;
    transform_scoreboard m_scoreboard;

    transform_ram_model ram_model;

    `uvm_component_utils(transform_env)

    function new(string name, uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // create the shared input-data storage model
        ram_model=transform_ram_model::type_id::create("ram_model");

        // give the RAM driver access to this same model
        uvm_config_db#(transform_ram_model)::set(this,"m_ram_agent.m_driver","ram_model",ram_model);

        // both agents actively drive their respective interfaces
        uvm_config_db#(uvm_active_passive_enum)::set(this,"m_ctrl_agent","is_active",UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this,"m_ram_agent","is_active",UVM_ACTIVE);
        m_ctrl_agent=transform_ctrl_agent::type_id::create("m_ctrl_agent",this);
        m_ram_agent=transform_ram_agent::type_id::create("m_ram_agent",this);
        m_scratch_monitor=transform_scratch_monitor::type_id::create("m_scratch_monitor",this);
        m_scoreboard=transform_scoreboard::type_id::create("m_scoreboard",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_ctrl_agent.m_monitor.ap.connect(m_scoreboard.ctrl_imp);
        m_ram_agent.m_monitor.ap.connect(m_scoreboard.ram_imp);
        m_scratch_monitor.ap.connect(m_scoreboard.scratch_imp);
    endfunction
endclass


