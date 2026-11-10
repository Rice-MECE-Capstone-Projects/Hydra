//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra_tb.sv
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Unit testbench for hydra_transform, hydra_scratchpad, and 
// hydra_arbiter. AHB slave is a simple synchronous RAM model. CPU AHB 
// reads to scratchpad are not exercised here - output verification reads 
// scratchpad.mem[] directly.
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

// Test list:
//   T1  Mode B, length=NUM_ELEMS,                no wait states
//   T2  Mode B, length=2*NUM_ELEMS (two blocks), no wait states
//   T3  Mode B, length=NUM_ELEMS,                bus requested mid-burst by CPU
//   T4  Mode B, length=2*NUM_ELEMS,              bus requested mid-last-burst by CPU
//   T5  Mode B, length=64 (invalid length)       => ERROR_HALT
//   T6  Mode B, length=0 (zero length)           => ERROR_HALT
//   T7  Mode B, length=NUM_ELEMS (wrong HRESP)   => ERROR_HALT
//
//   T8  Mode C, length=2*NUM_ELEMS,  signed,   scale_shift=NUM_ELEMS/16, round_en=0->1
//   T9  Mode C, length=NUM_ELEMS,    unsigned, scale_shift=NUM_ELEMS/8,  round_en=0
//   T10 Mode C, saturation corners,  signed,   scale_shift=0,            round_en=0
//
//   T11 Mode E, sum,  incrementing positive inputs
//   T12 Mode E, max,  mixed-sign inputs
//   T13 Mode E, min,  mixed-sign inputs
//   T14 Mode E, avg,  incrementing positive inputs
//   T15 Mode E, avg,  negative window sums (arithmetic shift)
//   T16 Mode E, length=POOL_SIZE+1 (invalid)    => ERROR_HALT
//   T17 Mode E 2D, max,  8k x 8k image (k = POOL_SIZE), mixed-sign inputs
//   T18 Mode E 2D, avg,  4k x 4k image, negative window sums (arithmetic shift)
//   T19 Mode E 2D, sum,  W = 6k (rows end mid-burst), 2k rows
//   T20 Mode E 2D, max,  3 channels of 2k x 2k (CHW, pooled as one 6k x 2k image)
//   T21 Mode E 2D, min,  widest row W = k * MAX_POOL_COLS, k rows
//   T22 Mode E 2D, sum,  back-to-back transfer reuses the accumulator row
//   T23 Mode E 2D, COLS=0                        => ERROR_HALT
//   T24 Mode E 2D, COLS=k+1 (not a multiple of k) => ERROR_HALT
//   T25 Mode E 2D, COLS=k*(MAX_POOL_COLS+1)      => ERROR_HALT
//   T26 Mode E 2D, LEN not a multiple of k*k     => ERROR_HALT
//   T27 Mode E 2D, rows not a multiple of k      => ERROR_HALT (at the last word)
//
// Usage:
//   `run`      executable for log printing only
//   `runwave`  executable for waveform viewing in Questa

