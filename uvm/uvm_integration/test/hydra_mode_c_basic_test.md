# HYDRA Top-Level Integration Debug and Fixes

## 1. Scratchpad data did not reach the CPU

The test wrote the correct packed word, `0x04030201`, but the CPU initially read `0`. The scratchpad returned its data one cycle after the read address was accepted. By then, the current `HSEL_scratch` had gone low.

**Before:** the mux used the current address-phase selection.

```systemverilog
assign HRDATA_s =
    ({DATA_WIDTH{HSEL_mmr}} & HRDATA_mmr) |
    ({DATA_WIDTH{HSEL_scratch}} & HRDATA_scratch);
```

**After:** save the selected slave when the read address is accepted, then use that selection for the returning data.

```systemverilog
always_ff @(posedge clk) begin
    if (!rst_n) begin
        read_mmr_q     <= 1'b0;
        read_scratch_q <= 1'b0;
    end
    else if (HREADY_s) begin
        read_mmr_q     <= HSEL_mmr     && HTRANS_s[1] && !HWRITE_s;
        read_scratch_q <= HSEL_scratch && HTRANS_s[1] && !HWRITE_s;
    end
end

assign HRDATA_s =
    ({DATA_WIDTH{read_mmr_q}} & HRDATA_mmr) |
    ({DATA_WIDTH{read_scratch_q}} & HRDATA_scratch);
```

After this change, the CPU read the correct scratchpad value.

## 2. STATUS read returned `X`

The scratchpad address range also matched MMR addresses, so a STATUS read selected both slaves. The scratchpad’s uninitialized read data could then introduce `X` into the mux output.

**Fix:** give MMR addresses priority in the scratchpad selection.

```systemverilog
assign HSEL_scratch =
    hydra_HSEL && !HSEL_mmr &&
    &((SCRATCH_BASE[ADDR_WIDTH-1:0] ~^ HADDR_s) |
      SCRATCH_RANGE[ADDR_WIDTH-1:0]);
```

STATUS then returned a definite value, but that value was `1`.

## 3. STATUS reported an error before the operation started

After reset, `length=0`, so `invalid_length=1`. The original state transition checked `invalid_length` even when no operation had started:

```systemverilog
if (HRESP || invalid_length)
    next_state = ERROR;
```

MMR retained the resulting error in `error_reg`, so STATUS remained `1` even after the valid Mode C operation completed.

**Fix:** check configuration length on START and bus errors during an active operation.

```systemverilog
if ((state == IDLE && start && invalid_length) ||
    (state == BUSY && HRESP))
    next_state = ERROR;
```

## Result

After recompiling, `hydra_mode_c_basic_test` completed four RAM reads, wrote and read back `0x04030201`, passed the STATUS check, and reported zero UVM errors or fatals.