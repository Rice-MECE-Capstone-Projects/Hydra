# Mode C RAM Read Request Duplication and Overrun

## Summary

The Mode C basic test originally produced the correct packed scratchpad data but issued extra RAM read requests. The first source address was accepted twice, and the read sequence continued beyond the configured `length`. After changing the Mode C address-generation logic to advance on accepted read requests, the zero-wait-state tests with `length=4` and `length=8` both pass.

**Key point:** The original RTL used `first_trans`, a flag cleared one clock edge too late for next-address generation. As a result, the first address was accepted on two valid clock edges. The fix advances the address according to the number of read requests actually accepted and stops after `length` requests.

This report describes the observed behavior and the tested fix. It does not claim coverage of wait states, CPU arbitration, or all legal lengths.

## Test setup

- `mode=MODE_C`, `scale_shift=0`, `round_en=0`, `signed_out=1`.
- `src_addr=0x80000000`, `dst_addr=0x00000000`.
- The RAM model stores 32-bit values `1, 2, ...` at consecutive word addresses.
- The RAM responder returns successful, zero-wait-state reads; there is no competing CPU request.
- For `length=4`, expect four reads from `0x80000000` through `0x8000000C` and one scratchpad write of `0x04030201` at address `0`.
- For `length=8`, expect eight reads through `0x8000001C` and scratchpad writes of `0x04030201` at address `0` and `0x08070605` at address `4`.

## Behavior before the fix

For `length=4`, the RAM driver accepted `0x80000000` at both **135 ns and 145 ns**. The scratchpad output was `0x04030201`, but the DUT then requested uninitialized address `0x80000010`, causing `RAM_UNINITIALIZED`.

The `length=8` run showed the same duplicate first read and a later request to `0x80000020`. An instrumented counter of accepted Mode C read addresses reached **9** for `length=8`. Therefore, a correct final output did not imply a correct bus request sequence.

## Root cause

The original address logic selected `src_addr` whenever `first_trans` was high. `first_trans` was cleared by sequential logic after observing `HTRANS == AHB_NONSEQ`. At the clock edge that accepted the first address, the next-address calculation still used the **old** value `first_trans=1`, so it scheduled the first address again. Both cycles had a valid transfer type and ready/arbiter conditions, allowing the RAM responder to accept the same address twice.

Relevant original RTL (abridged):

```systemverilog
// Address generation
if (first_trans) begin
    next_HADDR  = src_addr;
    next_HTRANS = AHB_NONSEQ;
end else if (!done_read) begin
    next_HADDR  = src_addr + (burst << (COLS_WIDTH+2))
                           + (beat << 2) + 4;
    next_HTRANS = (beat == NUM_BEATS-1)
                ? ((count == length-1) ? AHB_IDLE : AHB_NONSEQ)
                : AHB_SEQ;
end

// Sequential update: uses the previous HTRANS value at this edge.
first_trans <= (HTRANS == AHB_NONSEQ) ? 0 : first_trans;
```

The receive-side logic began using `HRDATA` only when `start_fill || HTRANS == AHB_SEQ`. In these directed tests, that timing masked the duplicate read in the packed output while the request sequence continued beyond the expected address range.

## Fix

For Mode C, the `mode_c_read_accepted` event identifies a valid, ready read address phase. `mode_c_read_count` counts these accepted addresses and is cleared on reset and in `IDLE`. The Mode C address logic now:

1. Launches `src_addr` as the initial `NONSEQ` transfer.
2. Advances to the next word address only after the current read address is accepted.
3. Sets the next transfer type to `IDLE` once `length` reads have been accepted.

Relevant updated RTL (abridged; the surrounding `AHB_SIGNALS` defaults and Mode B branch remain in place):

```systemverilog
logic               mode_c_read_accepted;
logic [LEN_WIDTH:0] mode_c_read_count;

assign mode_c_read_accepted = (state == BUSY) && (mode == MODE_C)
                            && HREADY && HTRANS[1] && !HWRITE;

// In the sequential block: reset this counter on reset and in IDLE.
// In the non-IDLE branch:
if (mode_c_read_accepted)
    mode_c_read_count <= mode_c_read_count + 1'b1;

// In AHB_SIGNALS, inside state == BUSY and HREADY:
if (mode == MODE_C) begin
    if ((mode_c_read_count == 0) && (HTRANS == AHB_IDLE)) begin
        next_HADDR  = src_addr;
        next_HTRANS = AHB_NONSEQ;
    end else if (mode_c_read_accepted) begin
        if (mode_c_read_count + 1'b1 < {1'b0, length}) begin
            next_HADDR  = src_addr + ((mode_c_read_count + 1'b1) << 2);
            next_HTRANS = AHB_SEQ;
        end else begin
            next_HTRANS = AHB_IDLE;
        end
    end
end else begin
    // Existing Mode B address-generation logic is unchanged.
end
```

The count comparison includes the read accepted **at the current edge** (`mode_c_read_count + 1'b1`). Because the counter uses a nonblocking assignment, next-address generation sees the pre-edge count. `<< 2` advances by four bytes per 32-bit input word.

The Mode B address logic was left unchanged. The RAM responder and Mode C packing logic were not modified for this fix.

## Verification after the fix

| Test | Accepted RAM reads | Scratchpad writes | Result |
| --- | --- | --- | --- |
| `length=4` | Four unique addresses, `0x80000000`–`0x8000000C` | Address `0`: `0x04030201` | `MODE_C_MATCH`; 0 errors, 0 fatals |
| `length=8` | Eight unique addresses, `0x80000000`–`0x8000001C` | Address `0`: `0x04030201`; address `4`: `0x08070605` | `MODE_C_MATCH`; 0 errors, 0 fatals |

Both runs reported `TRANSFORM_DONE`. The scoreboard confirmed the expected read counts, read addresses, scratchpad write counts, and output data; neither run triggered `RAM_UNINITIALIZED`.


## Reproduction files

- RTL: `src/hydra/hydra_transform.sv`
- UVM test: `uvm/uvm_transform/test/mode_c_basic_test.sv`
