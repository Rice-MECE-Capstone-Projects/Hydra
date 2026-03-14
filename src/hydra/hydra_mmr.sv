// HYDRA Memory-Mapped Register file.

// Implements an AHB-Lite slave interface through which the host CPU
// programs transfer descriptors and reads status.
//
// Register map (word-addressed, 32-bit):
//   Offset 0x00 : CTRL    [0]=START [1]=MODE[1:0] (W) / [3]=DONE (R)
//   Offset 0x04 : SRC     source address
//   Offset 0x08 : DST     destination address
//   Offset 0x0C : LEN     transfer length in 32-bit words [15:0]
//   Offset 0x10 : STATUS  [0]=BUSY [1]=DONE [2]=ERROR (read-only)

`timescale 1ns/1ps

module hydra_mmr #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // AHB-Lite slave port
    input  logic [ADDR_WIDTH-1:0] HADDR,
    input  logic [DATA_WIDTH-1:0] HWDATA,
    input  logic                  HWRITE,
    input  logic [1:0]            HTRANS,
    input  logic                  HSEL,
    input  logic                  HREADY,
    output logic [DATA_WIDTH-1:0] HRDATA,
    output logic                  HREADYOUT,
    output logic                  HRESP,

    // Decoded control outputs to hydra_transform
    output logic                  start,
    output logic [1:0]            mode,
    output logic [ADDR_WIDTH-1:0] src_addr,
    output logic [ADDR_WIDTH-1:0] dst_addr,
    output logic [15:0]           length,

    // Status input from hydra_transform
    input  logic                  done
);

endmodule