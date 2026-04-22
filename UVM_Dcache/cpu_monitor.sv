class cpu_monitor extends uvm_monitor;
  `uvm_component_utils(cpu_monitor)

  // Virtual interface (monitor modport)
  virtual cpu_if.MONITOR vif;

  // Analysis port to send collected transactions
  uvm_analysis_port #(cpu_sequence_item) monitor_port;

  function new(string name="cpu_monitor", uvm_component parent=null);
    super.new(name, parent);
    monitor_port = new("monitor_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get virtual interface from config DB
    if (!uvm_config_db#(virtual cpu_if.MONITOR)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "No vif found")
  endfunction

  task run_phase(uvm_phase phase);
    cpu_sequence_item tr;

    // Queues to track outstanding transactions
    logic [31:0] addr_queue[$];   // read addresses
    logic [31:0] waddr_queue[$];  // write addresses
    logic [31:0] wdata_queue[$];  // write data
  
    forever begin
      @(posedge vif.clk);
  
      // ---- Capture read request: req && !we && gnt ----
      if (vif.mon_cb.data_req && !vif.mon_cb.data_we && vif.mon_cb.data_gnt)
        addr_queue.push_back(vif.mon_cb.cpu_addr);
  
      // ---- Capture write request: req && we && gnt ----
      if (vif.mon_cb.data_req && vif.mon_cb.data_we && vif.mon_cb.data_gnt) begin
        waddr_queue.push_back(vif.mon_cb.cpu_addr);
        wdata_queue.push_back(vif.mon_cb.cpu_wdata);
      end
  
      // ---- Write completion: gnt && !stall ----
      if (vif.mon_cb.data_gnt && !vif.mon_cb.cpu_stall && vif.mon_cb.data_we) begin
        if (waddr_queue.size() > 0) begin
          tr = cpu_sequence_item::type_id::create("tr");

          tr.addr      = waddr_queue.pop_front();
          tr.we        = 1;
          tr.wdata     = wdata_queue.pop_front();

          // Hit/miss is determined by scoreboard, not monitor
          tr.miss_seen = 0;

          `uvm_info("MON",
            $sformatf("Collected tr: Addr=%h, we=1, rdata=%h, miss_seen=%0d",
                      tr.addr, tr.rdata, tr.miss_seen),
            UVM_LOW)

          monitor_port.write(tr);
        end
      end
  
      // ---- Read completion: data_rvalid ----
      if (vif.mon_cb.data_rvalid) begin
        if (addr_queue.size() > 0) begin
          tr = cpu_sequence_item::type_id::create("tr");

          tr.addr      = addr_queue.pop_front();
          tr.we        = 0;
          tr.rdata     = vif.mon_cb.cpu_rdata;

          // Hit/miss is determined by scoreboard
          tr.miss_seen = 0;

          `uvm_info("MON",
            $sformatf("Collected tr: Addr=%h, we=0, rdata=%h, miss_seen=%0d",
                      tr.addr, tr.rdata, tr.miss_seen),
            UVM_LOW)

          monitor_port.write(tr);
        end
      end
    end
  endtask

endclass