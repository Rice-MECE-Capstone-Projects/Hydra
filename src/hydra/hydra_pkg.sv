// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// hydra_pkg.sv
// Rice University — Project HYDRA
// Author: Giovanni Sirtori <gs86@rice.edu>
// Description: HYDRA's package.

`timescale 1ns/1ps
package hydra_pkg;
// -------------------------AHB Typedefs-------------------------
    typedef enum logic [2:0] {
        SINGLE = 3'b000, 
        INCR   = 3'b001, 
        WRAP4  = 3'b010, 
        INCR4  = 3'b011, 
        WRAP8  = 3'b100, 
        INCR8  = 3'b101, 
        WRAP16 = 3'b110, 
        INCR16 = 3'b111
    } ahb_burst_type;
    
    typedef enum logic [1:0] {
        AHB_IDLE   = 2'b00, 
        AHB_BUSY   = 2'b01, 
        AHB_NONSEQ = 2'b10, 
        AHB_SEQ    = 2'b11
    } ahb_trans_type;

    typedef enum logic [2:0] {
        BYTE    = 3'b000,
        HALF    = 3'b001,
        WORD    = 3'b010,
        DOUBLE  = 3'b011,
        QUAD    = 3'b100,
        OCTA    = 3'b101,
        HEXA    = 3'b110,
        KILO    = 3'b111
    } ahb_size_type;

  // -------------------------Parameters-------------------------
    parameter int unsigned      ADDR_WIDTH      = 32;
    parameter int unsigned      DATA_WIDTH      = 32;

    // Mode B block dimensions for 32-bit elements: 8 rows x 16 columns
    parameter int unsigned      BLOCK_ROWS      = 8;
    parameter int unsigned      BLOCK_COLS      = 16;

    parameter ahb_burst_type    BURST_TYPE      = INCR16;
    parameter int unsigned      QUANT_DIM       = 8;
    
    // Scratchpad has 4 MB at 32-bit words
    parameter int unsigned      MEM_SIZE        = 1048576;

    localparam int unsigned     REG_STRIDE      = DATA_WIDTH / 8;
    localparam int unsigned     DATA_BITS       = $clog2(DATA_WIDTH);
    localparam int unsigned     LEN_WIDTH       = $clog2(MEM_SIZE);
    localparam int unsigned     S_QUANT_BOUND   = 1 << (QUANT_DIM-1);
    localparam int unsigned     U_QUANT_BOUND   = 1 << (QUANT_DIM);
    localparam int unsigned     NUM_BEATS       = getLen_fn(BURST_TYPE);
    localparam int unsigned     BEATS_WIDTH     = $clog2(NUM_BEATS);

  // -------------------------HYDRA Typedefs-------------------------
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        MODE_A = 2'b01,     // scatter-gather
        MODE_B = 2'b10,     // matrix transposition
        MODE_C = 2'b11      // quantization
    } hydra_mode;

    typedef enum logic [7:0] { 
        CTRL    = 8'(0 * REG_STRIDE),
        SRC     = 8'(1 * REG_STRIDE),
        DST     = 8'(2 * REG_STRIDE),
        LEN     = 8'(3 * REG_STRIDE),
        STATUS  = 8'(4 * REG_STRIDE)
    } hydra_mmr_map;

  // -------------------------Constants Declarations-------------------------
    // Corner cases for MODE C
    const logic signed [DATA_WIDTH-1:0] corner_vals[] = '{
      {{(DATA_WIDTH-1){1'b0}}, 1'b1},       // +1 (no clip)
      {1'b0, {(DATA_WIDTH-1){1'b1}}},       // maximum positive (clip)
      {DATA_WIDTH{1'b1}},                   // -1 (no clip)
      {1'b1, {(DATA_WIDTH-1){1'b0}}}        // minimum negative (clip)
    };

  // -------------------------Functions Declarations-------------------------
    function automatic int getLen_fn(ahb_burst_type b);
        case (b)
            SINGLE  :   return 1;
            INCR4   :   return 4;
            INCR8   :   return 8;
            INCR16  :   return 16;
            default :   return 1;
        endcase
    endfunction

    // Quantize a [DATA_WIDTH-1:0] signal to QUANT_DIM bits using 
    // power-of-two shift.
    //      scale_shift : arithmetic right-shift amount [0:DATA_WIDTH-1]
    //      signed_out  : 1 = INT_QUANT_DIM [-S_QUANT_BOUND,S_QUANT_BOUND-1], 0 = UINT_QUANT_DIM [0,U_QUANT_BOUND-1]
    //      round_en    : 1 = add rounding correction before shift
    function automatic logic [QUANT_DIM-1:0] quant_fn (
        logic [DATA_WIDTH-1:0]  src, 
        logic [DATA_BITS-1:0]   scale_shift, 
        logic                   signed_out, 
        logic                   round_en
    );
        logic signed [DATA_WIDTH:0] val;        // one extra bit to absorb rounding carry safely
        logic signed [DATA_WIDTH:0] rounded;
        logic signed [DATA_WIDTH:0] scaled;
        logic signed [DATA_WIDTH:0] lo, hi;

        val     = {src[DATA_WIDTH-1], src};     // sign-extend
        // if rounded is enabled, add half of target scale to improve accuracy
        rounded = round_en && (scale_shift > 0)
                    ? val + ({{DATA_WIDTH{1'b0}}, 1'b1} << (scale_shift - 1))
                    : val;
        scaled = $signed(rounded) >>> scale_shift;

        lo      = signed_out ? -S_QUANT_BOUND : 0;
        hi      = signed_out ?  S_QUANT_BOUND-1 : U_QUANT_BOUND-1;

        if      ($signed(scaled) < $signed(lo)) return lo[QUANT_DIM-1:0];
        else if ($signed(scaled) > $signed(hi)) return hi[QUANT_DIM-1:0];
        else                                    return scaled[QUANT_DIM-1:0];
    endfunction

endpackage