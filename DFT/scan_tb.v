`timescale 1ns/1ps

module scan_tb;

reg clk;
reg reset;
reg enable_design;
reg scan_en;
reg scan_in;
wire scan_out;


wire STOP_sim;

riscv32i_main dut (
    .clk(clk),
    .reset(reset),
    .enable_design(enable_design),
    .scan_en(scan_en),
    .scan_in(scan_in),
    .scan_out(scan_out),

    .Cycle_count(32'b0),
    .memory_offset(32'b0),
    .initial_pc_i(32'b0),
    .final_value(),

    .data_mem_clkb(),
    .data_mem_enb(),
    .data_mem_rstb(),
    .data_mem_web(),
    .data_mem_addrb(),
    .data_mem_dinb(),
    .data_mem_rstb_busy(1'b0),
    .data_mem_doutb(32'b0),

    .ins_data_req_o(),
    .ins_data_addr_o(),
    .ins_data_we_o(),
    .ins_data_be_o(),
    .ins_data_wdata_o(),
    .ins_data_rdata_i(32'b0),
    .ins_data_rvalid_i(1'b0),
    .ins_data_gnt_i(1'b0)
);

integer i;

always #5 clk = ~clk;

initial begin
    clk = 0;
    reset = 1;
    enable_design = 0;
    scan_en = 0;
    scan_in = 0;

    #20;
    reset = 0;


    scan_en = 1;

 
    for (i = 0; i < 1604; i = i + 1) begin
        scan_in = i % 2;
        #10;
    end

     $display("After 1604 shifts, scan_out = %b at time %t", scan_out, $time);

    for (i = 0; i < 20; i = i + 1) begin
        scan_in = 0;
        #10;
        $display("Extra shift %0d: scan_out=%b", i, scan_out);
    end

    scan_en = 0;

    #100;
    $finish;
end

always @(posedge clk) begin
    if (scan_en)
        $display("T=%0t scan_in=%b scan_out=%b", $time, scan_in, scan_out);
end

endmodule