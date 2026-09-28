class mmr_env extends uvm_env;

`uvm_component_utils(mmr_env)

cpu_ahb_agent m_agent;
cpu_ahb_scoreboard m_scoreboard;

//construction
function new(string name="mmr_env",uvm_component parent=null);
    super.new(name,parent);
endfunction

//build_phase
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_agent=cpu_ahb_agent::type_id::create("m_agent",this);
    m_scoreboard=cpu_ahb_scoreboard::type_id::create("m_scoreboard",this);
endfunction

//connect_phase
virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    m_agent.m_monitor.ap.connect(m_scoreboard.cpu_ahb_imp);
endfunction

endclass




