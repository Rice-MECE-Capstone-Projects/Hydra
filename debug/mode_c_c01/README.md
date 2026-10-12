# Mode C C01 Debug Report

## Status

The Mode C RAM read-request duplication and overrun have been fixed in `src/hydra/hydra_transform.sv`. The zero-wait-state tests for `length=4` and `length=8` now pass: RAM read counts and addresses, scratchpad writes, and output data match the scoreboard expectations. Wait states and arbitration stalls have not yet been tested.

## Original issue

Before the fix, the first source address was accepted twice. With `length=4`, the DUT produced the correct `0x04030201` scratchpad word but then requested uninitialized address `0x80000010`, stopping the simulation with `RAM_UNINITIALIZED`. The `length=8` case similarly requested `0x80000020` beyond its configured inputs.

## Files

- [Fix investigation and regression results](mode_c_ram_read_debug.md)
- [Original cycle-level report](Mode_C.pdf)
- [Original failing simulation transcript](transcript.log)

## Reproduction

- Branch: `HYDRA_UVM_Verification`
- RTL: `src/hydra/hydra_transform.sv`
- Test: `uvm/uvm_transform/test/mode_c_basic_test.sv`
- Top: `uvm/uvm_transform/transform_top_tb.sv`
