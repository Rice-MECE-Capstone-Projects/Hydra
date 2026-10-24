//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_scratchpad.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Single-port scratchpad for HYDRA outputs across all modes.
//   One memory port shared by:
//   - AHB-Lite slave — CPU read-only access.
//   - HYDRA private sideband write port (has priority).
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
//   2. If a CPU read collides with a HYDRA write, the write takes the port
//      and the read is held (HREADYOUT low) until the port is free. The read
//      then returns post-write data; no corruption occurs.
//
// HRDATA/HREADYOUT are combinational and registered once in hydra_top, so
// they describe the next bus cycle (HREADYOUT=0 stalls the coming data phase).

import hydra_pkg::*;
module hydra_scratchpad (
    input logic clk,
    input logic rst_n,

    // AHB-Lite slave port — CPU read
    input  logic [ADDR_WIDTH-1:0] HADDR,
    // input  logic [2:0]             HBURST,   // unused (non-cacheable region)
    // input  logic [2:0]             HSIZE,    // unused (LSU handles sub-word)
    input  logic                  HWRITE,
    input  logic [           1:0] HTRANS,
    input  logic                  HSEL,
    input  logic                  HREADY,
    output logic [DATA_WIDTH-1:0] HRDATA,
    output logic                  HREADYOUT,
    output logic                  HRESP,

    // Sideband write port — HYDRA private write
    input logic                  SCRATCH_WE,
    input logic [ADDR_WIDTH-1:0] SCRATCH_WADDR,
    input logic [DATA_WIDTH-1:0] SCRATCH_WDATA
);

  // MEM_SIZE is the word count for a 32-bit DATA_WIDTH baseline. The
  // MEM_DEPTH localparam rescales this so capacity stays 32 KB for any
  // DATA_WIDTH.
  localparam int unsigned MEM_DEPTH  = 32 * MEM_SIZE / DATA_WIDTH;
  localparam int unsigned ADDR_BITS  = $clog2(MEM_DEPTH);
  localparam int unsigned BYTE_SHIFT = $clog2(DATA_WIDTH / 8);

  logic [DATA_WIDTH-1:0] mem         [MEM_DEPTH];
  logic                  read_access;
  logic                  read_pending;
  logic                  read_stall;
  logic [ ADDR_BITS-1:0] pending_addr;
  logic [ ADDR_BITS-1:0] read_addr;
  logic [ ADDR_BITS-1:0] port_addr;

  assign read_access  = HTRANS[1] && HSEL && !HWRITE && HREADY;

  // Single port: HYDRA writes win; otherwise serve a held read, then a new read
  assign read_addr    = read_pending ? pending_addr : HADDR[ADDR_BITS+BYTE_SHIFT-1:BYTE_SHIFT];
  assign port_addr    = SCRATCH_WE ? SCRATCH_WADDR[ADDR_BITS+BYTE_SHIFT-1:BYTE_SHIFT] : read_addr;
  assign read_stall   = SCRATCH_WE && (read_access || read_pending);

  // Never signals errors
  assign HREADYOUT    = !read_stall;
  assign HRESP        = 0;
  assign HRDATA       = (!SCRATCH_WE && (read_access || read_pending)) ? mem[port_addr] : '0;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      read_pending <= 0;
      pending_addr <= '0;
    end else begin
      // Hold a read that lost the port until it is served
      read_pending <= read_stall;
      if (read_access && SCRATCH_WE) pending_addr <= HADDR[ADDR_BITS+BYTE_SHIFT-1:BYTE_SHIFT];

      // Sideband write
      if (SCRATCH_WE) begin
        mem[port_addr] <= SCRATCH_WDATA;
      end
    end
  end

endmodule
