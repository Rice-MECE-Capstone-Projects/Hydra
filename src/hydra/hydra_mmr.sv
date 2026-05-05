//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_mmr.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Implements an AHB-Lite slave interface through 
// which the host CPU programs transfer descriptors and reads status.
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

// Register map:
    // Offset CTRL      : [0]=START, [2:1]=MODE[1:0], [7:3]=SCALE_SHIFT[4:0], [8]=SIGNED_OUT, [9]=ROUND_EN
    // Offset SRC       : [ADDR_WIDTH-1:0]
    // Offset DST       : [ADDR_WIDTH-1:0]
    // Offset LEN       : [LEN_WIDTH-1:0]
    // Offset STATUS    : [0]=ERROR

import hydra_pkg::*;
module hydra_mmr (
    input  logic                    clk,
    input  logic                    rst_n,

    // Status input from hydra_transform
    input  logic                    done,
    input  logic                    error,

    // AHB-Lite slave port
    input  logic [ADDR_WIDTH-1:0]   HADDR,
    input  logic [DATA_WIDTH-1:0]   HWDATA,
    input  logic                    HWRITE,
    input  logic [1:0]              HTRANS,
    input  logic                    HSEL,
    input  logic                    HREADY,
    output logic [DATA_WIDTH-1:0]   HRDATA,
    output logic                    HREADYOUT,
    output logic                    HRESP,

    // Decoded control outputs to hydra_transform
    output logic                    start,
    output hydra_mode               mode,
    output logic [DATA_BITS-1:0]    scale_shift,
    output logic                    signed_out,
    output logic                    round_en,
    output logic [ADDR_WIDTH-1:0]   src_addr,
    output logic [ADDR_WIDTH-1:0]   dst_addr,
    output logic [LEN_WIDTH-1:0]    length
);
    localparam int unsigned MODE_BITS       = $bits(hydra_mode);
    localparam int unsigned MMR_OFFSET_BITS = $bits(hydra_mmr_map);

    logic error_reg;
    logic phase_valid_r, phase_valid_w;
    hydra_mmr_map mmr_offset_r, mmr_offset_w;

    assign phase_valid_r    = HTRANS[1] && HSEL && !HWRITE;
    assign mmr_offset_r     = hydra_mmr_map'(HADDR[MMR_OFFSET_BITS-1:0]);

    // MMR has no wait states and never signals errors
    assign HREADYOUT    = 1;
    assign HRESP        = 0;

    always_ff @(posedge clk)
    begin
        if (!rst_n) begin
            HRDATA          <= '0;
            phase_valid_w   <= 0;
            mmr_offset_w    <= hydra_mmr_map'('0);
            start           <= 0;
            mode            <= IDLE;
            scale_shift     <= '0;
            signed_out      <= 0;
            round_en        <= 0;
            src_addr        <= '0;
            dst_addr        <= '0;
            length          <= '0;
            error_reg       <= 0;
        end else begin
            // `top` sends interrupt on (done || error), so CPU needs to read
            // STATUS to understand whether HYDRA was successfull or not
            error_reg   <= error ? 1 : error_reg;
            start       <= 0;       // single-cycle pulse

            phase_valid_w <= HTRANS[1]  && HSEL && HWRITE && HREADY;        // only write during Data Phase
            mmr_offset_w  <= (HTRANS[1] && HSEL && HREADY) ? mmr_offset_r : mmr_offset_w;
            if (phase_valid_r && HREADY) begin
                case (mmr_offset_r)
                    CTRL    : HRDATA <= {(DATA_WIDTH - MODE_BITS - DATA_BITS - 3)'(0), round_en, signed_out, scale_shift, mode, start};
                    SRC     : HRDATA <= src_addr;
                    DST     : HRDATA <= dst_addr;
                    LEN     : HRDATA <= length;
                    STATUS  : HRDATA <= {(DATA_WIDTH - 1)'(0), error_reg};

                    default : HRDATA <= '0;
                endcase  
            end else if (phase_valid_w && HREADY) begin
                case (mmr_offset_w)
                    CTRL    : begin
                        start           <= HWDATA[0];
                        mode            <= hydra_mode'(HWDATA[MODE_BITS:1]);
                        scale_shift     <= HWDATA[DATA_BITS+MODE_BITS:MODE_BITS+1];
                        signed_out      <= HWDATA[DATA_BITS+MODE_BITS+1];
                        round_en        <= HWDATA[DATA_BITS+MODE_BITS+2];
                    end
                    SRC     : src_addr  <= HWDATA[ADDR_WIDTH-1:0];
                    DST     : dst_addr  <= HWDATA[ADDR_WIDTH-1:0];
                    LEN     : length    <= HWDATA[LEN_WIDTH-1:0];
                    STATUS  : error_reg <= 0;
                endcase
            end
            end
        end

endmodule