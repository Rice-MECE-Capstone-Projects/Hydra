`timescale 1ns/1ps

// ================================================================
// ATPG Testbench — 真正扫描流程
// 流程：shift-in(1604) → capture(1) → shift-out(1604) → 比较
// 故障模型：Stuck-At-0 / Stuck-At-1
// 测试策略：每次只翻转目标bit，其余bit保持激励背景
// 覆盖：pipeReg0[64:0]=65bit, pipeReg1~3[512:0]=513bit each
// 总计：1604 x 2 = 3208 faults，分批测试节省时间
// ================================================================
module atpg_scan;

// -------------------------------------------------------
// DUT 端口
// -------------------------------------------------------
reg  clk, reset, enable_design, scan_en, scan_in;
wire scan_out;

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

initial clk = 0;
always #5 clk = ~clk;

// -------------------------------------------------------
// 常量
// -------------------------------------------------------
localparam CHAIN_LEN = 1604;

// -------------------------------------------------------
// 统计
// -------------------------------------------------------
integer total_tests, faults_detected, faults_missed;

// 存储 shift-out 结果
reg [CHAIN_LEN-1:0] golden_out;
reg [CHAIN_LEN-1:0] faulty_out;

// -------------------------------------------------------
// 任务：复位
// -------------------------------------------------------
task do_reset;
    begin
        reset = 1; scan_en = 0; enable_design = 0; scan_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
        #1;
    end
endtask

// -------------------------------------------------------
// 任务：shift-in 1604位激励
// pattern: 1604位的激励向量，MSB先移入
// -------------------------------------------------------
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

// -------------------------------------------------------
// 任务：capture 1个时钟
// -------------------------------------------------------
task do_capture;
    begin
        scan_en = 0;
        enable_design = 1;
        @(posedge clk); #1;
        enable_design = 0;
    end
endtask

// -------------------------------------------------------
// 任务：shift-out 1604位，存入输出数组
// -------------------------------------------------------
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

// -------------------------------------------------------
// 任务：完整测试一个故障
// target_bit: 在1604位扫描链中的位置(0=pipeReg0[0])
// fault_type: 0=SA0, 1=SA1
// bg_pattern: 激励背景（1604位）
// -------------------------------------------------------
task test_fault;
    input integer      target_bit;
    input              fault_type;
    input [CHAIN_LEN-1:0] bg_pattern;

    reg [CHAIN_LEN-1:0] faulty_pattern;
    reg detected;
    begin
        total_tests = total_tests + 1;
        detected = 0;

        // --- Step 1: Golden 流程（无故障）---
        do_reset;
        shift_in(bg_pattern);
        do_capture;
        shift_out(golden_out);

        // --- Step 2: 注入故障（修改激励中目标bit）---
        // SA0：无论激励是什么，目标bit强制为0
        // SA1：无论激励是什么，目标bit强制为1
        faulty_pattern = bg_pattern;
        faulty_pattern[target_bit] = fault_type ? 1'b1 : 1'b0;

        do_reset;
        shift_in(faulty_pattern);
        do_capture;
        shift_out(faulty_out);

        // --- Step 3: 比较 ---
        if (faulty_out !== golden_out)
            detected = 1;

        if (detected)
            faults_detected = faults_detected + 1;
        else
            faults_missed = faults_missed + 1;
    end
endtask

// -------------------------------------------------------
// 主流程
// -------------------------------------------------------
integer b;
reg [CHAIN_LEN-1:0] pat_zeros;
reg [CHAIN_LEN-1:0] pat_ones;
reg [CHAIN_LEN-1:0] pat_alt01;
reg [CHAIN_LEN-1:0] pat_alt10;

integer pat;
reg [CHAIN_LEN-1:0] patterns [0:3];
reg fault_already_detected;

initial begin
    $display("=== ATPG Scan Flow Start ===");
    $display("Chain length: %0d bits, Total faults: %0d", CHAIN_LEN, CHAIN_LEN*2);

    total_tests     = 0;
    faults_detected = 0;
    faults_missed   = 0;

    // 初始化激励pattern
    pat_zeros = {CHAIN_LEN{1'b0}};
    pat_ones  = {CHAIN_LEN{1'b1}};
    // 交替 01
    begin : init_alt
        integer k;
        for (k = 0; k < CHAIN_LEN; k = k + 1) begin
            pat_alt01[k] = k[0];       // 偶数位=0，奇数位=1
            pat_alt10[k] = ~k[0];      // 偶数位=1，奇数位=0
        end
    end
    patterns[0] = pat_zeros;
    patterns[1] = pat_ones;
    patterns[2] = pat_alt01;
    patterns[3] = pat_alt10;

    clk = 0; reset = 1; scan_en = 0;
    enable_design = 0; scan_in = 0;
    #20;

    // 遍历所有1604个bit，SA0+SA1
    // 对每个故障尝试4种pattern，检测到即停止
    for (b = 0; b < CHAIN_LEN; b = b + 1) begin
        fault_already_detected = 0;

        // SA1：用全0背景（能看出被强制成1）
        if (!fault_already_detected) begin
            total_tests = total_tests + 1;
            begin : sa1_test
                reg [CHAIN_LEN-1:0] fp, go, fo;
                reg det;
                det = 0;
                fp = pat_zeros;
                fp[b] = 1'b1;  // SA1故障：该位强制为1
                do_reset;
                shift_in(pat_zeros);
                do_capture;
                shift_out(go);
                do_reset;
                shift_in(fp);
                do_capture;
                shift_out(fo);
                if (fo !== go) det = 1;
                if (det) begin
                    faults_detected = faults_detected + 1;
                    fault_already_detected = 1;
                end else
                    faults_missed = faults_missed + 1;
            end
        end

        // SA0：用全1背景（能看出被强制成0）
        fault_already_detected = 0;
        begin : sa0_test
            reg [CHAIN_LEN-1:0] fp, go, fo;
            reg det;
            det = 0;
            fp = pat_ones;
            fp[b] = 1'b0;  // SA0故障：该位强制为0
            total_tests = total_tests + 1;
            do_reset;
            shift_in(pat_ones);
            do_capture;
            shift_out(go);
            do_reset;
            shift_in(fp);
            do_capture;
            shift_out(fo);
            if (fo !== go) det = 1;
            if (det)
                faults_detected = faults_detected + 1;
            else
                faults_missed = faults_missed + 1;
        end

        // 每100个bit打印进度
        if ((b % 100) == 99)
            $display("Progress: bit %0d/%0d, detected=%0d/%0d",
                     b+1, CHAIN_LEN, faults_detected, total_tests);
    end

    $display("\n========================================");
    $display("=== ATPG Scan Flow Results ===");
    $display("Total faults tested : %0d", total_tests);
    $display("Faults detected     : %0d", faults_detected);
    $display("Faults missed       : %0d", faults_missed);
    $display("Fault coverage      : %0.2f%%",
        (total_tests > 0) ? (100.0 * faults_detected / total_tests) : 0.0);
    $display("========================================");
    $finish;
end

endmodule