import hydra_pkg::*;
module hydra_tb;
  localparam int unsigned NUM_ELEMS    = BLOCK_ROWS * BLOCK_COLS;   // 128
  localparam int unsigned QUANT_DEPTH  = DATA_WIDTH / QUANT_DIM;    // 4 words => 1 packed
  localparam int unsigned RAM_WORDS    = 16384;                     // 64 KB AHB slave RAM
  localparam int unsigned TIMEOUT      = 4000;                      // max clock cycles per test

  // -------------------------SIGNALS-------------------------
  // Clock and Reset
  logic clk = 0;
  logic rst_n;
  always #5 clk = ~clk;   // 100 MHz

  // Helpers
  int inject_offset = 0;
  int inject_dur    = 0;
  int length_x      = 0;
  int scale_x       = 0;
  int signed_x      = 0;
  int round_en_x    = 0;

  // MMR
  logic                   start;
  hydra_mode              mode;
  logic [ADDR_WIDTH-1:0]  src_addr, dst_addr;
  logic [LEN_WIDTH-1:0]   length;
  logic [DATA_BITS-1:0]   scale_shift;
  logic                   signed_out, round_en;
  hydra_reduce_op         reduce_op;
  logic                   pool_2d;
  logic [LEN_WIDTH-1:0]   pool_cols;

  // Arbiter
  logic                   HBUSREQ;
  logic                   bus_grant;

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
  logic [BEATS_WIDTH-1:0] currBeat;
  logic                   done, error;

  // -------------------------RAM MODEL-------------------------
  logic [DATA_WIDTH-1:0]  ahb_ram [0:RAM_WORDS-1];
  logic [ADDR_WIDTH-1:0]  haddr_lat;
  logic                   cpu_HBUSREQ;
  logic                   HRESP_ctrl  = 0;    // default: no error

  // Simulate address and data phases with one cycle latency
  always_ff @(posedge clk) begin
    if (HTRANS_m[1] && HREADY_m)
      haddr_lat <= HADDR_m;
  end

  assign HRDATA_m = ahb_ram[haddr_lat[$clog2(RAM_WORDS)+1:2]];    // word-aligned

  // ERROR lasts one cycle and can follow `done` (wait_done returns on whichever comes first),
  // so remember any error since the last START. The CPU sees the same thing through the
  // MMR's sticky STATUS.ERROR bit
  logic err_seen;
  always_ff @(posedge clk) begin
    if (!rst_n || start) err_seen <= 0;
    else if (error)      err_seen <= 1;
  end
  assign HREADY_m = bus_grant;
  assign HRESP_m  = HRESP_ctrl;

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
    .reduce_op     (reduce_op),
    .pool_2d       (pool_2d),
    .pool_cols     (pool_cols),
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
    .currBeat      (currBeat),
    .done          (done),
    .error         (error)
  );
  hydra_scratchpad scratchpad (
    .clk           (clk),
    .rst_n         (rst_n),
    .HSEL   ('0),
    .HADDR         ('0),
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
  hydra_arbiter arbiter (
    .clk            (clk),
    .rst_n          (rst_n),
    .hydra_HBUSREQ  (HBUSREQ),
    .hydra_currBeat (currBeat),
    .cpu_HBUSREQ    (cpu_HBUSREQ),
    .hydra_grant    (bus_grant)
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

  function automatic logic [DATA_WIDTH-1:0] golden_pool (
    input int out_idx,
    input int src_base,
    input hydra_reduce_op op
  );
    logic signed [DATA_WIDTH-1:0] value;
    value = $signed(ahb_ram[src_base + out_idx*POOL_SIZE]);
    for (int k = 1; k < POOL_SIZE; k++) begin
      case (op)
        POOL_MAX: if ($signed(ahb_ram[src_base + out_idx*POOL_SIZE + k]) > value)
                    value = $signed(ahb_ram[src_base + out_idx*POOL_SIZE + k]);
        POOL_MIN: if ($signed(ahb_ram[src_base + out_idx*POOL_SIZE + k]) < value)
                    value = $signed(ahb_ram[src_base + out_idx*POOL_SIZE + k]);
        default: value = value + $signed(ahb_ram[src_base + out_idx*POOL_SIZE + k]);
      endcase
    end
    if (op == POOL_AVG)
      value = value >>> POOL_BITS;
    return value;
  endfunction

  // k x k window (k = POOL_SIZE) of a row-major image `width` words wide. Output out_idx is
  // window (out_idx / (width/k), out_idx % (width/k)), so outputs are packed in row-major order
  function automatic logic [DATA_WIDTH-1:0] golden_pool2d (
    input int out_idx,
    input int src_base,
    input int width,
    input hydra_reduce_op op
  );
    logic signed [DATA_WIDTH-1:0] value, elem;
    int out_r, out_c;
    out_r = out_idx / (width / POOL_SIZE);
    out_c = out_idx % (width / POOL_SIZE);
    for (int dy = 0; dy < POOL_SIZE; dy++) begin
      for (int dx = 0; dx < POOL_SIZE; dx++) begin
        elem = $signed(ahb_ram[src_base + (out_r*POOL_SIZE + dy)*width + out_c*POOL_SIZE + dx]);
        if (dy == 0 && dx == 0) value = elem;
        else case (op)
          POOL_MAX: if (elem > value) value = elem;
          POOL_MIN: if (elem < value) value = elem;
          default:  value = value + elem;
        endcase
      end
    end
    if (op == POOL_AVG)
      value = value >>> (2 * POOL_BITS);
    return value;
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
    reduce_op   = POOL_SUM;
    pool_2d     = 0;
    pool_cols   = 0;
    cpu_HBUSREQ = 0;
    HRESP_ctrl  = 0;
    repeat (4) @(posedge clk);
    @(negedge clk); rst_n = 1;
    @(posedge clk);
  endtask

  task automatic launch (
    input hydra_mode              m,
    input logic [ADDR_WIDTH-1:0]  src, dst, len,
    input logic [DATA_BITS-1:0]   sc,
    input logic                   s_out, r_en,
    input hydra_reduce_op         r_op = POOL_SUM,
    input logic                   p2d  = 0,
    input logic [LEN_WIDTH-1:0]   cols = '0
  );
    @(negedge clk);
    mode        = m;
    src_addr    = src;
    dst_addr    = dst;
    length      = len;
    scale_shift = sc;
    signed_out  = s_out;
    round_en    = r_en;
    reduce_op   = r_op;
    pool_2d     = p2d;
    pool_cols   = cols;
    start       = 1;
    @(posedge clk);
    @(negedge clk);
    start = 0;
  endtask

  task automatic wait_done ();
    for (int i = 0; i < TIMEOUT; i++) begin
      @(posedge clk);
      if (done || error) return;
    end
    $display("\t[TIMEOUT] T%0d: done never asserted after %0d cycles", test_id, TIMEOUT);
    errors++;
  endtask

  // Inject one-cycle HREADY=0 at a specific cycle offset from now
  task automatic inject_wait (input int cycle_offset, input int cycle_dur);
    repeat (cycle_offset) @(posedge clk);
    @(negedge clk); cpu_HBUSREQ = 1;
    repeat (cycle_dur) @(posedge clk);
    @(negedge clk); cpu_HBUSREQ = 0;
  endtask

  // Inject one-cycle HRESP=1 at a specific cycle offset from now
  task automatic inject_error (input int cycle_offset, input int cycle_dur);
    repeat (cycle_offset) @(posedge clk);
    @(negedge clk); HRESP_ctrl = 1;
    repeat (cycle_dur) @(posedge clk);
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
      scratchpad.mem[base + i] = '0;
  endtask

  task automatic check_mode_b (
    input int src_base,   // src_addr >> 2
    input int dst_base,   // dst_addr >> 2
    input int len_words
  );
    logic [DATA_WIDTH-1:0] exp, got;
    for (int i = 0; i < len_words; i++) begin
      exp = golden_b(i, src_base);
      got = scratchpad.mem[dst_base + i];
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
      got = scratchpad.mem[dst_base + i];
      if (got !== exp) begin
        $display("\t[FAIL] T%0d Mode C: scratch[%03d] = %h, expected %h",
                 test_id, dst_base + i, got, exp);
        errors++;
      end else
        $display("\t[PASS] T%0d Mode C: scratch[%03d] = %h",
                 test_id, dst_base + i, got);     
    end
  endtask

  task automatic check_mode_e (
    input int src_base,
    input int dst_base,
    input int len_words,
    input hydra_reduce_op op
  );
    logic [DATA_WIDTH-1:0] exp, got;
    for (int i = 0; i < len_words / POOL_SIZE; i++) begin
      exp = golden_pool(i, src_base, op);
      got = scratchpad.mem[dst_base + i];
      if (got !== exp) begin
        $display("\t[FAIL] T%0d Mode E: scratch[%03d] = %h, expected %h", test_id, dst_base + i, got, exp);
        errors++;
      end
    end
  endtask

  task automatic check_mode_e2d (
    input int src_base,
    input int dst_base,
    input int len_words,
    input int width,
    input hydra_reduce_op op
  );
    logic [DATA_WIDTH-1:0] exp, got;
    for (int i = 0; i < len_words / (POOL_SIZE * POOL_SIZE); i++) begin
      exp = golden_pool2d(i, src_base, width, op);
      got = scratchpad.mem[dst_base + i];
      if (got !== exp) begin
        $display("\t[FAIL] T%0d Mode E 2D: scratch[%03d] (out row %0d, col %0d) = %h, expected %h",
                 test_id, dst_base + i, i / (width / POOL_SIZE), i % (width / POOL_SIZE), got, exp);
        errors++;
      end
    end
    // The word after the last output must be untouched
    if (scratchpad.mem[dst_base + len_words / (POOL_SIZE * POOL_SIZE)] !== '0) begin
      $display("\t[FAIL] T%0d Mode E 2D: wrote past the last output", test_id);
      errors++;
    end
  endtask

  // Run one 2D pooling transfer from RAM word 0 to scratchpad word 0 and check it
  task automatic run_pool2d (input int width, input int rows, input hydra_reduce_op op);
    length_x = width * rows;
    clear_scratch(0, length_x / (POOL_SIZE * POOL_SIZE) + 1);
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, op, 1, width);
    wait_done();
    repeat (4) @(posedge clk);
    if (!err_seen) check_mode_e2d(0, 0, length_x, width, op);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();
  endtask

  // Launch a 2D transfer that must end in ERROR_HALT
  task automatic expect_pool2d_error (input int width, input int len);
    do_reset();
    launch(MODE_E, '0, '0, len, '0, '0, '0, POOL_SUM, 1, width);
    wait_done();
    repeat (4) @(posedge clk);
    if (!err_seen) begin $display("\t[FAIL] expected an error (COLS=%0d, LEN=%0d)", width, len); errors++; end
    report();
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
    do_reset();
    prev_errors = 0;

    // T1: Mode B, length=NUM_ELEMS, no wait states
    test_id   = 1;
    length_x  = NUM_ELEMS;
    $display("[T%0d] Mode B, length=%0d, no wait states", test_id, length_x);
    fill_ram_incr(0, length_x, 'h0000_0001);   // [1, 2, ..., length_x]
    clear_scratch(0, length_x);
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    wait_done();
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("[FAIL] unexpected error!"); errors++; end
    report();

    // T2: Mode B, length=2*NUM_ELEMS (two contiguous blocks), no wait states
      // drain_sel flip is the critical boundary.
    test_id   = test_id + 1;
    length_x  = 2 * NUM_ELEMS;
    $display("[T%0d] Mode B, length=%0d, %0d blocks", test_id, length_x, length_x/NUM_ELEMS);
    fill_ram_incr(0, length_x, 'h0001_0000);   // [65536, 65537, ..., 65536+length_x-1]
    clear_scratch(0, length_x);
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    wait_done();
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T3: Mode B, length=NUM_ELEMS, bus requested mid-burst by CPU
      // Expected to finish burst and then hand over bus to CPU.
      // Resume when CPU has done.
    test_id       = test_id + 1;
    length_x      = NUM_ELEMS;
    inject_offset = 15;
    inject_dur    = 60;
    $display("[T%0d] Mode B, length=%0d, wait state at cycle %0d", test_id, length_x, inject_offset);
    fill_ram_incr(0, length_x, 'h1);
    clear_scratch(0, length_x);
    fork
      inject_wait(inject_offset, inject_dur);
      begin
        launch(MODE_B, '0, '0, length_x, '0, '0, '0);
        wait_done();
      end
    join
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T4: Mode B, length=2*NUM_ELEMS, bus requested mid-last-burst by CPU
      // Expected to finish transfer and then hand over bus to CPU.
    test_id       = test_id + 1;
    length_x      = 2*NUM_ELEMS;
    inject_offset = 125 * length_x / NUM_ELEMS;
    inject_dur    = 100;
    $display("[T%0d] Mode B, length=%0d, wait state at cycle %0d", test_id, length_x, inject_offset);
    fill_ram_incr(0, length_x, 'hDEAD_0000);
    clear_scratch(0, length_x);
    fork
      inject_wait(inject_offset, inject_dur);
      begin
        launch(MODE_B, '0, '0, length_x, '0, '0, '0);
        wait_done();
      end
    join
    if (!error) check_mode_b(0, 0, length_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T5: Mode B, length=NUM_ELEMS/2 (invalid: not a multiple of NUM_ELEMS) => ERROR_HALT
    test_id   = test_id + 1;
    length_x  = NUM_ELEMS / 2;
    $display("[T%0d] Mode B, length=%0d (invalid) => expect ERROR_HALT", test_id, length_x);
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    wait_done();
    if (!error) begin
      $display("\t[FAIL] T%0d: ERROR_HALT not asserted", test_id); errors++;
    end
    report();

    // T6: Mode B, length=0 (invalid: not >0) => ERROR_HALT
    test_id   = test_id + 1;
    length_x  = 0;
    $display("[T%0d] Mode B, length=%0d => expect ERROR_HALT", test_id, length_x);
    launch(MODE_B, '0, '0, length_x, '0, '0, '0);
    wait_done();
    if (!error) begin
      $display("\t[FAIL] T%0d: ERROR_HALT not asserted", test_id); errors++;
    end
    report();

    // T7: Mode B, length=NUM_ELEMS, HRESP=1 injected early (during burst 2, ~cycle 25)
      // Expected ERROR_HALT + HBUSREQ deasserted.
    test_id       = test_id + 1;
    length_x      = NUM_ELEMS;
    inject_offset = 25;
    inject_dur    = 3;
    $display("[T%0d] Mode B, length=%0d, HRESP error at cycle %0d => expect ERROR_HALT", test_id, length_x, inject_offset);
    fill_ram_incr(0, length_x, 'h0000_0001);
    fork
      inject_error(inject_offset, inject_dur);
      launch(MODE_B, '0, '0, length_x, '0, '0, '0);
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
    test_id     = test_id + 1;
    length_x    = 2 * NUM_ELEMS;
    scale_x     = NUM_ELEMS / 16;
    signed_x    = 1;
    round_en_x  = 0;
    $display("[T%0d] Mode C, length=%0d, signed=%0d, scale_shift=%0d", test_id, length_x, signed_x, scale_x);
    fill_ram_incr(0, length_x, 'h0000_0080);   // [128, 129, ..., 128+length_x-1]
    clear_scratch(0, length_x/QUANT_DEPTH);
    $display("round_en=%0d", round_en_x);
    launch(MODE_C, '0, '0, length_x/4, scale_x, signed_x, round_en_x);
    wait_done();
    if (!error) check_mode_c(0, 0, length_x/4, scale_x, signed_x, round_en_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    $display("round_en=%0d", !round_en_x);
    launch(MODE_C, ((length_x/4)<<2), ((length_x/4)<<2)/QUANT_DEPTH, 3*length_x/4, scale_x, signed_x, !round_en_x);   // scratchpad is byte-addressed
    wait_done();
    if (!error)
      check_mode_c(((length_x/4)<<2)/QUANT_DEPTH, (length_x/4)/4, 3*length_x/4, scale_x, signed_x, !round_en_x);    // RAM model is word-addressed
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T9: Mode C, length=NUM_ELEMS, unsigned, scale_shift=NUM_ELEMS/8, round_en=0
    test_id     = test_id + 1;
    length_x    = NUM_ELEMS;
    scale_x     = NUM_ELEMS / 8;
    signed_x    = 0;
    round_en_x  = 0;
    $display("[T%0d] Mode C, length=%0d, signed=%0d, scale_shift=%0d, round_en=%0d", test_id, length_x, signed_x, scale_x, round_en_x);
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
    test_id     = test_id + 1;
    length_x    = corner_vals.size();
    scale_x     = 0;
    signed_x    = 1;
    round_en_x  = 0;
    $display("[T%0d] Mode C, saturation corners=%0d, signed=%0d, scale_shift=%0d, round_en=%0d", test_id, length_x, signed_x, scale_x, round_en_x);
    fill_ram_corners(0, length_x);
    clear_scratch(0, length_x/QUANT_DEPTH);
    launch(MODE_C, '0, '0, length_x, scale_x, signed_x, round_en_x);
    wait_done();
    if (!error) check_mode_c(0, 0, length_x, scale_x, signed_x, round_en_x);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();


    // T11: Mode E, sum reduction over four-word windows
    test_id = test_id + 1;
    length_x = 4 * POOL_SIZE;
    fill_ram_incr(0, length_x, 'h10);
    clear_scratch(0, length_x / POOL_SIZE);
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_SUM);
    wait_done();
    if (!error) check_mode_e(0, 0, length_x, POOL_SUM);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T12/T13: Mode E, signed maximum and minimum
    test_id = test_id + 1;
    length_x = 2 * POOL_SIZE;
    for (int i = 0; i < length_x; i++)
      ahb_ram[i] = (i % 2) ? -32'sd100 : 32'sd50 + i;
    clear_scratch(0, length_x / POOL_SIZE);
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_MAX);
    wait_done();
    if (!error) check_mode_e(0, 0, length_x, POOL_MAX);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    test_id = test_id + 1;
    clear_scratch(0, length_x / POOL_SIZE);
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_MIN);
    wait_done();
    if (!error) check_mode_e(0, 0, length_x, POOL_MIN);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T14: Mode E, average reduction
    test_id = test_id + 1;
    length_x = 4 * POOL_SIZE;
    fill_ram_incr(0, length_x, 'h20);
    clear_scratch(0, length_x / POOL_SIZE);
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_AVG);
    wait_done();
    if (!error) check_mode_e(0, 0, length_x, POOL_AVG);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T15: Mode E, average of negative windows (needs an arithmetic shift, rounds toward -inf)
    test_id = test_id + 1;
    length_x = 4 * POOL_SIZE;
    for (int i = 0; i < length_x; i++)
      ahb_ram[i] = (i % POOL_SIZE == 0) ? 32'sd3 + i : -32'sd37 - 5*i;
    clear_scratch(0, length_x / POOL_SIZE);
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_AVG);
    wait_done();
    if (!error) check_mode_e(0, 0, length_x, POOL_AVG);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T16: Mode E rejects a non-multiple window length
    test_id = test_id + 1;
    do_reset();
    launch(MODE_E, '0, '0, POOL_SIZE + 1, '0, '0, '0, POOL_SUM);
    wait_done();
    if (!error) begin $display("\t[FAIL] expected invalid length error"); errors++; end
    report();


    // -------------------------MODE E 2D-------------------------
    // Data patterns use i (the word index) so every window gets distinct values

    // T17: 2D max on an 8k x 8k image, mixed signs
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, max, %0dx%0d", test_id, 8*POOL_SIZE, 8*POOL_SIZE);
    for (int i = 0; i < 64*POOL_SIZE*POOL_SIZE; i++)
      ahb_ram[i] = (i % 3 == 0) ? -32'sd500 + i : 32'sd7 * ((i * 37) % 101) - 32'sd350;
    run_pool2d(8*POOL_SIZE, 8*POOL_SIZE, POOL_MAX);

    // T18: 2D average with negative window sums
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, avg, %0dx%0d, negative sums", test_id, 4*POOL_SIZE, 4*POOL_SIZE);
    for (int i = 0; i < 16*POOL_SIZE*POOL_SIZE; i++)
      ahb_ram[i] = (i % 5 == 0) ? 32'sd3 + i : -32'sd37 - 5*i;
    run_pool2d(4*POOL_SIZE, 4*POOL_SIZE, POOL_AVG);

    // T19: 2D sum, W = 6k is not a multiple of the 16-beat burst, so rows end mid-burst
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, sum, W=%0d, %0d rows", test_id, 6*POOL_SIZE, 2*POOL_SIZE);
    fill_ram_incr(0, 12*POOL_SIZE*POOL_SIZE, 'h40);
    run_pool2d(6*POOL_SIZE, 2*POOL_SIZE, POOL_SUM);

    // T20: 3 channels of 2k x 2k in CHW layout are one (3*2k) x 2k image
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, max, 3 channels of %0dx%0d", test_id, 2*POOL_SIZE, 2*POOL_SIZE);
    for (int i = 0; i < 12*POOL_SIZE*POOL_SIZE; i++)
      ahb_ram[i] = (i * 40503) ^ (i << 9);  // scrambled, non-monotonic
    run_pool2d(2*POOL_SIZE, 6*POOL_SIZE, POOL_MAX);

    // T21: widest supported row uses every accumulator slot
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, min, W=%0d (k * MAX_POOL_COLS)", test_id, POOL_SIZE*MAX_POOL_COLS);
    for (int i = 0; i < MAX_POOL_COLS*POOL_SIZE*POOL_SIZE; i++)
      ahb_ram[i] = (i % 7 == 3) ? -32'sd1 * i : 32'sd1000 - (i % 13);
    run_pool2d(POOL_SIZE*MAX_POOL_COLS, POOL_SIZE, POOL_MIN);

    // T22: a second transfer must not pick up partial results left by the first
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, sum, back-to-back transfers", test_id);
    fill_ram_incr(0, 4*POOL_SIZE*POOL_SIZE, 'h1000);
    length_x = 4*POOL_SIZE*POOL_SIZE;
    do_reset();
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_SUM, 1, 2*POOL_SIZE);
    wait_done();
    repeat (4) @(posedge clk);
    if (err_seen) begin $display("\t[FAIL] unexpected error in first transfer"); errors++; end
    fill_ram_incr(0, 4*POOL_SIZE*POOL_SIZE, 'h5);
    clear_scratch(0, 5);
    repeat (4) @(posedge clk);
    launch(MODE_E, '0, '0, length_x, '0, '0, '0, POOL_SUM, 1, 2*POOL_SIZE);
    wait_done();
    repeat (4) @(posedge clk);
    if (!err_seen) check_mode_e2d(0, 0, length_x, 2*POOL_SIZE, POOL_SUM);
    else begin $display("\t[FAIL] unexpected error"); errors++; end
    report();

    // T23-T27: invalid 2D shapes
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, COLS=0 => expect ERROR_HALT", test_id);
    expect_pool2d_error(0, POOL_SIZE*POOL_SIZE);

    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, COLS=%0d => expect ERROR_HALT", test_id, POOL_SIZE+1);
    expect_pool2d_error(POOL_SIZE+1, (POOL_SIZE+1)*POOL_SIZE*POOL_SIZE);

    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, COLS=%0d (too wide) => expect ERROR_HALT", test_id, POOL_SIZE*(MAX_POOL_COLS+1));
    expect_pool2d_error(POOL_SIZE*(MAX_POOL_COLS+1), POOL_SIZE*POOL_SIZE*(MAX_POOL_COLS+1));

    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, LEN=%0d (not a multiple of k*k) => expect ERROR_HALT", test_id, POOL_SIZE*POOL_SIZE + POOL_SIZE);
    expect_pool2d_error(POOL_SIZE, POOL_SIZE*POOL_SIZE + POOL_SIZE);

    // COLS = k*k and LEN = k*k pass the up-front checks but give a single row
    test_id = test_id + 1;
    $display("[T%0d] Mode E 2D, 1 row of %0d (rows not a multiple of k) => expect ERROR_HALT", test_id, POOL_SIZE*POOL_SIZE);
    expect_pool2d_error(POOL_SIZE*POOL_SIZE, POOL_SIZE*POOL_SIZE);


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