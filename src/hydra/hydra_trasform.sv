// HYDRA transformation datapath.

// Implements the AHB master state machine and the dual-MBTB ping-pong
// buffer for Mode B (matrix transposition) and the combinational
// quantization pipeline for Mode C.

`timescale 1ns/1ps

module hydra_transform #(
    parameter int unsigned ADDR_WIDTH  = 32,
    parameter int unsigned DATA_WIDTH  = 32,
    // Mode B block dimensions for 32-bit elements: 8 rows x 16 columns
    parameter int unsigned BLOCK_ROWS  = 8,
    parameter int unsigned BLOCK_COLS  = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Control from MMR
    input  logic                  start,
    input  logic [1:0]            mode,    // 2'b01=B, 2'b10=C
    input  logic [ADDR_WIDTH-1:0] src_addr,
    input  logic [ADDR_WIDTH-1:0] dst_addr,
    input  logic [15:0]           length,  // number of 32-bit words

    // Arbiter
    input  logic                  bus_grant,
    output logic                  HBUSREQ,

    // AHB-Lite master port
    output logic [ADDR_WIDTH-1:0] HADDR,
    output logic [2:0]            HBURST,
    output logic [2:0]            HSIZE,
    output logic [1:0]            HTRANS,
    output logic [DATA_WIDTH-1:0] HWDATA,
    output logic                  HWRITE,
    input  logic [DATA_WIDTH-1:0] HRDATA,
    input  logic                  HREADY,
    input  logic                  HRESP,

    // Status
    output logic                  done,
    output logic                  irq
);

endmodule