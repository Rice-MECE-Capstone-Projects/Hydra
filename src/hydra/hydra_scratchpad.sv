//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_scratchpad.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Dual-port scratchpad for HYDRA outputs across all modes.
//   Port A: AHB-Lite slave — CPU read-only access.
//   Port B: HYDRA private sideband write port.
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

// Ordering contract (enforced by software, not hardware):
    //   1. CPU must only read scratchpad after HYDRA asserts STATUS.DONE.
    //   2. Concurrent read/write collisions are not guarded in hardware — if
    //      software violates the contract, the read returns pre-write data
    //      (standard flop read-before-write semantics) but no corruption occurs.

import hydra_pkg::*;
module hydra_scratchpad (
    input  logic                   clk,
    input  logic                   rst_n,

    // AHB-Lite slave port — CPU read
    input  logic [ADDR_WIDTH-1:0]  HADDR,
    // input  logic [2:0]             HBURST,   // unused (non-cacheable region)
    // input  logic [2:0]             HSIZE,    // unused (LSU handles sub-word)
    input  logic                   HWRITE,
    input  logic [1:0]             HTRANS,
    input  logic                   HSEL,
    input  logic                   HREADY,
    output logic [DATA_WIDTH-1:0]  HRDATA,
    output logic                   HREADYOUT,
    output logic                   HRESP,

    // Sideband write port — HYDRA private write
    input  logic                   SCRATCH_WE,
    input  logic [ADDR_WIDTH-1:0]  SCRATCH_WADDR,
    input  logic [DATA_WIDTH-1:0]  SCRATCH_WDATA
);

    // MEM_SIZE is the word count for a 32-bit DATA_WIDTH baseline. The
    // MEM_DEPTH localparam rescales this so the memory is always 4 MB
    // regardless of DATA_WIDTH.
    localparam int unsigned MEM_DEPTH  = 32 * MEM_SIZE / DATA_WIDTH;
    localparam int unsigned ADDR_BITS  = $clog2(MEM_DEPTH);
    localparam int unsigned BYTE_SHIFT = $clog2(DATA_WIDTH/8);

    logic [DATA_WIDTH-1:0]  mem [0:MEM_DEPTH-1];
    logic                   read_access;

    assign read_access      = HTRANS[1] && HSEL && !HWRITE && HREADY;

    // Scratchpad has no wait states and never signals errors
    // (matches cvw/src/uncore/ram_ahb.sv convention)
    assign HREADYOUT        = 1;
    assign HRESP            = 0;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            HRDATA <= '0;
        end else begin
            // AHB read
            if (read_access) begin
                HRDATA <= mem[HADDR[ADDR_BITS+BYTE_SHIFT-1:BYTE_SHIFT]];
            end

            // Sideband write
            if (SCRATCH_WE) begin
                mem[SCRATCH_WADDR[ADDR_BITS+BYTE_SHIFT-1:BYTE_SHIFT]] <= SCRATCH_WDATA;
            end
        end
    end

endmodule