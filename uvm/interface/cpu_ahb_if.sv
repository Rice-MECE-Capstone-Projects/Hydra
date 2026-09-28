`timescale 1ns/1ps

interface cpu_ahb_if(
    input logic clk
    //input logic rst_n
);
    logic rst_n = 1'b0;

    // CPU/UVM Driver drives these signals to the DUT
    logic [31:0] HADDR;
    logic [31:0] HWDATA;
    logic        HWRITE;
    logic [1:0]  HTRANS;
    logic        HSEL;
    logic        HREADY;

    // DUT returns these signals to the CPU/UVM Agent
    logic [31:0] HRDATA;
    logic        HREADYOUT;
    logic        HRESP;

    // Driver clocking block
    clocking driver_cb @(posedge clk);
        default input #1step output #0;

        output HADDR;
        output HWDATA;
        output HWRITE;
        output HTRANS;
        output HSEL;
        output HREADY;

        input HRDATA;
        input HREADYOUT;
        input HRESP;
        input rst_n;
    endclocking 

    // Monitor clocking block
    clocking monitor_cb @(posedge clk);
        default input #1step;

        input HADDR;
        input HWDATA;
        input HWRITE;
        input HTRANS;
        input HSEL;
        input HREADY;

        input HRDATA;
        input HREADYOUT;
        input HRESP;
        input rst_n;
    endclocking

    //modport
    modport DRIVER (clocking driver_cb);
    modport MONITOR (clocking monitor_cb);

    //reset
    task apply_reset();
        @(negedge clk);
        rst_n = 1'b0;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
    endtask


endinterface


