class cpu_ahb_agent extends uvm_agent;

    `uvm_component_utils(cpu_ahb_agent)

    function new(string name="cpu_ahb_agent",uvm_component parent=null);
        super.new(name,parent);
    endfunction

    //create handle
    cpu_ahb_monitor m_monitor;
    cpu_ahb_sequencer m_sequencer;
    cpu_ahb_driver m_driver;

    //build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(get_is_active()==UVM_ACTIVE)begin //agent drives signal actively
        m_sequencer=cpu_ahb_sequencer::type_id::create("m_sequencer",this);
        m_driver=cpu_ahb_driver::type_id::create("m_driver",this);
        end
        m_monitor=cpu_ahb_monitor::type_id::create("m_monitor",this);
        
    endfunction

    //connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if(get_is_active()==UVM_ACTIVE)begin
        m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass