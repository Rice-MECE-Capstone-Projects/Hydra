`timescale 1ns/1ps

module atpg_scan_lite;

reg  clk, reset, enable_design, scan_en, scan_in;
wire scan_out;

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
    .data_mem_rstb_busy(1'b0), .data_mem_doutb(32'b0),
    .ins_data_req_o(), .ins_data_addr_o(), .ins_data_we_o(),
    .ins_data_be_o(), .ins_data_wdata_o(),
    .ins_data_rdata_i(32'b0),
    .ins_data_rvalid_i(1'b0),
    .ins_data_gnt_i(1'b0)
);

initial clk = 0;
always #5 clk = ~clk;

localparam CHAIN_LEN = 1604;

integer total_tests, faults_detected, faults_missed;
reg [CHAIN_LEN-1:0] golden_out, faulty_out;

// reset
task do_reset;
    begin
        reset = 1; scan_en = 0; enable_design = 0; scan_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0; #1;
    end
endtask

// shift-in
task shift_in;
    input [CHAIN_LEN-1:0] pattern;
    integer i;
    begin
        scan_en = 1; enable_design = 0;
        for (i = CHAIN_LEN-1; i >= 0; i = i - 1) begin
            scan_in = pattern[i];
            @(posedge clk); #1;
        end
        scan_en = 0; scan_in = 0;
    end
endtask

// capture
task do_capture;
    begin
        scan_en = 0; enable_design = 1;
        @(posedge clk); #1;
        enable_design = 0;
    end
endtask

// shift-out
task shift_out;
    output [CHAIN_LEN-1:0] result;
    integer i;
    begin
        scan_en = 1; enable_design = 0; scan_in = 0;
        for (i = CHAIN_LEN-1; i >= 0; i = i - 1) begin
            @(posedge clk); #1;
            result[i] = scan_out;
        end
        scan_en = 0;
    end
endtask

// test single fault
// fault_type: 0=SA0, 1=SA1
task test_one_fault;
    input integer target_bit;
    input         fault_type;

    reg [CHAIN_LEN-1:0] bg, fp;
    reg det;
    begin
        total_tests = total_tests + 1;
        det = 0;

        // SA1 test 0，SA0 test 1
        if (fault_type == 1)
            bg = {CHAIN_LEN{1'b0}};
        else
            bg = {CHAIN_LEN{1'b1}};

        // Golden
        do_reset;
        shift_in(bg);
        do_capture;
        shift_out(golden_out);

        // input fault
        fp = bg;
        fp[target_bit] = fault_type ? 1'b1 : 1'b0;
        do_reset;
        shift_in(fp);
        do_capture;
        shift_out(faulty_out);

        // compare
        if (faulty_out !== golden_out) det = 1;

        if (det) begin
            faults_detected = faults_detected + 1;
            $display("DETECTED bit=%4d SA%0d", target_bit, fault_type);
        end else begin
            faults_missed = faults_missed + 1;
            $display("MISSED   bit=%4d SA%0d", target_bit, fault_type);
        end
    end
endtask

// sampling strategy
integer b;

initial begin
    $display("=== ATPG Scan Lite Start ===");
    $display("Sampling strategy: representative bits from each pipeline register");
    total_tests     = 0;
    faults_detected = 0;
    faults_missed   = 0;

    clk = 0; reset = 1; scan_en = 0;
    enable_design = 0; scan_in = 0;
    #20;

    // --- pipeReg0: bit 0~64
    $display("\n[pipeReg0] Testing bits 0~24 (low bits = control signals)");
    for (b = 0; b <= 24; b = b + 1) begin
        test_one_fault(b, 1);  // SA1
        test_one_fault(b, 0);  // SA0
    end
    $display("[pipeReg0] Testing bits 60~64 (high bits)");
    for (b = 60; b <= 64; b = b + 1) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end
    $display("[pipeReg0] done. detected=%0d/%0d", faults_detected, total_tests);

    // --- pipeReg1: bit 65~577---
    $display("\n[pipeReg1] Sampling every 20 bits (65~577)");
    for (b = 65; b <= 577; b = b + 20) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end
    $display("[pipeReg1] done. detected=%0d/%0d", faults_detected, total_tests);

    // --- pipeReg2: bit 578~1090 ---
    $display("\n[pipeReg2] Sampling every 20 bits (578~1090)");
    for (b = 578; b <= 1090; b = b + 20) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end
    $display("[pipeReg2] done. detected=%0d/%0d", faults_detected, total_tests);

    // --- pipeReg3: bit 1091~1603 ---
    $display("\n[pipeReg3] Sampling every 20 bits (1091~1603)");
    for (b = 1091; b <= 1603; b = b + 20) begin
        test_one_fault(b, 1);
        test_one_fault(b, 0);
    end
    $display("[pipeReg3] done. detected=%0d/%0d", faults_detected, total_tests);

    $display("\n========================================");
    $display("=== ATPG Scan Lite Results ===");
    $display("Total faults tested : %0d", total_tests);
    $display("Faults detected     : %0d", faults_detected);
    $display("Faults missed       : %0d", faults_missed);
    $display("Fault coverage      : %0.2f%%",
        (total_tests > 0) ? (100.0 * faults_detected / total_tests) : 0.0);
    $display("Note: Sampled %0d bits out of 1604 total", total_tests/2);
    $display("========================================");
    $finish;
end

endmodule
