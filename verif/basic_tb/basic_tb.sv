// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// basic_tb.sv
// Rice University — Project HYDRA
// Author: Matthew Nutt
// Description: Basic testbench for verifying Hydra functionality.
// Adapted from ELEC 422 testbench design.

`timescale 1ns/1ps

localparam CLK_DELAY = 10;

task clock (input int repetitions);
    for (int i = 0; i < repetitions; i++) begin
        clk = 0;
        #CLK_DELAY;
        clk = 1;
        #CLK_DELAY;
    end
endtask



module basic_tb();

// Parameters for module
localparam int in_ADDR_WIDTH = 32;
localparam int in_DATA_WIDTH = 32;

// Inputs to module
reg                         clk         = '{default:0};
reg                         rst_n       = '{default:1};

reg [in_DATA_WIDTH-1:0]     HRDATA_m    = '{default:0};
reg                         HREADY_m    = '{default:0};
reg                         HRESP_m     = '{default:0};

reg [in_ADDR_WIDTH-1:0]     HADDR_s     = '{default:0};
reg [in_DATA_WIDTH-1:0]     HWDATA_s    = '{default:0};
reg                         HWRITE_s    = '{default:0};
reg [1:0]                   HTRANS_s    = '{default:0};
reg                         HSEL_s      = '{default:0};
reg                         HREADY_s    = '{default:0};

reg                         HGRANT      = '{default:0};

// Outputs from module
logic [in_ADDR_WIDTH-1:0]   HADDR_m;
logic [2:0]                 HBURST_m;
logic [2:0]                 HSIZE_m;
logic [1:0]                 HTRANS_m;
logic [in_DATA_WIDTH-1:0]   HWDATA_m;
logic                       HWRITE_m;

logic [in_DATA_WIDTH-1:0]   HRDATA_s; 
logic                       HREADYOUT_s;
logic                       HRESP_s;

logic                       HBUSREQ;

logic                       irq_done;



// Instantiate the module
hydra_top top #(parameter in_ADDR_WIDTH = 32, parameter in_DATA_WIDTH = 32)
(
    .clk,           // input
    .rst_n,         // input

    // AHB-Lite Master port (HYDRA as bus master for data transfers)
    .HADDR_m,       // output, [ADDR_WIDTH-1:0]
    .HBURST_m,      // output, [2:0]
    .HSIZE_m,       // output, [2:0]
    .HTRANS_m,      // output, [1:0]
    .HWDATA_m,      // output, [DATA_WIDTH-1:0]
    .HWRITE_m,      // output
    .HRDATA_m,      // input, [DATA_WIDTH-1:0]
    .HREADY_m,      // input
    .HRESP_m,       // input

    // AHB-Lite Slave port (CPU programs HYDRA through MMR)
    .HADDR_s,       // input, [ADDR_WIDTH-1:0]
    .HWDATA_s,      // input, [DATA_WIDTH-1:0]
    .HWRITE_s,      // input
    .HTRANS_s,      // input, [1:0]
    .HSEL_s,        // input
    .HREADY_s,      // input
    .HRDATA_s,      // output, [DATA_WIDTH-1:0]
    .HREADYOUT_s,   // output
    .HRESP_s,       // output

    // Arbiter interface (shared with CPU master)
    .HBUSREQ,       // output
    .HGRANT,        // input

    // Interrupt to CPU on transfer completion
    .irq_done       // output
);



initial
begin

// Write outputs to vcd file
$dumpfile("basic_tb.vcd");
$dumpvars;

// Specify input waveforms here ================================================

// restart
rst_n = 0;
clock(1);
rst_n = 1;

// idle
clock(10);

// receive programming from CPU over MMR





// End the testbench
$stop;

end

endmodule
