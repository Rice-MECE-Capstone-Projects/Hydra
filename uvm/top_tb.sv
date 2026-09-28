`timescale 1ns/1ps

module top_tb;
    import uvm_pkg::*;
    import hydra_pkg::*;
    import hydra_uvm_pkg::*;

    // clock and reset
    logic clk=1'b0;
    //logic rst_n=1'b0;

    // status inputs to MMR
    logic done = 1'b0;
    logic error = 1'b0;

    // control outputs from MMR
    logic                   start;
    hydra_mode              mode;
    logic [DATA_BITS-1:0]   scale_shift;
    logic                   signed_out;
    logic                   round_en;
    logic [ADDR_WIDTH-1:0]  src_addr;
    logic [ADDR_WIDTH-1:0]  dst_addr;
    logic [LEN_WIDTH-1:0]   length;

    // 10ns
    always #5 clk=~clk;

    // release reset on a falling edge
    /*initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
    end*/

    // instantiate the if
    cpu_ahb_if ahb_if(
        .clk (clk)
        //.rst_n (rst_n)
    );

    // Startup reset
    initial begin
        ahb_if.apply_reset();
    end

    // DUT instance
    hydra_mmr dut(
        .clk (clk),
        .rst_n (ahb_if.rst_n),
        .done (done),
        .error (error),
        .HADDR  (ahb_if.HADDR),
        .HWDATA (ahb_if.HWDATA),
        .HWRITE (ahb_if.HWRITE),
        .HTRANS (ahb_if.HTRANS),
        .HSEL   (ahb_if.HSEL),
        .HREADY (ahb_if.HREADY),
        .HRDATA (ahb_if.HRDATA),
        .HREADYOUT (ahb_if.HREADYOUT),
        .HRESP  (ahb_if.HRESP),

        .start  (start),
        .mode   (mode),
        .scale_shift(scale_shift),
        .signed_out(signed_out),
        .round_en(round_en),
        .src_addr(src_addr),
        .dst_addr(dst_addr),
        .length (length)
    );

    //configure the virtual interface and start UVM
    initial begin
        uvm_config_db#(virtual cpu_ahb_if)::set(null,"*","vif",ahb_if);
        run_test("mmr_reset_test");
    end
endmodule


