`timescale 1ns/1ps

module alu_scoreboard (
    input logic        clk,
    input logic        valid,

    // Instruction context for debug/logging
    input logic [31:0] pc,
    input logic [31:0] instruction,
    input logic [63:0] single_instruction,

    // DUT execute-stage outputs
    input logic [31:0] dut_alu_result_1,
    input logic [31:0] dut_alu_result_2,
    input logic        dut_branch_inst,
    input logic        dut_jump_inst,
    input logic        dut_write_reg,

    // Golden/reference outputs
    input logic [31:0] gold_alu_result_1,
    input logic [31:0] gold_alu_result_2,
    input logic        gold_branch_inst,
    input logic        gold_jump_inst,
    input logic        gold_write_reg
);

    // Basic scoreboard statistics
    integer total = 0;
    integer num_matches = 0;
    integer num_mismatches = 0;

    // Track PCs where mismatches occurred
    int unsigned mismatch_pc_list [10000];
    integer mismatch_idx = 0;

    always @(posedge clk) begin
        if (valid) begin
            total++;

            // Compare DUT outputs against golden model
            if (
                dut_alu_result_1 === gold_alu_result_1 &&
                dut_alu_result_2 === gold_alu_result_2 &&
                dut_branch_inst  === gold_branch_inst  &&
                dut_jump_inst    === gold_jump_inst    &&
                dut_write_reg    === gold_write_reg
            ) begin
                num_matches++;

                // Verbose success logging
                $display("[ALU MATCH @ PC=%h] instr=%h type=%h alu1=%h alu2=%h br=%b jmp=%b wr=%b",
                    pc,
                    instruction,
                    single_instruction,
                    dut_alu_result_1,
                    dut_alu_result_2,
                    dut_branch_inst,
                    dut_jump_inst,
                    dut_write_reg
                );

            end else begin
                num_mismatches++;
                mismatch_pc_list[mismatch_idx++] = pc;

                // Print mismatch details
                $display("\n[ALU MISMATCH @ PC=%h] instr=%h type=%h",
                    pc,
                    instruction,
                    single_instruction
                );

                $display("  DUT : alu1=%h alu2=%h br=%b jmp=%b wr=%b",
                    dut_alu_result_1,
                    dut_alu_result_2,
                    dut_branch_inst,
                    dut_jump_inst,
                    dut_write_reg
                );

                $display("  GOLD: alu1=%h alu2=%h br=%b jmp=%b wr=%b",
                    gold_alu_result_1,
                    gold_alu_result_2,
                    gold_branch_inst,
                    gold_jump_inst,
                    gold_write_reg
                );
            end
        end
    end

    // Manual summary task called before simulation finish
    task print_summary();
        integer i;

        $display("\n-----------------------------------------------");
        $display("              ALU SCOREBOARD                   ");
        $display("-----------------------------------------------");
        $display("Total Valid ALU Checks : %0d", total);
        $display("Matches                : %0d", num_matches);
        $display("Mismatches             : %0d", num_mismatches);

        // Print all PCs that failed
        if (num_mismatches > 0) begin
            $display("Mismatched PCs:");
            for (i = 0; i < mismatch_idx; i++) begin
                $display("  %h", mismatch_pc_list[i]);
            end
        end

        // Final pass/fail status
        if (num_mismatches == 0)
            $display("ALU SCOREBOARD PASSED");
        else
            $display("ALU SCOREBOARD FAILED");

        $display("-----------------------------------------------\n");
    endtask

endmodule