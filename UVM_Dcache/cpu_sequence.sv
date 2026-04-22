class cpu_sequence extends uvm_sequence #(cpu_sequence_item);
    
    `uvm_object_utils(cpu_sequence)
    `uvm_declare_p_sequencer(cpu_sequencer)

    function new (string name = "cpu_sequence");
        super.new(name);
    endfunction
    
    task body();
      cpu_sequence_item req;
  
      // Track last address to bias towards cache hits
      bit [31:0] last_addr;
  
      // Generate a fixed number of transactions
      for (int i = 0; i < 200; i++) begin
        req = cpu_sequence_item::type_id::create($sformatf("req_%0d", i));
  
        // Start handshake with driver
        start_item(req);
  
        // --- Address generation strategy ---
        // 70% probability: reuse last address → likely cache hit
        // 30% probability: random address → likely cache miss
        if ($urandom_range(0, 99) < 70 && i > 0) begin
          req.addr = last_addr;
        end
        else begin
          // Mask to limit address range (e.g., 8KB space)
          req.addr = {$urandom} & 32'h00001FFF;
        end
  
        // --- Random read/write operation ---
        req.we    = $urandom_range(0,1);  // 0 = read, 1 = write
        req.wdata = $urandom;             // random write data
        req.be    = 4'b1111;              // full word access
  
        // Save address for next iteration (hit bias)
        last_addr = req.addr;
  
        // Complete handshake
        finish_item(req);
  
        // Debug print
        `uvm_info("SEQ",
          $sformatf("txn[%0d]: addr=%h we=%0d", i, req.addr, req.we),
          UVM_LOW)
      end
    endtask

endclass