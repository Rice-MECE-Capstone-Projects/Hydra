// Begin contents of params.vh
`ifndef PARAMS_VH
`define PARAMS_VH


`define PC_reg              31:00   //[31:00]
`define instruct            63:32   //[31:00]
`define alu_res1            95:64   //[31:00]
`define load_reg           101
`define jump_en            102     //[ 4:0]
`define branch_en          103     //[ 4:0]
`define reg_write_en       104     //[ 4:0]
`define LD_ready           105     //[ 4:0]
`define SD_ready           106     //[ 4:0]
`define rd                 111:107 //[ 4:0]
`define operand_amt        115:112 //[ 3:0]
`define opRs1_reg          120:116 //[4:0]
`define opRs2_reg          127:121 //[4:0]
`define op1_reg            159:128 //[31:00]
`define op2_reg            191:160 //[31:00]
`define immediate          223:192 //[31:0]
`define alu_res2           255:224 //[31:0]
`define rd_data            287:256 //[31:0]
`define Single_Instruction 351:288 //[63:00]   
`define data_mem_loaded    383:352  

// Opcode Decoding Type
`define R_Type            7'b0110011 //0110011
`define I_Type_A          7'b0010011 // 0010011
`define I_Type_L          7'b0000011
`define S_Type            7'b0100011
`define B_Type            7'b1100011
`define J_Type_lk         7'b1101111
`define I_Type_JALR       7'b1100111
`define U_Type_lui        7'b0110111
`define U_Type_auipc      7'b0010111
`define I_Type_ECALL      7'b1110011
`define F_TYPE_FENCE      7'b0001111
`define NOOP             32'h00000013


`define ONE_OP      4'b0001
`define TWO_OP      4'b0010


// Encoding Type
`define INST_typ_R             7'b0000001
`define INST_typ_I             7'b0000010
`define INST_typ_I_ECALL       7'b1000010
`define INST_typ_S             7'b0000100
`define INST_typ_B             7'b0001000
`define INST_typ_U             7'b0010000
`define INST_typ_J             7'b0100000
`define INST_typ_F             7'b1000000
`define UNRECGONIZED           7'b0000000

// Instructions
`define inst_UNKNOWN    64'h0000_0000_0000_0000
`define inst_ADD    64'h0000_0000_0000_0001
`define inst_SUB    64'h0000_0000_0000_0002
`define inst_XOR    64'h0000_0000_0000_0004
`define inst_OR     64'h0000_0000_0000_0008

`define inst_AND    64'h0000_0000_0000_0010
`define inst_SLL    64'h0000_0000_0000_0020
`define inst_SRL    64'h0000_0000_0000_0040
`define inst_SRA    64'h0000_0000_0000_0080

`define inst_SLT    64'h0000_0000_0000_0100
`define inst_SLTU   64'h0000_0000_0000_0200
`define inst_ADDI   64'h0000_0000_0000_0400
`define inst_XORI   64'h0000_0000_0000_0800

`define inst_ORI    64'h0000_0000_0000_1000
`define inst_ANDI   64'h0000_0000_0000_2000
`define inst_SLLI   64'h0000_0000_0000_4000
`define inst_SRLI   64'h0000_0000_0000_8000

`define inst_SRAI   64'h0000_0000_0001_0000
`define inst_SLTI   64'h0000_0000_0002_0000
`define inst_SLTIU  64'h0000_0000_0004_0000
`define inst_LB     64'h0000_0000_0008_0000

`define inst_LH     64'h0000_0000_0010_0000
`define inst_LW     64'h0000_0000_0020_0000
`define inst_LBU    64'h0000_0000_0040_0000
`define inst_LHU    64'h0000_0000_0080_0000

`define inst_SB     64'h0000_0000_0100_0000
`define inst_SH     64'h0000_0000_0200_0000
`define inst_SW     64'h0000_0000_0400_0000
`define inst_BEQ    64'h0000_0000_0800_0000

`define inst_BNE    64'h0000_0000_1000_0000
`define inst_BLT    64'h0000_0000_2000_0000
`define inst_BGE    64'h0000_0000_4000_0000
`define inst_BLTU   64'h0000_0000_8000_0000

`define inst_BGEU   64'h0000_0001_0000_0000
`define inst_JAL    64'h0000_0002_0000_0000
`define inst_JALR   64'h0000_0004_0000_0000
`define inst_LUI    64'h0000_0008_0000_0000

`define inst_AUIPC  64'h0000_0010_0000_0000
`define inst_ECALL  64'h0000_0020_0000_0000
`define inst_EBREAK 64'h0000_0040_0000_0000
`define inst_FENCE  64'h0000_0080_0000_0000

`define inst_FENCEI 64'h0000_0100_0000_0000
`define inst_CSRRW  64'h0000_0200_0000_0000
`define inst_CSRRS  64'h0000_0400_0000_0000
`define inst_CSRRC  64'h0000_0800_0000_0000
`define inst_CSRRWI 64'h0000_1000_0000_0000
`define inst_CSRRSI 64'h0000_2000_0000_0000
`define inst_CSRRCI 64'h0000_4000_0000_0000

`endif

