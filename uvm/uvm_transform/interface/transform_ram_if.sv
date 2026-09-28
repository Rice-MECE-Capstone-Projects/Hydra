//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_ram_if.sv
//
// Author: Yulia Zhou
//
// Description:
// Defines the RAM-side interface for hydra_transform verification.
// The DUT drives AHB requests. The RAM responder drives read data, ready, and response signals. The arbiter supplies hydra_grant.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

interface transform_ram_if(
    input logic clk,
    input logic rst_n,
    input logic hydra_grant
);
    import hydra_pkg::*;

    // Requests driven by transform
    logic [ADDR_WIDTH-1:0] HADDR;
    logic [2:0] HBURST;
    logic [2:0] HSIZE;
    logic [1:0] HTRANS;
    logic [DATA_WIDTH-1:0] HWDATA;
    logic HWRITE;

    // Responses driven by the RAM responder   
    logic [DATA_WIDTH-1:0] HRDATA;
    logic HREADY;
    logic HRESP;

    // RAM responder observes requests and drives responses
    clocking driver_cb @(posedge clk);
        default input #1step output #0;

        input rst_n;
        input hydra_grant;

        input HADDR;
        input HBURST;
        input HSIZE;
        input HTRANS;
        input HWDATA;
        input HWRITE;

        output HRDATA;
        output HREADY;
        output HRESP;
    endclocking

    // Monitor observes requests and responses
    clocking monitor_cb @(posedge clk);
        default input #1step;

        input rst_n;
        input hydra_grant;

        input HADDR;
        input HBURST;
        input HSIZE;
        input HTRANS;
        input HWDATA;
        input HWRITE;

        input HRDATA;
        input HREADY;
        input HRESP;
    endclocking

    modport DRIVER(clocking driver_cb);
    modport MONITOR(clocking monitor_cb);
endinterface