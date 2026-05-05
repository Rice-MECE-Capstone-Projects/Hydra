//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_arbiter.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Grants the bus to HYDRA only when the 
// CPU has not asserted its own HBUSREQ, or after the CPU's 
// current burst completes (CPU cache-fill bursts hold higher
// priority than HYDRA bulk transfers).
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
module hydra_arbiter (
    input   logic                       clk,
    input   logic                       rst_n,

    // HYDRA request to external arbiter
    input   logic                       hydra_HBUSREQ,
    input   logic   [BEATS_WIDTH-1:0]   hydra_currBeat,
    // CPU's bus request (driven by Wally's EBU)
    input   logic                       cpu_HBUSREQ,

    // Internal grant to HYDRA datapath 
    output  logic                       hydra_grant     // '1' grants bus to HYDRA, '0' to CPU
);

    logic next_hydra_grant;     // give one extra cycle to write last beat

    always_ff @(posedge clk) 
    begin
        if (!rst_n) begin
            hydra_grant         <= 0;
            next_hydra_grant    <= 0;
        end else begin
            hydra_grant <= next_hydra_grant;

            if (!hydra_HBUSREQ)
                next_hydra_grant <= 0;
            else if (hydra_currBeat == NUM_BEATS-1)
                next_hydra_grant <= !cpu_HBUSREQ;
            else
                next_hydra_grant <= !cpu_HBUSREQ ? 1 : next_hydra_grant;
        end
    end

endmodule