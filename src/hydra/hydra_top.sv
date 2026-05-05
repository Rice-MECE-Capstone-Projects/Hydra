//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_top.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Top-level integration module. Instantiates the 
// arbiter, MMR register file, scratchpad memory, and transform 
// datapath. Connects to the Wally AHB-Lite bus fabric as a second 
// master alongside the CPU.
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
module hydra_top #(
    parameter MMR_BASE      = 'h2000_0000,
    parameter MMR_RANGE     = 'h0000_0FFF,
    parameter SCRATCH_BASE  = 'h2001_0000,
    parameter SCRATCH_RANGE = 'h003F_FFFF
)(
    input  logic                    clk, 
    input  logic                    rst_n,

    // AHB-Lite slave port (CPU programs MMR / reads scratchpad)
    input  logic                    hydra_HSEL,     // from uncore adrdecs
    input  logic [ADDR_WIDTH-1:0]   HADDR_s,
    input  logic [DATA_WIDTH-1:0]   HWDATA_s,
    input  logic                    HWRITE_s,
    input  logic [1:0]              HTRANS_s,
    input  logic                    HREADY_s,
    output logic [DATA_WIDTH-1:0]   HRDATA_s,
    output logic                    HREADYOUT_s,
    output logic                    HRESP_s,

    // AHB-Lite master port (HYDRA reads from RAM)
    output logic [ADDR_WIDTH-1:0]   HADDR_m,
    output logic [2:0]              HBURST_m, 
    output logic [2:0]              HSIZE_m,
    output logic [1:0]              HTRANS_m,
    output logic [DATA_WIDTH-1:0]   HWDATA_m,
    output logic [DATA_WIDTH/8-1:0] HWSTRB_m,
    output logic                    HWRITE_m,
    output logic [3:0]              HPROT_m,
    output logic                    HMASTLOCK_m,
    input  logic [DATA_WIDTH-1:0]   HRDATA_m,
    input  logic                    HREADY_m, 
    input  logic                    HRESP_m,

    // Arbitration handshake with wallypipelinedsoc
    input  logic                    HTRANS1_cpu,        // CPU's HTRANS[1] for arbitration
    output logic                    hydra_grant,        // 1 = HYDRA owns the bus

    // Interrupt
    output logic                    irq_hydra
);

    // MMR signals
    logic                   HSEL_mmr;
    logic [DATA_WIDTH-1:0]  HRDATA_mmr;
    logic                   HRESP_mmr;
    logic                   HREADYOUT_mmr;
    logic                   mmr_start;
    hydra_mode              mmr_mode;
    logic [DATA_BITS-1:0]   mmr_scale_shift;
    logic                   mmr_signed_out;
    logic                   mmr_round_en;
    logic [ADDR_WIDTH-1:0]  mmr_src_addr;
    logic [ADDR_WIDTH-1:0]  mmr_dst_addr;
    logic [LEN_WIDTH-1:0]   mmr_length;

    // Scratchpad sideband port signals
    logic                   HSEL_scratch;
    logic [DATA_WIDTH-1:0]  HRDATA_scratch;
    logic                   HRESP_scratch;
    logic                   HREADYOUT_scratch;
    logic                   SCRATCH_WE;
    logic [ADDR_WIDTH-1:0]  SCRATCH_WADDR;
    logic [DATA_WIDTH-1:0]  SCRATCH_WDATA;

    // Internal signals
    logic                   HSEL_none;       
    logic [ADDR_WIDTH-1:0]  HADDR_in;
    logic [ADDR_WIDTH-1:0]  hydra_dst_addr;
    logic [BEATS_WIDTH-1:0] hydra_currBeat;
    logic                   hydra_done;
    logic                   hydra_error;
    logic                   hydra_HBUSREQ;

    assign HPROT_m          = 4'b0011;      // privileged, data, non-cacheable, non-bufferable
    assign HMASTLOCK_m      = 0;
    assign HWSTRB_m         = '1;       // word write
    assign HSEL_mmr         = hydra_HSEL && &((MMR_BASE[ADDR_WIDTH-1:0]     ~^ HADDR_s) | MMR_RANGE[ADDR_WIDTH-1:0]);
    assign HSEL_scratch     = hydra_HSEL && &((SCRATCH_BASE[ADDR_WIDTH-1:0] ~^ HADDR_s) | SCRATCH_RANGE[ADDR_WIDTH-1:0]);
    assign HSEL_none        = !(HSEL_mmr || HSEL_scratch);
    assign HRDATA_s         = ({DATA_WIDTH{HSEL_mmr}} & HRDATA_mmr) | ({DATA_WIDTH{HSEL_scratch}} & HRDATA_scratch);
    // Both slaves are zero-wait-state, so HREADYOUT_s is always 1
    // HSEL_none ensures HREADYOUT_s=1 during idle cycles to prevent bus lockup
    assign HREADYOUT_s      = (HSEL_mmr && HREADYOUT_mmr) || (HSEL_scratch && HREADYOUT_scratch) || HSEL_none;
    assign HRESP_s          = (HSEL_mmr && HRESP_mmr)     || (HSEL_scratch && HRESP_scratch);
    assign HADDR_in         = HSEL_mmr ? (HADDR_s - MMR_BASE[ADDR_WIDTH-1:0]) : 
                                         (HSEL_scratch ? (HADDR_s - SCRATCH_BASE[ADDR_WIDTH-1:0]) : HADDR_s);
    assign hydra_dst_addr   = mmr_dst_addr - SCRATCH_BASE[ADDR_WIDTH-1:0];
    assign irq_hydra        = hydra_done || hydra_error;

    hydra_arbiter arbiter (
        .clk, .rst_n, .hydra_HBUSREQ,
        .hydra_currBeat, .cpu_HBUSREQ (HTRANS1_cpu),

        .hydra_grant
    );

    hydra_mmr mmr (
        .clk, .rst_n,
        .done           (hydra_done),
        .error          (hydra_error),
        .HADDR          (HADDR_in),
        .HWDATA         (HWDATA_s),
        .HWRITE         (HWRITE_s),
        .HTRANS         (HTRANS_s),
        .HSEL           (HSEL_mmr),
        .HREADY         (HREADY_s),

        .HRDATA         (HRDATA_mmr),
        .HREADYOUT      (HREADYOUT_mmr),
        .HRESP          (HRESP_mmr),
        .start          (mmr_start),
        .mode           (mmr_mode),
        .scale_shift    (mmr_scale_shift),
        .signed_out     (mmr_signed_out),
        .round_en       (mmr_round_en),
        .src_addr       (mmr_src_addr),
        .dst_addr       (mmr_dst_addr),
        .length         (mmr_length)
    );

    hydra_scratchpad scratchpad (
        .clk, .rst_n,
        .HSEL           (HSEL_scratch),
        .HADDR          (HADDR_in),
        .HTRANS         (HTRANS_s),
        .HWRITE         (HWRITE_s),
        .HREADY         (HREADY_s),
        .SCRATCH_WE,
        .SCRATCH_WADDR,
        .SCRATCH_WDATA,
        
        .HRDATA         (HRDATA_scratch),
        .HRESP          (HRESP_scratch),
        .HREADYOUT      (HREADYOUT_scratch)
    );

    hydra_transform u_transform (
        .clk, .rst_n,
        .scale_shift    (mmr_scale_shift),
        .signed_out     (mmr_signed_out),
        .round_en       (mmr_round_en),
        .start          (mmr_start),
        .mode           (mmr_mode),
        .src_addr       (mmr_src_addr),
        .dst_addr       (hydra_dst_addr),
        .length         (mmr_length),
        .HREADY         (HREADY_m && hydra_grant),
        .HRDATA         (HRDATA_m),
        .HRESP          (HRESP_m),

        .HBUSREQ        (hydra_HBUSREQ),
        .HADDR          (HADDR_m),
        .HBURST         (HBURST_m),
        .HSIZE          (HSIZE_m),
        .HTRANS         (HTRANS_m),
        .HWDATA         (HWDATA_m),
        .HWRITE         (HWRITE_m),
        .SCRATCH_WE,
        .SCRATCH_WADDR,
        .SCRATCH_WDATA,
        .currBeat       (hydra_currBeat),
        .done           (hydra_done),
        .error          (hydra_error)
    );

endmodule