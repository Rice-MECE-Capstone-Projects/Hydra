class hydra_integration_env extends uvm_env;
    `uvm_component_utils(hydra_integration_env)

    cpu_ahb_agent m_cpu_agent;
    transform_ram_agent m_ram_agent;
    transform_ram_model ram_model;
    transform_scratch_monitor m_scratch_monitor;
    hydra_integration_coverage m_coverage;

    uvm_tlm_analysis_fifo#(transform_ram_transaction) ram_read_fifo;
    uvm_tlm_analysis_fifo#(transform_scratch_transaction) scratch_write_fifo;

    function new(string name="hydra_integration_env",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_scratch_monitor=transform_scratch_monitor::type_id::create("m_scratch_monitor",this);
        ram_model=transform_ram_model::type_id::create("ram_model");
        m_coverage=hydra_integration_coverage::type_id::create("m_coverage",this);

        // The RAM responder and the test use the same input-data model
        uvm_config_db #(transform_ram_model)::set(this,"m_ram_agent.m_driver","ram_model",ram_model);
        uvm_config_db #(uvm_active_passive_enum)::set(this,"m_cpu_agent","is_active",UVM_ACTIVE);
        uvm_config_db #(uvm_active_passive_enum)::set(this,"m_ram_agent","is_active",UVM_ACTIVE);

        m_cpu_agent=cpu_ahb_agent::type_id::create("m_cpu_agent",this);
        m_ram_agent=transform_ram_agent::type_id::create("m_ram_agent",this);

        ram_read_fifo=new("ram_read_fifo",this);
        scratch_write_fifo=new("scratch_write_fifo",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_ram_agent.m_monitor.ap.connect(ram_read_fifo.analysis_export);
        m_scratch_monitor.ap.connect(scratch_write_fifo.analysis_export);
        m_cpu_agent.m_monitor.ap.connect(m_coverage.analysis_export);
    endfunction
    
endclass
