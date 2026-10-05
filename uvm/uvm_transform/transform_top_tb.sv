//////////////////////////////////////////////////////////////////////////////////////////////////
// File: transform_top_tb.sv
//
// Author: Yulia Zhou
//
// Description:
// Standalone testbench for hydra_transform.
// Connects control, RAM, and scratchpad interfaces to the DUT.
// Uses the HYDRA arbiter with no competing CPU request.
// Provides clock, reset, and virtual-interface configuration.
//
// Project: HYDRA UVM Verification
//////////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module transform_top_tb;
    import uvm_pkg::*;
    import hydra_pkg::*;
    import transform_pkg::*;

    `include "uvm_macros.svh"

    // clock and reset
    logic clk=1'b0;
    logic rst_n=1'b0;

    logic hydra_HBUSREQ;
    logic hydra_grant;
    logic [BEATS_WIDTH-1:0] hydra_currBeat;

    logic transform_HREADY;

    // 10ns clock period
    always #5 clk=~clk;

    // release reset on a falling edge
    initial begin
        repeat(5) @(negedge clk);
        rst_n=1'b1;
    end

    // interfaces
    transform_ctrl_if ctrl_if(
        .clk(clk),
        .rst_n(rst_n)
    );

    transform_ram_if ram_if(
        .clk(clk),
        .rst_n(rst_n),
        .hydra_grant(hydra_grant)
    );

    transform_scratch_if scratch_if(
        .clk(clk),
        .rst_n(rst_n)
    );

    // transform advances only when RAM is ready and the arbiter grants HYDRA access
    assign transform_HREADY = ram_if.HREADY & hydra_grant;

    // no competing CPU traffic in the first test
    hydra_arbiter arbiter(
        .clk(clk),
        .rst_n(rst_n),
        .hydra_HBUSREQ(hydra_HBUSREQ),
        .hydra_currBeat(hydra_currBeat),
        .cpu_HBUSREQ(1'b0),
        .hydra_grant(hydra_grant)
    );

    // DUT
    hydra_transform dut(
        .clk(clk),
        .rst_n(rst_n),

        // configuration from the control driver
        .scale_shift (ctrl_if.scale_shift),
        .signed_out(ctrl_if.signed_out),
        .round_en(ctrl_if.round_en),
        .start(ctrl_if.start),
        .mode(ctrl_if.mode),
        .src_addr(ctrl_if.src_addr),
        .dst_addr(ctrl_if.dst_addr),
        .length(ctrl_if.length),
        
        // arbitration and effective ready
        .HREADY(transform_HREADY),
        .HBUSREQ(hydra_HBUSREQ),

        // RAM-side AHB signals
        .HADDR(ram_if.HADDR),
        .HBURST(ram_if.HBURST),
        .HSIZE(ram_if.HSIZE),
        .HTRANS(ram_if.HTRANS),
        .HWDATA(ram_if.HWDATA),
        .HWRITE(ram_if.HWRITE),
        .HRDATA(ram_if.HRDATA),
        .HRESP(ram_if.HRESP),

        // scratchpad write outputs
        .SCRATCH_WE(scratch_if.SCRATCH_WE),
        .SCRATCH_WADDR(scratch_if.SCRATCH_WADDR),
        .SCRATCH_WDATA(scratch_if.SCRATCH_WDATA),

        .currBeat(hydra_currBeat),
        .done(ctrl_if.done),
        .error(ctrl_if.error)
    );

// configure virtual interfaces before starting UVM
initial begin
    uvm_config_db#(virtual transform_ctrl_if)::set(null,"uvm_test_top.m_env.m_ctrl_agent.*","vif",ctrl_if);
    uvm_config_db#(virtual transform_ram_if)::set(null,"uvm_test_top.m_env.m_ram_agent.*","vif",ram_if);
    uvm_config_db#(virtual transform_scratch_if)::set(null,"uvm_test_top.m_env.m_scratch_monitor","vif",scratch_if);

    run_test("mode_c_basic_test");
end

endmodule

