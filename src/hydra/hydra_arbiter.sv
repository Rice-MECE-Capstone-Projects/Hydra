// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// hydra_arbiter.sv
// Rice University — Project HYDRA
// Author: Giovanni Sirtori <gs86@rice.edu>
// Description: Grants the bus to HYDRA only when the 
// CPU has not asserted its own HBUSREQ, or after the CPU's 
// current burst completes (CPU cache-fill bursts hold higher
// priority than HYDRA bulk transfers).

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