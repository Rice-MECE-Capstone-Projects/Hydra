// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// hydra_arbiter.sv
// Rice University — Project HYDRA
// Author: <name> <netID>@rice.edu
// Description: CPU cache-fill bursts hold higher priority than 
// HYDRA bulk transfers. Grants the bus to HYDRA only when the 
// CPU has not asserted its own HBUSREQ, or after the CPU's 
// current burst completes.

// Grant is registered to prevent combinational loops on HGRANT->HADDR.

`timescale 1ns/1ps

module hydra_arbiter (
    input  logic clk,
    input  logic rst_n,

    // HYDRA request to external arbiter (drives top-level HBUSREQ)
    input  logic HBUSREQ,
    // Grant returned from bus fabric to HYDRA
    input  logic HGRANT,

    // CPU's bus request (driven by Wally's EBU)
    // High priority: when asserted, HYDRA must yield the bus
    input  logic cpu_HBUSREQ,

    // Internal grant to HYDRA datapath — only valid when HGRANT is
    // asserted AND cpu_HBUSREQ is deasserted or the CPU burst is done
    output logic grant_out
);

endmodule