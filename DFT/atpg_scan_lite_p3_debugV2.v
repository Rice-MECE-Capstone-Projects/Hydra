`timescale 1ns/1ps
`include "params.vh"

module atpg_pr3_debug_fields_tb;

reg  clk, reset, enable_design, scan_en, scan_in;
wire scan_out;

// active DUT-side stimulus
reg [31:0] tb_data_mem_doutb;
reg [31:0] tb_ins_data_rdata_i;
reg        tb_ins_data_rvalid_i;
reg        tb_ins_data_gnt_i;

localparam CHAIN_LEN  = 1604;
localparam TARGET_BIT = 1161;   // change to 1171 / 1181 if needed
localparam FAULT_TYPE = 1'b0;   // 0 = SA0, 1 = SA1

reg [CHAIN_LEN-1:0] golden_out, faulty_out;
reg [CHAIN_LEN-1:0] bg_pattern;
reg [CHAIN_LEN-1:0] faulty_pattern;

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
    .data_mem_doutb(tb_data_mem_doutb),
    .ins_data_req_o(),
    .ins_data_addr_o(),
    .ins_data_we_o(),
    .ins_data_be_o(),
    .ins_data_wdata_o(),
    .ins_data_rdata_i(tb_ins_data_rdata_i),
    .ins_data_rvalid_i(tb_ins_data_rvalid_i),
    .ins_data_gnt_i(tb_ins_data_gnt_i)
);

initial clk = 0;
always #5 clk = ~clk;

// --------------------------------------------------
// reset
// --------------------------------------------------
task do_reset;
begin
    reset = 1;
    scan_en = 0;
    enable_design = 0;
    scan_in = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    reset = 0; #1;
end
endtask

// --------------------------------------------------
// shift-in
// --------------------------------------------------
task shift_in;
input [CHAIN_LEN-1:0] pattern;
integer i;
begin
    scan_en = 1;
    enable_design = 0;
    for (i = CHAIN_LEN-1; i >= 0; i = i - 1) begin
        scan_in = pattern[i];
        @(posedge clk); #1;
    end
    scan_en = 0;
    scan_in = 0;
end
endtask

// --------------------------------------------------
// shift-out
// --------------------------------------------------
task shift_out;
output [CHAIN_LEN-1:0] result;
integer i;
begin
    scan_en = 1;
    enable_design = 0;
    scan_in = 0;
    for (i = CHAIN_LEN-1; i >= 0; i = i - 1) begin
        @(posedge clk); #1;
        result[i] = scan_out;
    end
    scan_en = 0;
end
endtask

