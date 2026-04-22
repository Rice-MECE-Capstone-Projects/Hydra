class cpu_sequence_item extends uvm_sequence_item;

  // ---------- Request fields (driven by sequence) ----------
  rand bit [31:0] addr;   // memory address
  rand bit [31:0] wdata;  // write data
  rand bit        we;     // write enable (1 = write, 0 = read)
  rand bit [3:0]  be;     // byte enable

  // ---------- Response fields (filled by monitor/driver) ----------
  bit [31:0] rdata;       // read data returned from DUT
  
  // Auxiliary field (not used for checking)
  bit        miss_seen;   // placeholder, hit/miss determined by scoreboard

  // ---------- UVM automation macros ----------
  `uvm_object_utils_begin(cpu_sequence_item)
    `uvm_field_int(addr  , UVM_ALL_ON)
    `uvm_field_int(wdata , UVM_ALL_ON)
    `uvm_field_int(we    , UVM_ALL_ON)
    `uvm_field_int(be    , UVM_ALL_ON)
    `uvm_field_int(rdata , UVM_ALL_ON)
  `uvm_object_utils_end

  // ---------- Constraints ----------

  // Limit address space (e.g., 8KB memory region)
  constraint addr_range {
    addr inside {[32'h0 : 32'h1FFF]};
  }

  // Equal probability for read and write operations
  constraint rw_ratio {
    we dist {1 := 50, 0 := 50};
  }

  // Ensure at least one byte is enabled
  constraint be_valid {
    be != 4'b0000;
  }

  function new(string name = "cpu_sequence_item");
    super.new(name);
  endfunction

endclass