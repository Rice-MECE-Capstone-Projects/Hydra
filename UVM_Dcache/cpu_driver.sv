class cpu_driver extends uvm_driver #(cpu_sequence_item);
  `uvm_component_utils(cpu_driver)

  // Virtual interface (driver modport)
  virtual cpu_if.DRIVER vif;

  function new(string name="cpu_driver", uvm_component parent=null);
      super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
      super.build_phase(phase);
     
      // Get virtual interface from config DB
      if (!uvm_config_db#(virtual cpu_if.DRIVER)::get(this, "", "vif", vif))
        `uvm_fatal("DRV", "No vif found")
  endfunction

  task run_phase(uvm_phase phase);
    cpu_sequence_item req;
    $display("Driver entered run_phase at %0t", $time);

    // --- Initial signal reset (drive idle values) ---
    @(vif.drv_cb);
    vif.drv_cb.cpu_addr  <= 0;
    vif.drv_cb.cpu_wdata <= 0;
    vif.drv_cb.data_req  <= 0;
    vif.drv_cb.data_we   <= 0;
    vif.drv_cb.data_be   <= 0;

    // --- Main transaction loop ---
    forever begin
    
      `uvm_info("DRV", "WAITING ITEM", UVM_LOW)
      
      // Get next transaction from sequencer
      seq_item_port.get_next_item(req);
      `uvm_info("DRV", "Got transaction", UVM_LOW)
      
      // Drive one transaction onto the interface
      drive_one_pkt(req);
      
      // Notify sequencer that the item is done
      seq_item_port.item_done();
    end
  endtask


  task drive_one_pkt(cpu_sequence_item req);
    int timeout;

    // --- Drive request signals ---
    @(vif.drv_cb);
    vif.drv_cb.data_req  <= 1;
    vif.drv_cb.data_we   <= req.we;
    vif.drv_cb.cpu_addr  <= req.addr;
    vif.drv_cb.cpu_wdata <= req.wdata;
    vif.drv_cb.data_be   <= req.be;
    
    // --- Wait for grant (handshake phase 1) ---
    timeout = 1000;
    do begin
      @(vif.drv_cb);
      timeout--;
    end while (vif.drv_cb.data_gnt !== 1 && timeout > 0);

    if (timeout <= 0)
      `uvm_error("DRV", "GNT Timeout - Cache ignored the request!")
    
    // --- Wait for transaction completion (handshake phase 2) ---
    timeout = 1000;

    while (timeout > 0) begin
      @(vif.drv_cb);
      timeout--;
  
      // Read completes when data_rvalid is asserted
      if (req.we == 0 && vif.drv_cb.data_rvalid == 1)
        break;
  
      // Write completes when stall is deasserted
      if (req.we == 1 && vif.drv_cb.cpu_stall == 0)
        break;
    end
  
    if (timeout <= 0)
      `uvm_error("DRV", "Operation Timeout")
    
    // --- Wait until stall is fully released ---
    while (vif.drv_cb.cpu_stall == 1)
      @(vif.drv_cb);
    
    // --- Deassert request (insert one idle cycle) ---
    @(vif.drv_cb);
    vif.drv_cb.data_req <= 0;
    vif.drv_cb.data_we  <= 0;

    // Allow deassertion to propagate
    @(vif.drv_cb);
    
    // --- Optional debug print for read ---
    if (req.we == 0)
      `uvm_info("DRV",
        $sformatf("Addr: %h | Read Data: %h", req.addr, vif.drv_cb.cpu_rdata),
        UVM_LOW)
  endtask

endclass