module core_coverage (
    input logic        clk,
    input logic        reset,
    input logic        valid,

    // decoder signals
    input logic [6:0]  opcode,
    input logic [6:0]  inst_typ,
    input logic [2:0]  fun3,

    // ALU / execute signals
    input logic [63:0] single_instruction,
    input logic [31:0] alu_result_1,
    input logic [31:0] alu_result_2,
    input logic        branch_taken,
    input logic        jump_taken,
    input logic        reg_write
);

    covergroup decoder_cg @(posedge clk iff (valid && !reset));

        cp_opcode : coverpoint opcode {
            bins r_type    = {`R_Type};
            bins i_type_a  = {`I_Type_A};
            bins b_type    = {`B_Type};
            bins u_lui     = {`U_Type_lui};
            bins u_auipc   = {`U_Type_auipc};
            bins j_type    = {`J_Type_lk};
            bins fence     = {`F_TYPE_FENCE};

            bins load      = {7'b0000011};
            bins store     = {7'b0100011};
            bins jalr      = {7'b1100111};
            bins system    = {7'b1110011};
        }

        cp_inst_typ : coverpoint inst_typ {
            bins r_type   = {`INST_typ_R};
            bins i_type   = {`INST_typ_I};
            bins i_sys    = {`INST_typ_I_ECALL};
            bins s_type   = {`INST_typ_S};
            bins b_type   = {`INST_typ_B};
            bins u_type   = {`INST_typ_U};
            bins j_type   = {`INST_typ_J};
            bins f_type   = {`INST_typ_F};
            bins unknown  = {`UNRECGONIZED};
        }

        cp_branch_fun3 : coverpoint fun3 iff (opcode == `B_Type) {
            bins beq  = {3'b000};
            bins bne  = {3'b001};
            bins blt  = {3'b100};
            bins bge  = {3'b101};
            bins bltu = {3'b110};
            bins bgeu = {3'b111};
        }

        x_opcode_insttyp : cross cp_opcode, cp_inst_typ;

    endgroup


    covergroup alu_cg @(posedge clk iff (valid && !reset));

        cp_alu_instruction : coverpoint single_instruction {
            bins add_sub[] = {
                `inst_ADD,
                `inst_SUB,
                `inst_ADDI
            };

            bins logic_ops[] = {
                `inst_XOR,
                `inst_OR,
                `inst_AND,
                `inst_XORI,
                `inst_ORI,
                `inst_ANDI
            };

            bins shift_ops[] = {
                `inst_SLL,
                `inst_SRL,
                `inst_SRA,
                `inst_SLLI,
                `inst_SRLI,
                `inst_SRAI
            };

            bins compare_ops[] = {
                `inst_SLT,
                `inst_SLTU,
                `inst_SLTI,
                `inst_SLTIU
            };

            bins mem_addr_ops[] = {
                `inst_LB,
                `inst_LH,
                `inst_LW,
                `inst_LBU,
                `inst_LHU,
                `inst_SB,
                `inst_SH,
                `inst_SW
            };

            bins branch_ops[] = {
                `inst_BEQ,
                `inst_BNE,
                `inst_BLT,
                `inst_BGE,
                `inst_BLTU,
                `inst_BGEU
            };

            bins jump_ops[] = {
                `inst_JAL,
                `inst_JALR
            };

            bins upper_ops[] = {
                `inst_LUI,
                `inst_AUIPC
            };
        }

        cp_alu_result_1 : coverpoint alu_result_1 {
            bins zero     = {32'h0000_0000};
            bins one      = {32'h0000_0001};
            bins positive = {[32'h0000_0002:32'h7fff_ffff]};
            bins negative = {[32'h8000_0000:32'hffff_ffff]};
        }

        cp_alu_result_2 : coverpoint alu_result_2 {
            bins zero     = {32'h0000_0000};
            bins positive = {[32'h0000_0001:32'h7fff_ffff]};
            bins negative = {[32'h8000_0000:32'hffff_ffff]};
        }

        cp_branch_taken : coverpoint branch_taken {
            bins not_taken = {1'b0};
            bins taken     = {1'b1};
        }

        cp_jump_taken : coverpoint jump_taken {
            bins no_jump = {1'b0};
            bins jump    = {1'b1};
        }

        cp_reg_write : coverpoint reg_write {
            bins no_write = {1'b0};
            bins write    = {1'b1};
        }

        x_alu_instr_result : cross cp_alu_instruction, cp_alu_result_1;
        x_branch_taken     : cross cp_alu_instruction, cp_branch_taken;
        x_reg_write        : cross cp_alu_instruction, cp_reg_write;

    endgroup


    decoder_cg cg     = new();
    alu_cg     alucg = new();

endmodule
