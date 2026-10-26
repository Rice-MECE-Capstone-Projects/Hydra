//////////////////////////////////////////////////////////////////////////////////////////////////
// sram_wrapper_8192x32.sv
//
// Author: Matthew Nutt <mcn5@rice.edu>
//
// Description: Implements a wrapper that instantiates multiple ASAP7 SRAM macros
// and provides transparent access, as though the wrapper is a monolithic macro.
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

module sram_wrapper_8192x32 (
  input  logic        clk,
  input  logic [12:0] address,
  input  logic [31:0] write_data,
  input  logic        bank_en,
  input  logic        read_en,
  input  logic        write_en,
  output logic [31:0] dataout
);

  logic [7:0]  bank_sel;
  logic [31:0] dout [0:7];
  logic [2:0]  bank_addr_q; // Registered bank address for read MUX

  // Decode MSBs of address into individual bank selects
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      bank_sel[i] = bank_en && (address[12:10] == i);
    end
  end

  // Use registered address for multiplexing output, so dataout won't change early
  always_ff @(posedge clk) begin
    if (bank_en && read_en) begin
      bank_addr_q <= address[12:10];
    end
  end
  assign dataout = dout[bank_addr_q];

  // Instantiate eight macros with generate block
  genvar i;
  generate
    for (i = 0; i < 8; i++) begin : gen_sram_banks
      srambank_256x4x32_6t122 sram_inst (
        .clk     (clk),
        .ADDRESS (address[9:0]),
        .wd      (write_data),
        .banksel (bank_sel[i]),
        .read    (read_en),
        .write   (write_en),
        .dataout (dout[i])
      );
    end
  endgenerate

endmodule
