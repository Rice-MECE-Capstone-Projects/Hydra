interface cpu_if(input logic clk);

  logic [31:0] cpu_addr;
  logic [31:0] cpu_wdata;
  logic        data_req;
  logic        data_we;
  logic [3:0]  data_be;

  logic [31:0] cpu_rdata;
  logic        data_rvalid;
  logic        data_gnt;
  logic        cpu_stall;
  
  // ===== Memory side =====
  logic [31:0] mem_addr_block;
  logic [31:0] mem_addr;
  logic        mem_read;
  logic        mem_write;
  logic [255:0] mem_wdata_block;
  logic [31:0] miss_mem_wdata;
  
  logic [255:0] mem_rdata_array;
  logic         mem_ready;

  clocking drv_cb @(posedge clk);
    default input #1 output #1;

    output cpu_addr, cpu_wdata, data_req, data_we, data_be;
    input  cpu_rdata, data_rvalid, data_gnt, cpu_stall;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1 output #1;
    
    input mem_addr_block, mem_addr, mem_read, mem_write;
    input mem_wdata_block, miss_mem_wdata;
    input mem_rdata_array, mem_ready;

    input cpu_addr, cpu_wdata, data_req, data_we, data_be;
    input cpu_rdata, data_rvalid, data_gnt, cpu_stall;
  endclocking
  
  // Assertion
  assert property (@(posedge clk)
    data_rvalid |-> data_req
  );
  assert property (@(posedge clk)
    data_we |-> (data_be != 4'b0000)
  );
  assert property (@(posedge clk)
      (cpu_stall && $past(cpu_stall)) |-> $stable(cpu_addr)
  );

  // modport
  modport DRIVER  (clocking drv_cb, input clk);
  modport MONITOR (clocking mon_cb, input clk);

endinterface