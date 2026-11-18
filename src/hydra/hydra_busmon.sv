//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_busmon.sv
//
// Author: bjw8 <bjw8@rice.edu>, 18 Nov 2026
//
// Description: Simulation-only AHB traffic monitor (not synthesizable, not part of HYDRA).
//              Counts accepted AHB transfers (one per beat) on the shared bus, split by master
//              (CPU vs HYDRA) and direction. CPU transfers addressed to HYDRA's slave port
//              (MMR / scratchpad) are also counted separately as cpu_hy.
//
//              Software brackets a measurement by writing an id to MARK_ADDR (an unused MMR
//              offset, which hydra_mmr ignores). On each marker write the monitor prints a
//              snapshot of the running counters:
//                BUSMON mark=<id> cpu_rd=.. cpu_wr=.. cpu_hy=.. hy_rd=.. hy_wr=..
//              Differences between two snapshots give the traffic inside the window. The
//              marker write itself is one CPU write beat (counted in cpu_wr and cpu_hy).
//
//              Enabled by `define HYDRA_BUSMON (see wallypipelinedsoc.sv).
//
// A component of the HYDRA project.
// https://github.com/Rice-MECE-Capstone-Projects/Hydra
//
// Copyright (C) 2025-26 Rice University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//////////////////////////////////////////////////////////////////////////////////////////////////

module hydra_busmon #(
    parameter int unsigned  ADDR_WIDTH = 32,
    parameter int unsigned  DATA_WIDTH = 32,
    parameter logic [63:0]  MARK_ADDR  = 64'h2000_0018
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  hydra_grant,  // 1: HYDRA owns the bus, 0: CPU
    input  logic                  hydra_HSEL,   // CPU transfer targets HYDRA's slave port
    input  logic [ADDR_WIDTH-1:0] HADDR_bus,
    input  logic [1:0]            HTRANS_bus,
    input  logic                  HWRITE_bus,
    input  logic [DATA_WIDTH-1:0] HWDATA_bus,
    input  logic                  HREADY
);
  // synthesis translate_off
  longint unsigned cpu_rd, cpu_wr, cpu_hy, hy_rd, hy_wr;
  logic            mark_pending;

  wire accepted = HTRANS_bus[1] && HREADY;  // NONSEQ or SEQ address phase accepted

  always_ff @(posedge clk) begin
    if (reset) begin
      {cpu_rd, cpu_wr, cpu_hy, hy_rd, hy_wr} <= '0;
      mark_pending <= 0;
    end else begin
      if (accepted) begin
        if (hydra_grant) begin
          if (HWRITE_bus) hy_wr  <= hy_wr  + 1;
          else            hy_rd  <= hy_rd  + 1;
        end else begin
          if (HWRITE_bus) cpu_wr <= cpu_wr + 1;
          else            cpu_rd <= cpu_rd + 1;
          if (hydra_HSEL) cpu_hy <= cpu_hy + 1;
        end
      end

      // Marker: CPU write address phase to MARK_ADDR, data arrives in the next accepted cycle
      if (mark_pending && HREADY) begin
        $display("BUSMON mark=%0d cpu_rd=%0d cpu_wr=%0d cpu_hy=%0d hy_rd=%0d hy_wr=%0d",
                 HWDATA_bus, cpu_rd, cpu_wr, cpu_hy, hy_rd, hy_wr);
        mark_pending <= 0;
      end
      if (accepted && !hydra_grant && HWRITE_bus && HADDR_bus == MARK_ADDR[ADDR_WIDTH-1:0])
        mark_pending <= 1;
    end
  end
  // synthesis translate_on
endmodule
