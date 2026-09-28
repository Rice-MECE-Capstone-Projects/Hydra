//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ctrl_if.sv
//
// Author: Yulia Zhou
// Date: 2026-09-16
//
// Description:
// Defines the configuration and status interface for hydra_transform.
// Provides start, mode, source/destination addresses, transfer length, and quantization parameters. 
// Includes driver and monitor clocking blocks and modports for UVM access.
//
// Scope:
// Shared by Mode B and Mode C verification.
// RAM transactions and scratchpad writes use separate interfaces.
//
// Project: Hydra UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

interface transform_ctrl_if(
    input logic clk,
    input logic rst_n
);

    import hydra_pkg::*;
    
    // Configuration inputs to Transform
    logic start;
    hydra_mode mode;
    logic [ADDR_WIDTH-1:0] src_addr;
    logic [ADDR_WIDTH-1:0] dst_addr;
    logic [LEN_WIDTH-1:0] length;

    logic [DATA_BITS:0] scale_shift;
    logic signed_out;
    logic round_en;

    // Status outputs from Transform
    logic done;
    logic error;

    // Driver drives configuration and samples status
    clocking driver_cb @(posedge clk);
        default input #1step output #0;

        output start;
        output mode;
        output src_addr;
        output dst_addr;
        output length;
        output scale_shift;
        output signed_out;
        output round_en;

        input rst_n;
        input done;
        input error;
    endclocking

    // Monitor observes configuration and status 
    clocking monitor_cb @(posedge clk);
        default input #1step;

        input rst_n;
        input start;
        input mode;
        input src_addr;
        input dst_addr;
        input length;
        input scale_shift;
        input signed_out;
        input round_en;
        input done;
        input error;
    endclocking

    modport DRIVER(clocking driver_cb);
    modport MONITOR(clocking monitor_cb);
endinterface
