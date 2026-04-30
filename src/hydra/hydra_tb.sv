// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// hydra_tb.sv
// Rice University - Project HYDRA
// Author: Giovanni <gs86@rice.edu>
// Description: Unit testbench for hydra_transform + hydra_scratchpad.
//
// DUT scope: hydra_transform and hydra_scratchpad in isolation.
// AHB slave is a simple synchronous RAM model. Bus grant is a 1-cycle
// delayed copy of HBUSREQ. CPU AHB reads to scratchpad are not exercised
// here - output verification reads u_scratchpad.mem[] directly.
//
// Test list:
//   T1  Mode B, length=NUM_ELEMS,                no wait states
//   T2  Mode B, length=2*NUM_ELEMS (two blocks), no wait states
//   T3  Mode B, length=NUM_ELEMS,                wait state injected early
//   T4  Mode B, length=NUM_ELEMS,                wait state injected mid-burst
//   T5  Mode B, length=64 (invalid length)       => ERROR_HALT
//   T6  Mode B, length=0 (zero length)           => ERROR_HALT
//   T7  Mode B, length=NUM_ELEMS (wrong HRESP)   => ERROR_HALT

//   T8  Mode C, length=2*NUM_ELEMS,  signed,   scale_shift=NUM_ELEMS/16, round_en=0->1
//   T9  Mode C, length=NUM_ELEMS,    unsigned, scale_shift=NUM_ELEMS/8,  round_en=0
//   T10 Mode C, saturation corners,  signed,   scale_shift=0,            round_en=0
//
// Usage:
//   `run`      executable for log printing only
//   `runwave`  executable for waveform viewing in Questa

