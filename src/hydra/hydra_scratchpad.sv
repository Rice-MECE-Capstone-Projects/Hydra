// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// hydra_scratchpad.sv
// Rice University — Project HYDRA
// Author: Giovanni Sirtori <gs86@rice.edu>
// Description: Dual-port scratchpad for HYDRA outputs across all modes.
//   Port A: AHB-Lite slave — CPU read-only access.
//   Port B: HYDRA private sideband write port.
//
// Ordering contract (enforced by software, not hardware):
//   CPU must only read scratchpad after HYDRA asserts STATUS.DONE.
//   Concurrent read/write collisions are not guarded in hardware — if
//   software violates the contract, the read returns pre-write data
//   (standard flop read-before-write semantics) but no corruption occurs.
//
// CPU writes to this region are silently ignored. Scratchpad is strictly
// read-only from the AHB side.

import hydra_pkg::*;
module hydra_scratchpad (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   HSELScratch,

    // AHB-Lite slave port — CPU read
    input  logic [ADDR_WIDTH-1:0]  HADDR,
    input  logic [2:0]             HBURST,   // accepted, but unused (non-cacheable region)
    input  logic [2:0]             HSIZE,    // accepted, but unused (LSU handles sub-word)
    input  logic [1:0]             HTRANS,
    input  logic                   HWRITE,
    input  logic                   HREADY,
    output logic [DATA_WIDTH-1:0]  HRDATA,
    output logic                   HRESP,
    output logic                   HREADYOUT,

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

    assign read_access      = HTRANS[1] && HSELScratch && !HWRITE && HREADY;

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