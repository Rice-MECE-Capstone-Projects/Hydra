`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// basics 
`include "cpu_sequence_item.sv"
`include "cpu_sequencer.sv"

`include "cpu_if.sv"

// driver / monitor
`include "cpu_driver.sv"
`include "cpu_monitor.sv"

// agent
`include "cpu_agent.sv"

// scoreboard
`include "cpu_scoreboard.sv"

// env 
`include "cpu_env.sv"

// sequences and tests
`include "cpu_sequence.sv"
`include "cpu_test.sv"


module top;

  logic clk;
  logic reset;

  // memory bus
  logic [31:0] mem_bus_addr, mem_bus_wdata, mem_bus_rdata;
  logic        mem_bus_read, mem_bus_write, mem_bus_valid;

  // clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // reset
  initial begin
    reset = 1;
    repeat (5) @(posedge clk);
    reset = 0;
  end

  // interface
  cpu_if vif(clk);

  // ================= DUT =================
  cache u_cache(
      .clk(clk),
      .reset(reset),

      // CPU side
      .cpu_addr    (vif.cpu_addr),
      .cpu_wdata   (vif.cpu_wdata),
      .data_req    (vif.data_req),
      .data_we     (vif.data_we),
      .data_be     (vif.data_be),
      .cpu_rdata   (vif.cpu_rdata),
      .data_rvalid (vif.data_rvalid),
      .data_gnt    (vif.data_gnt),
      .cpu_stall   (vif.cpu_stall),

      // Memory side
      .mem_addr_block (vif.mem_addr_block),
      .mem_addr       (vif.mem_addr),
      .mem_read       (vif.mem_read),
      .mem_write      (vif.mem_write),
      .mem_wdata_block(vif.mem_wdata_block),
      .miss_mem_wdata (vif.miss_mem_wdata),

      .mem_rdata_array(vif.mem_rdata_array),
      .mem_ready      (vif.mem_ready),

      .state()
  );

  // ================= Memory Interface =================
  data_cache_interface u_interface_ctrl (
      .clk(clk),
      .reset(reset),

      .cache_mem_addr_block (vif.mem_addr_block),
      .cache_mem_addr       (vif.mem_addr),
      .cache_mem_read       (vif.mem_read),
      .cache_mem_write      (vif.mem_write),
      .cache_mem_wdata_block(vif.mem_wdata_block),
      .cache_miss_mem_wdata (vif.miss_mem_wdata),
      .cache_mem_rdata_array(vif.mem_rdata_array),
      .cache_mem_ready      (vif.mem_ready),

      .mem_addr  (mem_bus_addr), 
      .mem_read  (mem_bus_read),
      .mem_write (mem_bus_write),
      .mem_wdata (mem_bus_wdata),
      .mem_rdata (mem_bus_rdata),
      .mem_valid (mem_bus_valid)
  );

  // ================= Real Memory =================
  dataMem u_real_mem (
      .clk(clk),
      .reset(reset),

      .mem_addr  (mem_bus_addr),
      .mem_read  (mem_bus_read),
      .mem_write (mem_bus_write),
      .mem_wdata (mem_bus_wdata),
      .mem_rdata (mem_bus_rdata),
      .mem_valid (mem_bus_valid)
  );

  // ================= UVM =================
  initial begin
    uvm_config_db#(virtual cpu_if.DRIVER)::set(null, "*", "vif", vif);
    uvm_config_db#(virtual cpu_if.MONITOR)::set(null, "*", "vif", vif);

    run_test("cpu_test");
  end

endmodule