//////////////////////////////////////////////////////////////////////////////////////////////////
// sram_auto_wrapper.sv
//
// Author: Matthew Nutt <mcn5@rice.edu>
//
// Description: Implements a wrapper that instantiates multiple ASAP7 SRAM macros
// and provides transparent access, as though the wrapper is a monolithic macro.
// Instantiate with sram_auto_wrapper #( .TOTAL_DEPTH(...), .TOTAL_WIDTH(...) ) (...);
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

// ============================================================================
// Module: sram_macro_dispatch
// Description: Internal helper module that maps chosen MACRO_DEPTH and 
//              MACRO_WIDTH parameters directly to the hard macro instance.
// ============================================================================
module sram_macro_dispatch #(
  parameter int MACRO_DEPTH = 1024,
  parameter int MACRO_WIDTH = 32
)(
  input  logic                            clk,
  input  logic [$clog2(MACRO_DEPTH)-1:0]  ADDRESS,
  input  logic [MACRO_WIDTH-1:0]          wd,
  input  logic                            banksel,
  input  logic                            read,
  input  logic                            write,
  output logic [MACRO_WIDTH-1:0]          dataout
);

  generate
    case ({MACRO_DEPTH, MACRO_WIDTH})
      // ----------------------------------------------------------------------
      // 256-Word Macros (64x4)
      // ----------------------------------------------------------------------
      {32'd256, 32'd16}: srambank_64x4x16_6t122 dispatch_inst_64x4x16 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd18}: srambank_64x4x18_6t122 dispatch_inst_64x4x18 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd20}: srambank_64x4x20_6t122 dispatch_inst_64x4x20 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd32}: srambank_64x4x32_6t122 dispatch_inst_64x4x32 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd34}: srambank_64x4x34_6t122 dispatch_inst_64x4x34 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd36}: srambank_64x4x36_6t122 dispatch_inst_64x4x36 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd40}: srambank_64x4x40_6t122 dispatch_inst_64x4x40 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd48}: srambank_64x4x48_6t122 dispatch_inst_64x4x48 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd64}: srambank_64x4x64_6t122 dispatch_inst_64x4x64 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd72}: srambank_64x4x72_6t122 dispatch_inst_64x4x72 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd74}: srambank_64x4x74_6t122 dispatch_inst_64x4x74 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd256, 32'd80}: srambank_64x4x80_6t122 dispatch_inst_64x4x80 (.clk(clk), .ADDRESS(ADDRESS[7:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));

      // ----------------------------------------------------------------------
      // 512-Word Macros (128x4)
      // ----------------------------------------------------------------------
      {32'd512, 32'd16}: srambank_128x4x16_6t122 dispatch_inst_128x4x16 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd18}: srambank_128x4x18_6t122 dispatch_inst_128x4x18 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd20}: srambank_128x4x20_6t122 dispatch_inst_128x4x20 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd32}: srambank_128x4x32_6t122 dispatch_inst_128x4x32 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd34}: srambank_128x4x34_6t122 dispatch_inst_128x4x34 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd36}: srambank_128x4x36_6t122 dispatch_inst_128x4x36 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd40}: srambank_128x4x40_6t122 dispatch_inst_128x4x40 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd48}: srambank_128x4x48_6t122 dispatch_inst_128x4x48 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd64}: srambank_128x4x64_6t122 dispatch_inst_128x4x64 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd72}: srambank_128x4x72_6t122 dispatch_inst_128x4x72 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd74}: srambank_128x4x74_6t122 dispatch_inst_128x4x74 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd512, 32'd80}: srambank_128x4x80_6t122 dispatch_inst_128x4x80 (.clk(clk), .ADDRESS(ADDRESS[8:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));

      // ----------------------------------------------------------------------
      // 1024-Word Macros (256x4)
      // ----------------------------------------------------------------------
      {32'd1024, 32'd16}: srambank_256x4x16_6t122 dispatch_inst_256x4x16 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd18}: srambank_256x4x18_6t122 dispatch_inst_256x4x18 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd20}: srambank_256x4x20_6t122 dispatch_inst_256x4x20 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd32}: srambank_256x4x32_6t122 dispatch_inst_256x4x32 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd34}: srambank_256x4x34_6t122 dispatch_inst_256x4x34 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd36}: srambank_256x4x36_6t122 dispatch_inst_256x4x36 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd40}: srambank_256x4x40_6t122 dispatch_inst_256x4x40 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd48}: srambank_256x4x48_6t122 dispatch_inst_256x4x48 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd64}: srambank_256x4x64_6t122 dispatch_inst_256x4x64 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd72}: srambank_256x4x72_6t122 dispatch_inst_256x4x72 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd74}: srambank_256x4x74_6t122 dispatch_inst_256x4x74 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      {32'd1024, 32'd80}: srambank_256x4x80_6t122 dispatch_inst_256x4x80 (.clk(clk), .ADDRESS(ADDRESS[9:0]), .wd(wd), .banksel(banksel), .read(read), .write(write), .dataout(dataout));
      
      default: initial $error("Unsupported macro depth/width configuration.");
    endcase
  endgenerate

endmodule


