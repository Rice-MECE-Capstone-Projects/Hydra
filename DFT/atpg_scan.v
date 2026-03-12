`timescale 1ns/1ps

module atpg_scan;

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

localparam CHAIN_LEN = 1604;

integer total_tests, faults_detected, faults_missed;


reg [CHAIN_LEN-1:0] golden_out;
reg [CHAIN_LEN-1:0] faulty_out;


task do_reset;
    begin
        reset = 1; scan_en = 0; enable_design = 0; scan_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
        #1;
    end
endtask


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


task do_capture;
    begin
        scan_en = 0;
        enable_design = 1;
        @(posedge clk); #1;
        enable_design = 0;
    end
endtask


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

task test_fault;
    input integer      target_bit;
    input              fault_type;
    input [CHAIN_LEN-1:0] bg_pattern;

    reg [CHAIN_LEN-1:0] faulty_pattern;
    reg detected;
    begin
        total_tests = total_tests + 1;
        detected = 0;

     
        do_reset;
        shift_in(bg_pattern);
        do_capture;
        shift_out(golden_out);

    
        faulty_pattern = bg_pattern;
        faulty_pattern[target_bit] = fault_type ? 1'b1 : 1'b0;

        do_reset;
        shift_in(faulty_pattern);
        do_capture;
        shift_out(faulty_out);

        // compare
        if (faulty_out !== golden_out)
            detected = 1;

        if (detected)
            faults_detected = faults_detected + 1;
        else
            faults_missed = faults_missed + 1;
    end
endtask

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

  
    pat_zeros = {CHAIN_LEN{1'b0}};
    pat_ones  = {CHAIN_LEN{1'b1}};
    
    begin : init_alt
        integer k;
        for (k = 0; k < CHAIN_LEN; k = k + 1) begin
            pat_alt01[k] = k[0];      
            pat_alt10[k] = ~k[0];     
        end
    end
    patterns[0] = pat_zeros;
    patterns[1] = pat_ones;
    patterns[2] = pat_alt01;
    patterns[3] = pat_alt10;

    clk = 0; reset = 1; scan_en = 0;
    enable_design = 0; scan_in = 0;
    #20;

    for (b = 0; b < CHAIN_LEN; b = b + 1) begin
        fault_already_detected = 0;

        
        if (!fault_already_detected) begin
            total_tests = total_tests + 1;
            begin : sa1_test
                reg [CHAIN_LEN-1:0] fp, go, fo;
                reg det;
                det = 0;
                fp = pat_zeros;
                fp[b] = 1'b1; 
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

        fault_already_detected = 0;
        begin : sa0_test
            reg [CHAIN_LEN-1:0] fp, go, fo;
            reg det;
            det = 0;
            fp = pat_ones;
            fp[b] = 1'b0;  
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
