//////////////////////////////////////////////////////////////////////////////////////////////////
// sram.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: SRAM wrapper for different data configurations.
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
module sram (
    input logic                  clk,
    input logic [ADDR_WIDTH-1:0] ADDRESS,  // address (byte-addressed)
    input logic [DATA_WIDTH-1:0] wd,       // data to write
    input logic                  banksel,  // access enable
    input logic                  read,     // read enable
    input logic                  write,    // write enable

    output logic [DATA_WIDTH-1:0] dataout  // registered data output (only updated on read)
);

  generate
    if (SRAM_SUPPORTED) begin : gen_SRAM
      localparam int unsigned BANKS_NUM = MEM_DEPTH / 1024;
      localparam int unsigned ACTUAL_BANKS_NUM = (MEM_DEPTH + 1023) / 1024;  // integer ceiling division
      localparam int unsigned MEM_WIDTH = (ACTUAL_BANKS_NUM > 1) ? $clog2(ACTUAL_BANKS_NUM) : 1;
      if (ACTUAL_BANKS_NUM != BANKS_NUM)
        $warning(
            "Using SRAM capacity of %0d KiB, instead of specified config (%0d bytes).",
            ACTUAL_BANKS_NUM * REG_STRIDE,
            SCRATCH_BYTES
        );

      logic [ADDR_WIDTH-1:0] waddr;
      logic [9:0] addr;
      logic [DATA_WIDTH-1:0] bank_data[ACTUAL_BANKS_NUM];
      logic [ACTUAL_BANKS_NUM-1:0] bank_enable;
      logic [MEM_WIDTH-1:0] sel;

      // convert scratchpad byte-addressed format to word-indexed for ASAP7
      assign waddr = ADDRESS >> BYTE_SHIFT;
      assign addr = waddr[9:0];
      assign dataout = bank_data[sel];
      always_ff @(posedge clk) if (read && |bank_enable) sel <= waddr[10+:MEM_WIDTH];

      for (genvar i = 0; i < ACTUAL_BANKS_NUM; i++) begin : g_array
        assign bank_enable[i] = banksel && (waddr[10+:MEM_WIDTH] == i);

        if (DATA_WIDTH == 16) begin : g_bank
          srambank_256x4x16_6t122 sram (
              .clk,
              .ADDRESS(addr),
              .wd,
              .banksel(bank_enable[i]),
              .read,
              .write,
              .dataout(bank_data[i])
          );
        end else if (DATA_WIDTH == 32) begin : g_bank
          srambank_256x4x32_6t122 sram (
              .clk,
              .ADDRESS(addr),
              .wd,
              .banksel(bank_enable[i]),
              .read,
              .write,
              .dataout(bank_data[i])
          );
        end else if (DATA_WIDTH == 64) begin : g_bank
          srambank_256x4x64_6t122 sram (
              .clk,
              .ADDRESS(addr),
              .wd,
              .banksel(bank_enable[i]),
              .read,
              .write,
              .dataout(bank_data[i])
          );
        end else
          $fatal(1, "SRAM implementation currently only supports DATA_WIDTH = {16, 32, 64}!");
      end
    end else begin : gen_FF
      logic [DATA_WIDTH-1:0] mem[MEM_DEPTH];
      always_ff @(posedge clk) begin
        if (banksel)
          if (write) mem[BYTE_SHIFT+:ADDR_BITS] <= wd;
          else if (read) dataout <= mem[BYTE_SHIFT+:ADDR_BITS];
      end
    end
  endgenerate

endmodule
