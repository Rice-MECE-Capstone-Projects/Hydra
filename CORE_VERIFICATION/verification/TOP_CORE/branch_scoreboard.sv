`timescale 1ns/1ps

module branch_scoreboard (
    input logic        clk,
    input logic        valid,

    // Instruction context for debug/logging
    input logic [31:0] pc,
    input logic [31:0] instruction,
    input logic [63:0] single_instruction,

    // DUT branch/jump outputs
    input logic        dut_branch_taken,
    input logic        dut_jump_taken,
    input logic [31:0] dut_target_pc,

    // Golden/reference branch/jump outputs
    input logic        gold_branch_taken,
    input logic        gold_jump_taken,
    input logic [31:0] gold_target_pc
);

    // Basic scoreboard statistics
    integer total = 0;
    integer num_matches = 0;
    integer num_mismatches = 0;

    // Track mismatch PCs
    int unsigned mismatch_pc_list [10000];
    integer mismatch_idx = 0;

    always @(posedge clk) begin
        if (valid) begin
            total++;

            // Compare branch/jump control and target PC
            if (
                dut_branch_taken === gold_branch_taken &&
                dut_jump_taken   === gold_jump_taken   &&
                dut_target_pc    === gold_target_pc
            ) begin
                num_matches++;

                $display("[BRANCH MATCH @ PC=%h] instr=%h type=%h target=%h br=%b jmp=%b",
                    pc,
                    instruction,
                    single_instruction,
                    dut_target_pc,
                    dut_branch_taken,
                    dut_jump_taken
                );

            end else begin
                num_mismatches++;
                mismatch_pc_list[mismatch_idx++] = pc;

                $display("\n[BRANCH MISMATCH @ PC=%h] instr=%h type=%h",
                    pc,
                    instruction,
                    single_instruction
                );

                $display("  DUT : target=%h br=%b jmp=%b",
                    dut_target_pc,
                    dut_branch_taken,
                    dut_jump_taken
                );

                $display("  GOLD: target=%h br=%b jmp=%b",
                    gold_target_pc,
                    gold_branch_taken,
                    gold_jump_taken
                );
            end
        end
    end

    // Manual summary task called before simulation finish
    task print_summary();
        integer i;

        $display("\n-----------------------------------------------");
        $display("            BRANCH SCOREBOARD                  ");
        $display("-----------------------------------------------");
        $display("Total Valid Branch Checks : %0d", total);
        $display("Matches                   : %0d", num_matches);
        $display("Mismatches                : %0d", num_mismatches);

        // Print all PCs that failed
        if (num_mismatches > 0) begin
            $display("Mismatched PCs:");
            for (i = 0; i < mismatch_idx; i++) begin
                $display("  %h", mismatch_pc_list[i]);
            end
        end

        // Final pass/fail status
        if (num_mismatches == 0)
            $display("BRANCH SCOREBOARD PASSED");
        else
            $display("BRANCH SCOREBOARD FAILED");

        $display("-----------------------------------------------\n");
    endtask

endmodule