// --------------------------------------------------
// make background pattern
// --------------------------------------------------
task make_background_pattern;
input fault_type;
output [CHAIN_LEN-1:0] pattern;
begin
    if (fault_type == 1'b1)
        pattern = {CHAIN_LEN{1'b0}};  // SA1: start from all-0
    else
        pattern = {CHAIN_LEN{1'b1}};  // SA0: start from all-1
end
endtask

// --------------------------------------------------
// pretty-print pipeReg3 fields
// requires params macros already used by design
// --------------------------------------------------
task dump_pipeReg3_fields;
input [8*20:1] tag;
begin
    $display("[%0s] pipeReg3                = %h", tag, dut.pipeReg3);
    $display("[%0s] pipeReg3_wire           = %h", tag, dut.pipeReg3_wire);

    $display("[%0s] PC_reg                  = %h", tag, dut.pipeReg3[`PC_reg]);
    $display("[%0s] instruct                = %h", tag, dut.pipeReg3[`instruct]);
    $display("[%0s] alu_res1                = %h", tag, dut.pipeReg3[`alu_res1]);
    $display("[%0s] load_reg                = %b", tag, dut.pipeReg3[`load_reg]);
    $display("[%0s] jump_en                 = %b", tag, dut.pipeReg3[`jump_en]);
    $display("[%0s] branch_en               = %b", tag, dut.pipeReg3[`branch_en]);
    $display("[%0s] reg_write_en            = %b", tag, dut.pipeReg3[`reg_write_en]);
    $display("[%0s] LD_ready                = %b", tag, dut.pipeReg3[`LD_ready]);
    $display("[%0s] SD_ready                = %b", tag, dut.pipeReg3[`SD_ready]);
    $display("[%0s] rd                      = %h", tag, dut.pipeReg3[`rd]);
    $display("[%0s] operand_amt             = %h", tag, dut.pipeReg3[`operand_amt]);
    $display("[%0s] opRs1_reg               = %h", tag, dut.pipeReg3[`opRs1_reg]);
    $display("[%0s] opRs2_reg               = %h", tag, dut.pipeReg3[`opRs2_reg]);
    $display("[%0s] op1_reg                 = %h", tag, dut.pipeReg3[`op1_reg]);
    $display("[%0s] op2_reg                 = %h", tag, dut.pipeReg3[`op2_reg]);
    $display("[%0s] immediate               = %h", tag, dut.pipeReg3[`immediate]);
    $display("[%0s] alu_res2                = %h", tag, dut.pipeReg3[`alu_res2]);
    $display("[%0s] rd_data                 = %h", tag, dut.pipeReg3[`rd_data]);
    $display("[%0s] Single_Instruction      = %h", tag, dut.pipeReg3[`Single_Instruction]);
    $display("[%0s] data_mem_loaded         = %h", tag, dut.pipeReg3[`data_mem_loaded]);
    $display("[%0s] branch_predicted        = %b", tag, dut.pipeReg3[`branch_predicted]);

    $display("[%0s] wire.PC_reg             = %h", tag, dut.pipeReg3_wire[`PC_reg]);
    $display("[%0s] wire.instruct           = %h", tag, dut.pipeReg3_wire[`instruct]);
    $display("[%0s] wire.alu_res1           = %h", tag, dut.pipeReg3_wire[`alu_res1]);
    $display("[%0s] wire.load_reg           = %b", tag, dut.pipeReg3_wire[`load_reg]);
    $display("[%0s] wire.reg_write_en       = %b", tag, dut.pipeReg3_wire[`reg_write_en]);
    $display("[%0s] wire.rd                 = %h", tag, dut.pipeReg3_wire[`rd]);
    $display("[%0s] wire.op1_reg            = %h", tag, dut.pipeReg3_wire[`op1_reg]);
    $display("[%0s] wire.op2_reg            = %h", tag, dut.pipeReg3_wire[`op2_reg]);
    $display("[%0s] wire.immediate          = %h", tag, dut.pipeReg3_wire[`immediate]);
    $display("[%0s] wire.alu_res2           = %h", tag, dut.pipeReg3_wire[`alu_res2]);
    $display("[%0s] wire.data_mem_loaded    = %h", tag, dut.pipeReg3_wire[`data_mem_loaded]);
    $display("[%0s] wire.branch_predicted   = %b", tag, dut.pipeReg3_wire[`branch_predicted]);

    $display("[%0s] stage3_MEM_valid        = %b", tag, dut.stage3_MEM_valid);
    $display("[%0s] stage2_EXEC_valid       = %b", tag, dut.stage2_EXEC_valid);
    $display("[%0s] enable_design           = %b", tag, dut.enable_design);
    $display("[%0s] delete_reg1_reg2_reg    = %b", tag, dut.delete_reg1_reg2_reg);
    $display("[%0s] load_into_reg           = %b", tag, dut.load_into_reg);
    $display("[%0s] write_reg_file_wire_s2  = %b", tag, dut.write_reg_file_wire_stage2);
end
endtask

// --------------------------------------------------
// debug capture
// --------------------------------------------------
task do_capture_debug;
begin
    $display("--------------------------------------------------");
    dump_pipeReg3_fields("BEFORE_CAPTURE");

    scan_en = 0;
    enable_design = 1;
    @(posedge clk); #1;
    enable_design = 0;

    dump_pipeReg3_fields("AFTER_CAPTURE");
    $display("--------------------------------------------------");
end
endtask

// --------------------------------------------------
// main diagnostic flow
// --------------------------------------------------
initial begin
    $display("=== pipeReg3 field-level root-cause debug ===");
    $display("TARGET_BIT = %0d, FAULT_TYPE = SA%0d", TARGET_BIT, FAULT_TYPE);

    tb_data_mem_doutb    = 32'hA5A5_5A5A;
    tb_ins_data_rdata_i  = 32'h1234_5678;
    tb_ins_data_rvalid_i = 1'b1;
    tb_ins_data_gnt_i    = 1'b1;

    clk = 0;
    reset = 1;
    scan_en = 0;
    enable_design = 0;
    scan_in = 0;
    #20;

    make_background_pattern(FAULT_TYPE, bg_pattern);
    faulty_pattern = bg_pattern;
    faulty_pattern[TARGET_BIT] = FAULT_TYPE ? 1'b1 : 1'b0;

    // --------------------------
    // GOLDEN
    // --------------------------
    $display("\n=== GOLDEN RUN ===");
    do_reset;
    shift_in(bg_pattern);
    $display("Golden after shift_in:");
    $display("  pipeReg3 = %h", dut.pipeReg3);
    $display("  local_bit_index=%0d value=%b", TARGET_BIT-1091, dut.pipeReg3[TARGET_BIT-1091]);

    do_capture_debug;

    $display("Golden before shift_out:");
    $display("  pipeReg3 = %h", dut.pipeReg3);
    shift_out(golden_out);

    // --------------------------
    // FAULTY
    // --------------------------
    $display("\n=== FAULTY RUN ===");
    do_reset;
    shift_in(faulty_pattern);
    $display("Faulty after shift_in:");
    $display("  pipeReg3 = %h", dut.pipeReg3);
    $display("  local_bit_index=%0d value=%b", TARGET_BIT-1091, dut.pipeReg3[TARGET_BIT-1091]);

    do_capture_debug;

    $display("Faulty before shift_out:");
    $display("  pipeReg3 = %h", dut.pipeReg3);
    shift_out(faulty_out);

    // --------------------------
    // Compare
    // --------------------------
    $display("\n=== COMPARISON ===");
    $display("golden_out = %h", golden_out);
    $display("faulty_out = %h", faulty_out);

    if (golden_out !== faulty_out)
        $display("RESULT: DETECTED");
    else
        $display("RESULT: MISSED");

    $finish;
end

endmodule