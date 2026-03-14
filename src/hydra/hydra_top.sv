// HYDRA: High-Yield Data Reorganization and Acceleration

// Top-level integration module. Instantiates the arbiter, transform
// datapath, and MMR register file. Connects to the Wally AHB-Lite bus
// fabric as a second master alongside the CPU.

`timescale 1ns/1ps

module hydra_top #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // AHB-Lite Master port (HYDRA as bus master for data transfers)
    output logic [ADDR_WIDTH-1:0] HADDR_m,
    output logic [2:0]            HBURST_m,
    output logic [2:0]            HSIZE_m,
    output logic [1:0]            HTRANS_m,
    output logic [DATA_WIDTH-1:0] HWDATA_m,
    output logic                  HWRITE_m,
    input  logic [DATA_WIDTH-1:0] HRDATA_m,
    input  logic                  HREADY_m,
    input  logic                  HRESP_m,

    // AHB-Lite Slave port (CPU programs HYDRA through MMR)
    input  logic [ADDR_WIDTH-1:0] HADDR_s,
    input  logic [DATA_WIDTH-1:0] HWDATA_s,
    input  logic                  HWRITE_s,
    input  logic [1:0]            HTRANS_s,
    input  logic                  HSEL_s,
    input  logic                  HREADY_s,
    output logic [DATA_WIDTH-1:0] HRDATA_s,
    output logic                  HREADYOUT_s,
    output logic                  HRESP_s,

    // Arbiter interface (shared with CPU master)
    output logic                  HBUSREQ,
    input  logic                  HGRANT,

    // Interrupt to CPU on transfer completion
    output logic                  irq_done
);

    // Internal wires — connect submodules once implemented
    logic        arb_grant;
    logic        mmr_start;
    logic [1:0]  mmr_mode;       // 2'b00=A, 2'b01=B, 2'b10=C
    logic [31:0] mmr_src_addr;
    logic [31:0] mmr_dst_addr;
    logic [15:0] mmr_length;
    logic        xfm_done;

    hydra_arbiter u_arbiter (
        .clk        (clk),
        .rst_n      (rst_n),
        .HBUSREQ    (HBUSREQ),
        .HGRANT     (HGRANT),
        .grant_out  (arb_grant)
    );

    hydra_mmr u_mmr (
        .clk        (clk),
        .rst_n      (rst_n),
        .HADDR      (HADDR_s),
        .HWDATA     (HWDATA_s),
        .HWRITE     (HWRITE_s),
        .HTRANS     (HTRANS_s),
        .HSEL       (HSEL_s),
        .HREADY     (HREADY_s),
        .HRDATA     (HRDATA_s),
        .HREADYOUT  (HREADYOUT_s),
        .HRESP      (HRESP_s),
        .start      (mmr_start),
        .mode       (mmr_mode),
        .src_addr   (mmr_src_addr),
        .dst_addr   (mmr_dst_addr),
        .length     (mmr_length),
        .done       (xfm_done)
    );

    hydra_transform u_transform (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (mmr_start),
        .mode       (mmr_mode),
        .src_addr   (mmr_src_addr),
        .dst_addr   (mmr_dst_addr),
        .length     (mmr_length),
        .bus_grant  (arb_grant),
        .HADDR      (HADDR_m),
        .HBURST     (HBURST_m),
        .HSIZE      (HSIZE_m),
        .HTRANS     (HTRANS_m),
        .HWDATA     (HWDATA_m),
        .HWRITE     (HWRITE_m),
        .HRDATA     (HRDATA_m),
        .HREADY     (HREADY_m),
        .HRESP      (HRESP_m),
        .HBUSREQ    (HBUSREQ),
        .done       (xfm_done),
        .irq        (irq_done)
    );

endmodule