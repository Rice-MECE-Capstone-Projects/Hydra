# Mode C C01 Debug Report

## Summary

The basic Mode C test produces the expected output `0x04030201`, but the RAM request sequence includes a duplicate first address and an additional read beyond the configured inputs. The simulation stops with `RAM_UNINITIALIZED`.

The issue is under review; the test has not passed.

## Test Setup

- `MODE_C`, `length=4`, `scale_shift=0`, `round_en=0`, `signed_out=1`.
- RAM inputs: 1, 2, 3, 4 at `0x80000000`, `0x80000004`, `0x80000008`, and `0x8000000C`.
- Zero-wait-state RAM responses; no competing CPU traffic.
- Expected: four reads and one scratchpad write of `0x04030201` at address 0.

## Observed Issue

- **135 ns and 145 ns:** duplicate requests at `0x80000000`.
- **185 ns:** correct scratchpad output is observed, but a request at `0x80000010` triggers `RAM_UNINITIALIZED`.

## Files

- [Detailed report](Mode_C.pdf): cycle tables, waveform, and relevant RTL code.
- [Simulation transcript](transcript.log): complete simulation log.

## Reproduction

UVM code is on branch `HYDRA_UVM_Verification`, commit `1caa771`.

- Test: `uvm/uvm_transform/test/mode_c_basic_test.sv`
- Top: `uvm/uvm_transform/transform_top_tb.sv`