// ============================================================================
// Top Module: sram_auto_wrapper
// Description: Fully parameterized wrapper supporting arbitrary depth/width.
//              Automatically selects optimal macro dimensions and instantiates
//              a 2D grid of hard macros.
// ============================================================================
module sram_auto_wrapper #(
  parameter int TOTAL_DEPTH = 8192,
  parameter int TOTAL_WIDTH = 32
)(
  input  logic                            clk,
  input  logic [$clog2(TOTAL_DEPTH)-1:0]  address,
  input  logic [TOTAL_WIDTH-1:0]          write_data,
  input  logic                            bank_en,
  input  logic                            read_en,
  input  logic                            write_en,
  output logic [TOTAL_WIDTH-1:0]          dataout
);

  // --------------------------------------------------------------------------
  // Constant Functions for Compile-time Optimization
  // --------------------------------------------------------------------------
  function automatic int select_macro_depth(int req_depth);
    if (req_depth >= 1024) return 1024;
    else if (req_depth >= 512) return 512;
    else return 256;
  endfunction

  function automatic int select_macro_width(int req_w);
    int candidate_widths[12] = '{16, 18, 20, 32, 34, 36, 40, 48, 64, 72, 74, 80};
    int best_w = 16;
    int min_allocated = 999999;
    int min_cols = 999999;

    for (int i = 0; i < 12; i++) begin
      int w = candidate_widths[i];
      int cols = (req_w + w - 1) / w; // Ceiling division
      int total_allocated = cols * w;

      // 1. Primary goal: Minimize total allocated width (minimizes bitcell waste)
      // 2. Secondary goal: Minimize column count (fewer hard macro instances)
      if (total_allocated < min_allocated || 
         (total_allocated == min_allocated && cols < min_cols)) begin
        min_allocated = total_allocated;
        min_cols      = cols;
        best_w        = w;
      end
    end
    return best_w;
  endfunction

  // --------------------------------------------------------------------------
  // Grid and Address Parameter Math
  // --------------------------------------------------------------------------
  localparam int MACRO_DEPTH     = select_macro_depth(TOTAL_DEPTH);
  localparam int MACRO_WIDTH     = select_macro_width(TOTAL_WIDTH);

  localparam int NUM_DEPTH_BANKS = (TOTAL_DEPTH + MACRO_DEPTH - 1) / MACRO_DEPTH;
  localparam int NUM_WIDTH_BANKS = (TOTAL_WIDTH + MACRO_WIDTH - 1) / MACRO_WIDTH;

  localparam int MACRO_ADDR_W   = $clog2(MACRO_DEPTH);
  localparam int BANK_ADDR_W    = (NUM_DEPTH_BANKS > 1) ? $clog2(NUM_DEPTH_BANKS) : 1;

  // Internal Signals
  logic [NUM_DEPTH_BANKS-1:0] bank_sel;
  logic [BANK_ADDR_W-1:0]     bank_addr;
  logic [BANK_ADDR_W-1:0]     bank_addr_q;
  logic [MACRO_ADDR_W-1:0]    local_addr;

  logic [MACRO_WIDTH-1:0] macro_wd   [0:NUM_DEPTH_BANKS-1][0:NUM_WIDTH_BANKS-1];
  logic [MACRO_WIDTH-1:0] macro_dout [0:NUM_DEPTH_BANKS-1][0:NUM_WIDTH_BANKS-1];

  // Address Partitioning
  assign local_addr = address[MACRO_ADDR_W-1:0];

  generate
    if (NUM_DEPTH_BANKS > 1) begin : gen_bank_split
      assign bank_addr = address[MACRO_ADDR_W + $clog2(NUM_DEPTH_BANKS) - 1 : MACRO_ADDR_W];
    end else begin : gen_single_bank
      assign bank_addr = 1'b0;
    end
  endgenerate

  // Bank Decoder
  always_comb begin
    for (int d = 0; d < NUM_DEPTH_BANKS; d++) begin
      if (NUM_DEPTH_BANKS > 1)
        bank_sel[d] = bank_en && (bank_addr == d[BANK_ADDR_W-1:0]);
      else
        bank_sel[d] = bank_en;
    end
  end

  // Read Latency Pipeline Stage
  always_ff @(posedge clk) begin
    if (bank_en && read_en) begin
      bank_addr_q <= bank_addr;
    end
  end

  // --------------------------------------------------------------------------
  // 2D Macro Grid Instantiation & Data Mapping
  // --------------------------------------------------------------------------
  genvar d, w;
  generate
    for (d = 0; d < NUM_DEPTH_BANKS; d++) begin : gen_depth
      for (w = 0; w < NUM_WIDTH_BANKS; w++) begin : gen_width

        // Write Data Mapping (Bit Slicing)
        always_comb begin
          macro_wd[d][w] = '0;
          for (int b = 0; b < MACRO_WIDTH; b++) begin
            if ((w * MACRO_WIDTH + b) < TOTAL_WIDTH) begin
              macro_wd[d][w][b] = write_data[w * MACRO_WIDTH + b];
            end
          end
        end

        // Dispatch Hard Macro Instance
        sram_macro_dispatch #(
          .MACRO_DEPTH(MACRO_DEPTH),
          .MACRO_WIDTH(MACRO_WIDTH)
        ) u_macro (
          .clk     (clk),
          .ADDRESS (local_addr),
          .wd      (macro_wd[d][w]),
          .banksel (bank_sel[d]),
          .read    (read_en),
          .write   (write_en),
          .dataout (macro_dout[d][w])
        );

      end
    end
  endgenerate

  // Read Output Multiplexing (combines dynamic bank select + column concat)
  always_comb begin
    dataout = '0;
    for (int col = 0; col < NUM_WIDTH_BANKS; col++) begin
      for (int b = 0; b < MACRO_WIDTH; b++) begin
        if ((col * MACRO_WIDTH + b) < TOTAL_WIDTH) begin
          dataout[col * MACRO_WIDTH + b] = macro_dout[bank_addr_q][col][b];
        end
      end
    end
  end

endmodule
