//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_scratch_if.sv
//
// Author: Yulia Zhou
//
// Description:
// Exposes the scratchpad write outputs of hydra_transform.
// Provides a monitor clocking block to sample write enable, address, and data at the receiving clock edge.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

interface transform_scratch_if(
    input logic clk,
    input logic rst_n
);

    import hydra_pkg::*;

    // Driver by Transform
    logic SCRATCH_WE; // write enable
    logic [ADDR_WIDTH-1:0] SCRATCH_WADDR; 
    logic [DATA_WIDTH-1:0] SCRATCH_WDATA;

    // Observe scratchpad writes
    clocking monitor_cb @(posedge clk);
        default input #1step;

        input rst_n;
        input SCRATCH_WE;
        input SCRATCH_WADDR;
        input SCRATCH_WDATA;
    endclocking

    modport MONITOR(clocking monitor_cb);
endinterface


 