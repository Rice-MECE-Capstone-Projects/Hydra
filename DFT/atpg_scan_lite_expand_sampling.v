`timescale 1ns/1ps

module atpg_scan_lite;

reg  clk, reset, enable_design, scan_en, scan_in;
wire scan_out;

// active DUT-side stimulus
reg [31:0] tb_data_mem_doutb;
reg [31:0] tb_ins_data_rdata_i;
reg        tb_ins_data_rvalid_i;
reg        tb_ins_data_gnt_i;

riscv32i_main dut (
    .clk(clk), .reset(reset),
    .enable_design(enable_design),
    .scan_en(scan_en),
    .scan_in(scan_in),
    .scan_out(scan_out),
    .Cycle_count(32'b0),
    .memory_offset(32'b0),
    .initial_pc_i(32'b0),
    .final_value(),
    .data_mem_clkb(), .data_mem_enb(), .data_mem_rstb(),
    .data_mem_web(), .data_mem_addrb(), .data_mem_dinb(),
    .data_mem_rstb_busy(1'b0),
    .data_mem_doutb(tb_data_mem_doutb),
    .ins_data_req_o(), .ins_data_addr_o(), .ins_data_we_o(),
    .ins_data_be_o(), .ins_data_wdata_o(),
    .ins_data_rdata_i(tb_ins_data_rdata_i),
    .ins_data_rvalid_i(tb_ins_data_rvalid_i),
    .ins_data_gnt_i(tb_ins_data_gnt_i)
);

initial clk = 0;
always #5 clk = ~clk;

localparam CHAIN_LEN = 1604;

integer total_tests, faults_detected, faults_missed;
reg [CHAIN_LEN-1:0] golden_out, faulty_out;

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
// 1-cycle capture
// --------------------------------------------------
task do_capture;
    begin
        scan_en = 0;
        enable_design = 1;
        @(posedge clk); #1;
        enable_design = 0;
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
// deterministic patterns
// pattern_sel:
//   0 = all-0
//   1 = all-1
//   2 = alt01
//   3 = alt10
// --------------------------------------------------
function [CHAIN_LEN-1:0] gen_pattern;
    input integer pattern_sel;
    integer i;
    reg [CHAIN_LEN-1:0] tmp;
    begin
        case (pattern_sel)
            0: tmp = {CHAIN_LEN{1'b0}};
            1: tmp = {CHAIN_LEN{1'b1}};
            2: begin
                for (i = 0; i < CHAIN_LEN; i = i + 1)
                    tmp[i] = (i % 2 == 0) ? 1'b0 : 1'b1;
            end
            3: begin
                for (i = 0; i < CHAIN_LEN; i = i + 1)
                    tmp[i] = (i % 2 == 0) ? 1'b1 : 1'b0;
            end
            default: tmp = {CHAIN_LEN{1'b0}};
        endcase
        gen_pattern = tmp;
    end
endfunction

// --------------------------------------------------
// random pattern
// --------------------------------------------------
function [CHAIN_LEN-1:0] gen_random_pattern;
    input dummy;
    integer i;
    reg [CHAIN_LEN-1:0] tmp;
    begin
        for (i = 0; i < CHAIN_LEN; i = i + 1)
            tmp[i] = $random;
        gen_random_pattern = tmp;
    end
endfunction

// --------------------------------------------------
// run one pattern and compare golden/faulty
// --------------------------------------------------
task run_one_pattern_for_fault;
    input  [CHAIN_LEN-1:0] bg;
    input  integer target_bit;
    input         fault_type;   // 0=SA0, 1=SA1
    output reg    detected;

    reg [CHAIN_LEN-1:0] fp;
    begin
        detected = 0;

        // Golden run
        do_reset;
        shift_in(bg);
        do_capture;
        shift_out(golden_out);

        // Faulty run
        fp = bg;
        fp[target_bit] = fault_type ? 1'b1 : 1'b0;

        do_reset;
        shift_in(fp);
        do_capture;
        shift_out(faulty_out);

        if (faulty_out !== golden_out)
            detected = 1;
    end
endtask

// --------------------------------------------------
// test one fault:
//   SA1 -> all-0, alt01, alt10, then 5 random
//   SA0 -> all-1, alt01, alt10, then 5 random
// --------------------------------------------------
task test_one_fault;
    input integer target_bit;
    input         fault_type;   // 0=SA0, 1=SA1

    reg det;
    reg found;
    reg [CHAIN_LEN-1:0] bg;
    integer rp;
    begin
        total_tests = total_tests + 1;
        found = 0;

        if (fault_type == 1) begin
            // SA1: all-0
            bg = gen_pattern(0);
            run_one_pattern_for_fault(bg, target_bit, fault_type, det);
            if (det) found = 1;

            // SA1: alt01
            if (!found) begin
                bg = gen_pattern(2);
                run_one_pattern_for_fault(bg, target_bit, fault_type, det);
                if (det) found = 1;
            end

            // SA1: alt10
            if (!found) begin
                bg = gen_pattern(3);
                run_one_pattern_for_fault(bg, target_bit, fault_type, det);
                if (det) found = 1;
            end
        end
        else begin
            // SA0: all-1
            bg = gen_pattern(1);
            run_one_pattern_for_fault(bg, target_bit, fault_type, det);
            if (det) found = 1;

            // SA0: alt01
            if (!found) begin
                bg = gen_pattern(2);
                run_one_pattern_for_fault(bg, target_bit, fault_type, det);
                if (det) found = 1;
            end

            // SA0: alt10
            if (!found) begin
                bg = gen_pattern(3);
                run_one_pattern_for_fault(bg, target_bit, fault_type, det);
                if (det) found = 1;
            end
        end

        // 5 random patterns
        if (!found) begin
            for (rp = 0; rp < 5; rp = rp + 1) begin
                bg = gen_random_pattern(1'b0);
                run_one_pattern_for_fault(bg, target_bit, fault_type, det);
                if (det)
                    found = 1;
            end
        end

        if (found) begin
            faults_detected = faults_detected + 1;
            $display("DETECTED bit=%4d SA%0d", target_bit, fault_type);
        end
        else begin
            faults_missed = faults_missed + 1;
            $display("MISSED   bit=%4d SA%0d", target_bit, fault_type);
        end
    end
endtask

// --------------------------------------------------
// main flow
// Focus only on pipeReg0/1/2
// pipeReg1/2 use denser sampling (every 10 bits)
// pipeReg3 is excluded
// --------------------------------------------------
integer b;

initial begin
    $display("=== ATPG Scan Lite Start ===");
    $display("Expand scan bit sampling across pipeline stages (pipeReg0/1/2 only)");
    $display("Patterns used: all-0, all-1, alt01, alt10, + 5 random patterns");

    total_tests     = 0;
    faults_detected = 0;
    faults_missed   = 0;

    // active, non-zero stimulus
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

    // pipeReg0
    $display("\n[pipeReg0] Testing bits 0~24");
    for (b = 0; b <= 24; b = b + 1) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end

    $display("[pipeReg0] Testing bits 60~64");
    for (b = 60; b <= 64; b = b + 1) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end

    // pipeReg1 - expanded sampling
    $display("\n[pipeReg1] Sampling every 10 bits (65~577)");
    for (b = 65; b <= 577; b = b + 10) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end

    // pipeReg2 - expanded sampling
    $display("\n[pipeReg2] Sampling every 10 bits (578~1090)");
    for (b = 578; b <= 1090; b = b + 10) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end

    $display("\n========================================");
    $display("=== ATPG Scan Lite Results (expanded sampling on pipeReg0/1/2) ===");
    $display("Total faults tested : %0d", total_tests);
    $display("Faults detected     : %0d", faults_detected);
    $display("Faults missed       : %0d", faults_missed);
    $display("Fault coverage      : %0.2f%%",
        (total_tests > 0) ? (100.0 * faults_detected / total_tests) : 0.0);
    $display("========================================");
    $finish;
end

endmodule