import hydra_pkg::*;
module hydra_tb;
  localparam int unsigned NUM_ELEMS    = BLOCK_ROWS * BLOCK_COLS;   // 128
  localparam int unsigned QUANT_DEPTH  = DATA_WIDTH / QUANT_DIM;    // 4 words => 1 packed
  localparam int unsigned RAM_WORDS    = 16384;                     // 64 KB AHB slave RAM
  localparam int unsigned TIMEOUT      = 2000;                      // max clock cycles per test

  // -------------------------SIGNALS-------------------------
  // Clock and Reset
  logic clk = 0;
  logic rst_n;
  always #5 clk = ~clk;   // 100 MHz

  // Helpers
  int length_x    = 0;
  int scale_x     = 0;
  int signed_x    = 0;
  int round_en_x  = 0;

  // MMR
  logic                   start;
  hydra_mode              mode;
  logic [ADDR_WIDTH-1:0]  src_addr, dst_addr;
  logic [LEN_WIDTH-1:0]   length;
  logic [DATA_BITS-1:0]   scale_shift;
  logic                   signed_out, round_en;

  // Arbiter
  logic                   HBUSREQ, bus_grant;

  // RAM
  logic [ADDR_WIDTH-1:0]  HADDR_m;
  logic [2:0]             HBURST_m;
  logic [2:0]             HSIZE_m;
  logic [1:0]             HTRANS_m;
  logic [ADDR_WIDTH-1:0]  HWDATA_m;
  logic                   HWRITE_m;
  logic [ADDR_WIDTH-1:0]  HRDATA_m;
  logic                   HREADY_m;
  logic                   HRESP_m;

  // Scratchpad
  logic                   SCRATCH_WE;
  logic [ADDR_WIDTH-1:0]  SCRATCH_WADDR;
  logic [DATA_WIDTH-1:0]  SCRATCH_WDATA;

  // Status
  logic         done, error;

  // -------------------------RAM MODEL-------------------------
  logic [DATA_WIDTH-1:0]  ahb_ram [0:RAM_WORDS-1];
  logic [ADDR_WIDTH-1:0]  haddr_lat;
  logic                   HREADY_ctrl = 1;    // default: always ready
  logic                   HRESP_ctrl  = 0;    // default: no error

  // Simulate address and data phases with one cycle latency
  always_ff @(posedge clk) begin
    if (HTRANS_m[1] && HREADY_m)
      haddr_lat <= HADDR_m;
  end

  assign HRDATA_m = ahb_ram[haddr_lat[$clog2(RAM_WORDS)+1:2]];    // word-aligned
  assign HREADY_m = HREADY_ctrl;
  assign HRESP_m  = HRESP_ctrl;

  // -------------------------Arbiter MODEL-------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) bus_grant <= 0;
    else        bus_grant <= HBUSREQ;
  end

  // -------------------------DUTs-------------------------
  hydra_transform u_transform (
    .clk           (clk),
    .rst_n         (rst_n),
    .start         (start),
    .mode          (mode),
    .src_addr      (src_addr),
    .dst_addr      (dst_addr),
    .length        (length),
    .scale_shift   (scale_shift),
    .signed_out    (signed_out),
    .round_en      (round_en),
    .bus_grant     (bus_grant),
    .HBUSREQ       (HBUSREQ),
    .HADDR         (HADDR_m),
    .HBURST        (HBURST_m),
    .HSIZE         (HSIZE_m),
    .HTRANS        (HTRANS_m),
    .HWDATA        (HWDATA_m),
    .HWRITE        (HWRITE_m),
    .HRDATA        (HRDATA_m),
    .HREADY        (HREADY_m),
    .HRESP         (HRESP_m),
    .SCRATCH_WE    (SCRATCH_WE),
    .SCRATCH_WADDR (SCRATCH_WADDR),
    .SCRATCH_WDATA (SCRATCH_WDATA),
    .done          (done),
    .error         (error)
  );
  hydra_scratchpad u_scratchpad (
    .clk           (clk),
    .rst_n         (rst_n),
    .HSELScratch   ('0),
    .HADDR         ('0),
    .HBURST        ('0),
    .HSIZE         ('0),
    .HTRANS        ('0),    // AHB_IDLE
    .HWRITE        ('0),
    .HREADY        ('1),
    .HRDATA        (),
    .HRESP         (),
    .HREADYOUT     (),
    .SCRATCH_WE    (SCRATCH_WE),
    .SCRATCH_WADDR (SCRATCH_WADDR),
    .SCRATCH_WDATA (SCRATCH_WDATA)
  );

  // -------------------------GOLDEN MODELS-------------------------
  int  errors  = 0;
  int  test_id = 0;

  // Mode B
  function automatic logic [DATA_WIDTH-1:0] golden_b (
    input int out_idx,    // absolute scratchpad word index
    input int src_base    // src_addr >> 2
  );
    int blk, local_i, r, c;
    blk     = out_idx / NUM_ELEMS;
    local_i = out_idx % NUM_ELEMS;
    r       = local_i % BLOCK_ROWS;
    c       = local_i / BLOCK_ROWS;
    return ahb_ram[src_base + blk * NUM_ELEMS + r * BLOCK_COLS + c];
  endfunction

  // Mode C
  function automatic logic [DATA_WIDTH-1:0] golden_c (
    input int                   out_idx,
    input int                   src_base,
    input logic [DATA_BITS-1:0] sc,
    input logic                 s_out,
    input logic                 r_en
  );
    golden_c = '0;
    for (int k = 0; k < QUANT_DEPTH; k++)
      golden_c[k*QUANT_DIM +: QUANT_DIM] = 
        quant_fn(ahb_ram[src_base + out_idx*QUANT_DEPTH + k], sc, s_out, r_en);
    return golden_c;
  endfunction

  // -------------------------TASKS-------------------------
  task automatic do_reset ();
    rst_n       = 0;
    start       = 0;
    mode        = IDLE;
    src_addr    = 0;
    dst_addr    = 0;
    length      = 0;
    scale_shift = 0;
    signed_out  = 0;
    round_en    = 0;
    HREADY_ctrl = 1;
    HRESP_ctrl  = 0;
    repeat (4) @(posedge clk);
    @(negedge clk); rst_n = 1;
    @(posedge clk);
  endtask

  task automatic launch (
    input hydra_mode              m,
    input logic [ADDR_WIDTH-1:0]  src, dst, len,
    input logic [DATA_BITS-1:0]   sc,
    input logic                   s_out, r_en
  );
    @(negedge clk);
    mode        = m;
    src_addr    = src;
    dst_addr    = dst;
    length      = len;
    scale_shift = sc;
    signed_out  = s_out;
    round_en    = r_en;
    start       = 1;
    @(posedge clk);
    @(negedge clk);
    start = 0;
  endtask

  task automatic wait_done ();
    for (int i = 0; i < TIMEOUT; i++) begin
      @(posedge clk); #1;
      if (done || error) return;
    end
    $display("\t[TIMEOUT] T%0d: done never asserted after %0d cycles", test_id, TIMEOUT);
    errors++;
  endtask

  // Inject one-cycle HREADY=0 at a specific cycle offset from now
  task automatic inject_wait (input int cycle_offset);
    repeat (cycle_offset) @(posedge clk);
    @(negedge clk); HREADY_ctrl = 0;
    @(posedge clk);
    @(negedge clk); HREADY_ctrl = 1;
  endtask

  // Inject one-cycle HRESP=1 at a specific cycle offset from now
  task automatic inject_error (input int cycle_offset);
    repeat (cycle_offset) @(posedge clk);
    @(negedge clk); HRESP_ctrl = 1;
    @(posedge clk);
    @(negedge clk); HRESP_ctrl = 0;
  endtask

  // Fill RAM incrementally 
  task automatic fill_ram_incr (
    input int base, n,
    input logic [DATA_WIDTH-1:0] base_val
  );
    for (int i = 0; i < n; i++)
      ahb_ram[base + i] = base_val + i;
  endtask

// Fill RAM with saturation corner cases for MODE C
  task automatic fill_ram_corners (input int base, input int n);
    for (int i = 0; i < n; i++) begin
      ahb_ram[base + i] = corner_vals[i % corner_vals.size()];    // corner_vals[] in hydra_pkg.sv
    end
  endtask

  task automatic clear_scratch (input int base, input int n);
    for (int i = 0; i < n; i++)
      u_scratchpad.mem[base + i] = '0;
  endtask

  task automatic check_mode_b (
    input int src_base,   // src_addr >> 2
    input int dst_base,   // dst_addr >> 2
    input int len_words
  );
    logic [DATA_WIDTH-1:0] exp, got;
    for (int i = 0; i < len_words; i++) begin
      exp = golden_b(i, src_base);
      got = u_scratchpad.mem[dst_base + i];
      if (got !== exp) begin
        $display("\t[FAIL] T%0d Mode B: scratch[%03d] = %h, expected %h",
                 test_id, dst_base + i, got, exp);
        errors++;
      end else
        $display("\t[PASS] T%0d Mode B: scratch[%03d] = %h",
                 test_id, dst_base + i, got);
    end
  endtask

  task automatic check_mode_c (
    input int                   src_base,
    input int                   dst_base,
    input int                   len_words,
    input logic [DATA_BITS-1:0] sc,
    input logic                 s_out,
    input logic                 r_en
  );
    logic [DATA_WIDTH-1:0] exp, got;
    int out_words;
    out_words = len_words / QUANT_DEPTH;
    for (int i = 0; i < out_words; i++) begin
      exp = golden_c(i, src_base, sc, s_out, r_en);
      got = u_scratchpad.mem[dst_base + i];
      if (got !== exp) begin
        $display("\t[FAIL] T%0d Mode C: scratch[%03d] = %h, expected %h",
                 test_id, dst_base + i, got, exp);
        errors++;
      end else
        $display("\t[PASS] T%0d Mode C: scratch[%03d] = %h",
                 test_id, dst_base + i, got);     
    end
  endtask

  int prev_errors;
  task automatic report ();
    if (errors == prev_errors)
      $display("T%0d PASSED SUCCESSFULLY!", test_id);
    else
      $display("T%0d FAILED! Encountered %0d new error(s).", test_id, errors - prev_errors);
    prev_errors = errors;
  endtask


  // -------------------------MAIN-------------------------
  initial begin
    $dumpfile("hydra_tb.vcd");
    $dumpvars(0, hydra_tb);

    $display("-----------------------------------------------------------------");
    $display("HYDRA TESTBENCH (hydra_transform + hydra_scratchpad)");
    $display();   // \n
    prev_errors = 0;

    // T1: Mode B, length=NUM_ELEMS, no wait states
    test_id   = 1;
    length_x  = NUM_ELEMS;
    $display("[T1] Mode B, length=%0d, no wait states", length_x);
    do_reset();
    fill_ram_incr(0, length_x, 'h0000_0001);   // [1, 2, ..., length_x]
    clear_scratch(0, length_x);
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    wait_done();
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("[FAIL] unexpected error!"); errors++; end
    report();

    // T2: Mode B, length=2*NUM_ELEMS (two contiguous blocks), no wait states
      // drain_sel flip is the critical boundary.
    test_id   = 2;
    length_x  = 2 * NUM_ELEMS;
    $display("[T2] Mode B, length=%0d, %0d blocks", length_x, length_x/NUM_ELEMS);
    do_reset();
    fill_ram_incr(0, length_x, 'h0001_0000);   // [65536, 65537, ..., 65536+length_x-1]
    clear_scratch(0, length_x);
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    wait_done();
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T3: Mode B, length=NUM_ELEMS, wait state injected early (during burst 1, ~cycle 20)
    test_id   = 3;
    length_x  = NUM_ELEMS;
    $display("[T3] Mode B, length=%0d, wait state at cycle 20", length_x);
    do_reset();
    fill_ram_incr(0, length_x, 'h1);
    clear_scratch(0, length_x);
    fork
      inject_wait(20);
      begin
        launch(MODE_B, '0, '0, length_x, '0, '0, '0);
        wait_done();
      end
    join
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T4: Mode B, length=NUM_ELEMS, wait state injected mid-burst (during burst 6, ~cycle 100)
      // wait state happens late in transfer, near drain start.
    test_id   = 4;
    length_x  = NUM_ELEMS;
    $display("[T4] Mode B, length=%0d, wait state at cycle 100", length_x);
    do_reset();
    fill_ram_incr(0, length_x, 'hDEAD_0000);
    clear_scratch(0, length_x);
    fork
      inject_wait(100);
      begin
        launch(MODE_B, '0, '0, length_x, '0, '0, '0);
        wait_done();
      end
    join
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T5: Mode B, length=NUM_ELEMS/2 (invalid: not a multiple of NUM_ELEMS) => ERROR_HALT
    test_id   = 5;
    length_x  = NUM_ELEMS / 2;
    $display("[T5] Mode B, length=%0d (invalid) => expect ERROR_HALT", length_x);
    do_reset();
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    repeat (10) @(posedge clk); #1;
    if (!error) begin
      $display("\t[FAIL] T%0d: ERROR_HALT not asserted", test_id); errors++;
    end
    report();

    // T6: Mode B, length=0 (invalid: not >0) => ERROR_HALT
    test_id   = 6;
    length_x  = 0;
    $display("[T6] Mode B, length=%0d => expect ERROR_HALT", length_x);
    do_reset();
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    repeat (10) @(posedge clk); #1;
    if (!error) begin
      $display("\t[FAIL] T%0d: ERROR_HALT not asserted", test_id); errors++;
    end
    report();

    // T7: Mode B, length=NUM_ELEMS, HRESP=1 injected early (during burst 1, ~cycle 25)
      // Expected ERROR_HALT + HBUSREQ deasserted.
    test_id   = 7;
    length_x  = NUM_ELEMS;
    $display("[T7] Mode B, length=%0d, HRESP error at cycle 25 => expect ERROR_HALT", length_x);
    do_reset();
    fill_ram_incr(0, length_x, 'h0000_0001);
    fork
      inject_error(25);
      begin
        launch(MODE_B, '0, '0, length_x, '0, '0, '0);
        repeat (60) @(posedge clk);
      end
    join
    #1;
    if (!error) begin
      $display("\t[FAIL] T%0d: ERROR_HALT not asserted after HRESP", test_id); errors++;
    end
    // HBUSREQ must have been deasserted (done_B or error path clears it)
    @(posedge clk); #1;
    if (HBUSREQ) begin
      $display("\t[FAIL] T%0d: HBUSREQ still high after ERROR_HALT", test_id); errors++;
    end
    report();


    // T8: Mode C, length=2*NUM_ELEMS, signed, scale_shift=NUM_ELEMS/16, round_en=0->1
      // Values around shift boundary => should be '1' with round_en=1 or index>32, '0' otherwise
    test_id     = 8;
    length_x    = 2 * NUM_ELEMS;
    scale_x     = NUM_ELEMS / 16;
    signed_x    = 1;
    round_en_x  = 0;
    $display("[T8] Mode C, length=%0d, signed=%0d, scale_shift=%0d", length_x, signed_x, scale_x);
    do_reset();
    fill_ram_incr(0, length_x, 'h0000_0080);   // [128, 129, ..., 128+length_x-1]
    clear_scratch(0, length_x/QUANT_DEPTH);
    $display("round_en=%0d", round_en_x);
    launch(MODE_C, '0, '0, length_x/4, scale_x, signed_x, round_en_x);
    wait_done();
    if (!error) check_mode_c(0, 0, length_x/4, scale_x, signed_x, round_en_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    do_reset();
    $display("round_en=%0d", !round_en_x);
    launch(MODE_C, ((length_x/4)<<2), ((length_x/4)<<2)/QUANT_DEPTH, 3*length_x/4, scale_x, signed_x, !round_en_x);   // scratchpad is byte-addressed
    wait_done();
    if (!error)
      check_mode_c(((length_x/4)<<2)/QUANT_DEPTH, (length_x/4)/4, 3*length_x/4, scale_x, signed_x, !round_en_x);    // RAM model is word-addressed
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T9: Mode C, length=NUM_ELEMS, unsigned, scale_shift=NUM_ELEMS/8, round_en=0
    test_id     = 9;
    length_x    = NUM_ELEMS;
    scale_x     = NUM_ELEMS / 8;
    signed_x    = 0;
    round_en_x  = 0;
    $display("[T9] Mode C, length=%0d, signed=%0d, scale_shift=%0d, round_en=%0d", length_x, signed_x, scale_x, round_en_x);
    do_reset();
    fill_ram_incr(0, length_x, 'h0000_0000);
    for (int i = 0; i < length_x; i++)
      ahb_ram[i] = i << scale_x;
    clear_scratch(0, length_x/QUANT_DEPTH);
    launch(MODE_C, '0, '0, length_x, scale_x, signed_x, round_en_x);
    wait_done();
    if (!error) check_mode_c(0, 0, length_x, scale_x, signed_x, round_en_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T10: Mode C, saturation corners, signed, scale_shift=0, round_en=0
      // All four clip cases.
    test_id     = 10;
    length_x    = corner_vals.size();
    scale_x     = 0;
    signed_x    = 1;
    round_en_x  = 0;
    $display("[T10] Mode C, saturation corners=%0d, signed=%0d, scale_shift=%0d, round_en=%0d", length_x, signed_x, scale_x, round_en_x);
    do_reset();
    fill_ram_corners(0, length_x);
    clear_scratch(0, length_x/QUANT_DEPTH);
    launch(MODE_C, '0, '0, length_x, scale_x, signed_x, round_en_x);
    wait_done();
    if (!error) check_mode_c(0, 0, length_x, scale_x, signed_x, round_en_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();


    // SUMMARY
    $display();   // \n
    $display("Results: %0d error(s) across %0d test(s).", errors, test_id);
    if (!errors)
      $display("ALL TESTS PASSED!");
    else
      $display("SOME TESTS FAILED!");
    $display("-----------------------------------------------------------------");
    $stop;
  end

endmodule