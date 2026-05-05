//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_transform.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Implements the AHB master state machine and the 
// dual-MBTB ping-pong buffer for Mode B (matrix transposition) 
// and the combinational quantization pipeline for Mode C.
//
// A component of the HYDRA project.
// https://github.com/Rice-MECE-Capstone-Projects/Hydra
//
// Copyright (C) 2025-26 Rice University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
//////////////////////////////////////////////////////////////////////////////////////////////////

import hydra_pkg::*;
module hydra_transform (
    input  logic                    clk,
    input  logic                    rst_n,

    // MODE C quantization parameters
    input logic [DATA_BITS-1:0]     scale_shift,
    input logic                     signed_out,
    input logic                     round_en,


    // Control from MMR
    input  logic                    start,
    input  hydra_mode               mode,
    input  logic [ADDR_WIDTH-1:0]   src_addr,
    input  logic [ADDR_WIDTH-1:0]   dst_addr,
    input  logic [LEN_WIDTH-1:0]    length,     // number of 32-bit words

    // Arbiter
    input  logic                    HREADY,
    output logic                    HBUSREQ,

    // AHB-Lite master port
    output logic [ADDR_WIDTH-1:0]   HADDR,
    output logic [2:0]              HBURST,
    output logic [2:0]              HSIZE,
    output logic [1:0]              HTRANS,
    output logic [DATA_WIDTH-1:0]   HWDATA,
    output logic                    HWRITE,
    input  logic [DATA_WIDTH-1:0]   HRDATA,
    input  logic                    HRESP,

    // Scratchpad sideband write port
    output logic                    SCRATCH_WE,
    output logic [ADDR_WIDTH-1:0]   SCRATCH_WADDR,
    output logic [DATA_WIDTH-1:0]   SCRATCH_WDATA,

    // Status
    output logic [BEATS_WIDTH-1:0]  currBeat,
    output logic                    done,
    output logic                    error
);

    localparam AHB_SIZE     = $clog2(DATA_WIDTH/8);     // AHB size encoding for 32-bit words
    localparam NUM_ELEMS    = BLOCK_ROWS * BLOCK_COLS;
    localparam ELEM_WIDTH   = $clog2(NUM_ELEMS);
    localparam QUANT_DEPTH  = DATA_WIDTH / QUANT_DIM;
    localparam QUANT_BITS   = $clog2(QUANT_DEPTH);
    localparam QUANT_WIDTH  = NUM_ELEMS / QUANT_DEPTH;
    localparam QUANT_SIZE   = $clog2(QUANT_WIDTH);
    localparam TRANSP_START = (BLOCK_ROWS - 1) * (BLOCK_COLS - 1);      // we can start writing scratchpad before first buffer is full
    localparam ROWS_WIDTH   = $clog2(BLOCK_ROWS);
    localparam COLS_WIDTH   = $clog2(BLOCK_COLS);
    localparam BURST_WIDTH  = LEN_WIDTH - BEATS_WIDTH;

    logic [DATA_WIDTH-1:0]  mbtb_buffer_a [0:BLOCK_ROWS-1][0:BLOCK_COLS-1];     // Buffer A for Mode B
    logic [DATA_WIDTH-1:0]  mbtb_buffer_b [0:BLOCK_ROWS-1][0:BLOCK_COLS-1];     // Buffer B for Mode B
    logic [ELEM_WIDTH-1:0]  pos_mat;
    logic [BEATS_WIDTH-1:0] beat;
    logic [BURST_WIDTH-1:0] burst;
    logic [ROWS_WIDTH-1:0]  row; logic [COLS_WIDTH-1:0] col;
    logic [ROWS_WIDTH-1:0]  SCRATCH_row; logic [COLS_WIDTH-1:0] SCRATCH_col;
    logic [LEN_WIDTH-1:0]   count, SCRATCH_count;
    logic [LEN_WIDTH:0]     offset;
    logic [ADDR_WIDTH-1:0]  next_HADDR;
    logic [QUANT_BITS-1:0]  count_bytes;
    logic [QUANT_SIZE-1:0]  quant_curr;
    logic [DATA_WIDTH-1:0]  quant;
    logic [2:0]             next_HBURST, next_HSIZE;
    logic [1:0]             next_HTRANS;
    logic                   next_HBUSREQ;
    logic                   invalid_length;
    logic                   first_trans, start_fill;
    logic                   fill_sel, drain_sel;
    logic                   next_done_read, done_read, next_done;

    typedef enum logic [1:0] {IDLE, BUSY, FLUSH, ERROR} bus_state_type;
    bus_state_type state, next_state;

    assign currBeat         = beat;
    assign next_done_read   = (count == length-1) && HREADY && (state == BUSY); // done reading when last word of last column is read from AHB
    assign invalid_length   = (length == '0) || ((mode == MODE_B) && (length[ELEM_WIDTH-1:0] != '0)) ||
                              ((mode == MODE_C) && (length[QUANT_BITS-1:0] != '0));
    assign error            = (state == ERROR);
    always_ff @(posedge clk) begin
        if (rst_n && start) begin
            if (invalid_length) begin
                $display("\t[ERROR] Fatal error occurred in hydra_transform:");
                $display("\t\tGot `length`: %0d.", length);
                $display("\t\tExpected: non-zero multiple of %0d.", mode == MODE_B ? NUM_ELEMS : QUANT_DEPTH);
            end
        end
    end

    always_comb
    begin : NEXT_STATE_SIGNALS
        next_state = state;

        if (HRESP || invalid_length) next_state = ERROR;     // if any AHB error response is received, go to error halt
        else begin
            case (state)
                IDLE        : next_state = HREADY           ? (invalid_length ? ERROR : BUSY) : IDLE;
                BUSY        : next_state = (mode == MODE_B) ? (done_read ? FLUSH : BUSY) : ((mode == MODE_C) ? (done_read ? IDLE : BUSY) : IDLE);
                FLUSH       : next_state = done             ? IDLE          : FLUSH;
                ERROR       : next_state = IDLE;
            endcase
        end
    end

    always_comb
    begin : AHB_SIGNALS
        next_HBUSREQ    = (!invalid_length && start) ? 1 : ((done_read || next_state == ERROR) ? 0 : HBUSREQ);
        next_HADDR      = HADDR;
        next_HBURST     = BURST_TYPE;
        next_HSIZE      = AHB_SIZE;
        next_HTRANS     = HTRANS;

        if (state == BUSY) begin
                if (HREADY) begin
                    if (first_trans) begin
                        next_HADDR  = src_addr;
                        next_HTRANS = AHB_NONSEQ;
                    end else if (!done_read) begin
                        next_HADDR  = src_addr + (burst << (COLS_WIDTH+2)) + (beat << 2) + 4;
                        next_HTRANS = (beat == NUM_BEATS-1) ? ((count == length-1) ? AHB_IDLE : AHB_NONSEQ) : AHB_SEQ;
                    end
                end
        end else begin
            next_HADDR  = '0;
            next_HTRANS = AHB_IDLE;
        end
    end

    always_comb
    begin : SCRATCHPAD_SIGNALS
    SCRATCH_WADDR = '0;
    SCRATCH_WE    = 0;
    SCRATCH_WDATA = '0;
    next_done     = 0;

        case (mode)
            MODE_B  : begin
                SCRATCH_WADDR   = dst_addr + (SCRATCH_col << (ROWS_WIDTH + 2)) + (SCRATCH_row << 2) + offset;
                SCRATCH_WE      = ((state == BUSY) && HREADY && (count > TRANSP_START)) || (next_state == FLUSH);
                SCRATCH_WDATA   = drain_sel ? mbtb_buffer_a[SCRATCH_row][SCRATCH_col] : mbtb_buffer_b[SCRATCH_row][SCRATCH_col];
                // if (drain_sel)
                //     $display("scratch[%0d, %0d] <= mbtb_buffer_a[%0d][%0d] = %0h", SCRATCH_WADDR/32, (SCRATCH_WADDR/4)%8, SCRATCH_row, SCRATCH_col, mbtb_buffer_a[SCRATCH_row][SCRATCH_col]);
                // else
                //     $display("scratch[%0d, %0d] <= mbtb_buffer_b[%0d][%0d] = %0h", SCRATCH_WADDR/32, (SCRATCH_WADDR/4)%8, SCRATCH_row, SCRATCH_col, mbtb_buffer_b[SCRATCH_row][SCRATCH_col]);
                next_done       = (SCRATCH_count == length-1) && SCRATCH_WE;
            end
            MODE_C  : begin
                SCRATCH_WADDR   = dst_addr + (quant_curr << 2) + offset;
                SCRATCH_WE      = (state == BUSY) && HREADY && (count_bytes == QUANT_DEPTH-1);
                SCRATCH_WDATA   = {quant_fn(HRDATA, scale_shift, signed_out, round_en), quant[DATA_WIDTH-QUANT_DIM-1:0]}; 
                next_done       = next_done_read;
            end
        endcase
    end

    always_ff @(posedge clk)
    begin
        if (!rst_n) begin
            state           <= IDLE;
            HBUSREQ         <= 0;
            HADDR           <= '0;
            HBURST          <= '0;
            HSIZE           <= '0;
            HTRANS          <= AHB_IDLE;
            HWDATA          <= '0;
            HWRITE          <= 0;
            first_trans     <= 1;
            start_fill      <= 0;
            fill_sel        <= 0;
            drain_sel       <= 0;
            count           <= '0;
            count_bytes     <= '0;
            quant_curr      <= '0;
            quant           <= '0;
            pos_mat         <= '0;
            beat            <= '0;
            burst           <= '0;
            col             <= '0;
            row             <= '0;
            offset          <= '0;
            SCRATCH_count   <= '0;
            SCRATCH_row     <= '0;
            SCRATCH_col     <= '0;
            done_read       <= 0;
            done            <= 0;
        end else begin
            state       <= next_state;
            HBUSREQ     <= next_HBUSREQ;
            HADDR       <= next_HADDR;
            HBURST      <= next_HBURST;
            HSIZE       <= next_HSIZE;
            HTRANS      <= next_HTRANS;
            done_read   <= next_done_read;
            done        <= next_done;

            if (state == IDLE) begin
                done_read       <= 0;
                done            <= 0;
                first_trans     <= 1;
                start_fill      <= 0;
                fill_sel        <= 0;
                drain_sel       <= 0;
                count           <= '0;
                count_bytes     <= '0;
                quant_curr      <= '0;
                quant           <= '0;
                pos_mat         <= '0;
                beat            <= '0;
                burst           <= '0;
                col             <= '0;
                row             <= '0;
                offset          <= '0;
                SCRATCH_count   <= '0;
                SCRATCH_row     <= '0;
                SCRATCH_col     <= '0;
            end else begin
                first_trans <= (HTRANS == AHB_NONSEQ)       ? 0 : first_trans;
                start_fill  <= (HTRANS == AHB_SEQ)          ? 1 : start_fill;

                if ((((mode == MODE_B) || (mode == MODE_C)) && HREADY) || (next_state == FLUSH)) begin
                    if (state == BUSY) begin
                        beat <= (beat == NUM_BEATS-1) ? '0 : (!first_trans ? beat + 1 : beat);
                        if (start_fill || (HTRANS == AHB_SEQ)) begin
                            if (start_fill || (HTRANS == AHB_SEQ)) begin
                                count   <= (count == length-1)      ? count : count + 1;
                                pos_mat <= (pos_mat == NUM_ELEMS-1) ? '0 : pos_mat + 1;
                                burst   <= (count == length-1)      ? '0 : ((beat == NUM_BEATS-1)   ? burst + 1 : burst);
                            end

                            if (mode == MODE_B) begin
                                col                     <= (col == BLOCK_COLS-1)    ? '0 : col + 1;
                                row                     <= (col == BLOCK_COLS-1)    ? ((row == BLOCK_ROWS-1) ? '0 : row + 1) : row;
                                fill_sel                <= (pos_mat == NUM_ELEMS-1) ? !fill_sel : fill_sel;     // toggle buffer after each block
                                mbtb_buffer_a[row][col] <= fill_sel                 ? HRDATA : mbtb_buffer_a[row][col];
                                mbtb_buffer_b[row][col] <= !fill_sel                ? HRDATA : mbtb_buffer_b[row][col];
                            end else if (mode == MODE_C) begin
                                count_bytes                                 <= (count_bytes == QUANT_DEPTH-1) ? '0 : count_bytes + 1;
                                quant_curr                                  <= (count_bytes == QUANT_DEPTH-1) ? ((quant_curr == QUANT_WIDTH-1) ? '0 : quant_curr + 1) : quant_curr;
                                quant[count_bytes*QUANT_DIM +: QUANT_DIM]   <= quant_fn(HRDATA, scale_shift, signed_out, round_en);     // function quant_fn() defined in hydra_pkg.sv
                            end
                        end
                    end if (SCRATCH_WE) begin
                        if (mode == MODE_B) begin
                            drain_sel       <= (SCRATCH_count == length-1)      ? 0 : ((SCRATCH_count[ELEM_WIDTH-1:0] == NUM_ELEMS-1 && SCRATCH_WE) ? !drain_sel : drain_sel);

                            offset          <= (SCRATCH_count[ELEM_WIDTH-1:0] == NUM_ELEMS-1 && SCRATCH_WE) ? offset + NUM_ELEMS*4 : offset;
                            SCRATCH_count   <= (SCRATCH_count == length-1)      ? '0 : SCRATCH_count + 1;
                            SCRATCH_col     <= (SCRATCH_col == BLOCK_COLS-1)    ? '0 : SCRATCH_col + 1;
                            SCRATCH_row     <= (SCRATCH_col == BLOCK_COLS-1)    ? ((SCRATCH_row == BLOCK_ROWS-1) ? '0 : SCRATCH_row + 1) : SCRATCH_row;
                        end else if (mode == MODE_C)
                            offset <= (quant_curr == QUANT_WIDTH-1) ? offset + QUANT_WIDTH*QUANT_DEPTH : offset;
                    end                    
                end
            end
        end
    end

endmodule