# HYDRA UVM Verification Test Plan

## 1. Objective and scope

Verify the HYDRA control and transform path in three stages:

1. **MMR unit level:** exercise CPU AHB register accesses, readback, data patterns, and reset behavior.
2. **Transform unit level:** verify Mode B block transposition and Mode C quantization using a RAM responder, monitors, and an independent scoreboard.
3. **HYDRA top level:** configure the integrated design through CPU AHB writes to the MMR, supply input data through the RAM responder, and check scratchpad results through CPU AHB readback.

Mode B and Mode C are separate operating modes selected through the control register. A top-level test also checks a Mode C operation followed by a Mode B operation without reset.

## 2. Verification approach and common checks

The CPU AHB agent drives register accesses. At Transform unit level, the control agent drives the configuration and START pulse, the RAM model supplies preloaded input words, and monitors publish accepted RAM reads and scratchpad writes. The scoreboard checks transaction counts, addresses, RAM responses and data, and scratchpad data against a reference calculation. At top level, tests check STATUS and read the resulting scratchpad words through the CPU AHB interface. RAM-read and scratchpad-write observations also support count and no-traffic checks.

A normal test passes when the DUT completes without timeout, all observed addresses and data match the reference, expected read and write counts match, STATUS reports no error at top level, and the UVM report contains no unexpected errors or fatals. An invalid-configuration test passes when the DUT reports an error and generates no RAM reads or scratchpad writes. Seeded random tests use reproducible seeds; each passing seed proves only its generated configuration and input pattern.

### MMR unit-level checks

The MMR checks are grouped here by verified behavior; these labels do not imply existing test-class names.

| ID | Scenario | Expected result | Status |
| --- | --- | --- | --- |
| M01 | Write and read back the SRC register. | Readback matches the written value. | Passed |
| M02 | Read back SRC, DST, and LEN after separate writes. | Each register retains its own value; writes do not alter the others. | Passed |
| M03 | Apply all-zero, all-one, alternating-bit, and walking-one patterns. | Readback follows each register's writable-bit behavior. | Passed |
| M04 | Apply reset and read the registers. | Reset values match the register specification. | Passed |

## 3. Mode B Transform unit-level tests

An 8 × 16 input block contains 128 words. Within a block, input index `i` maps to output index `(i % 16) * 8 + i / 16`, using integer division. Each word is transferred unchanged; the destination order implements the transpose. A valid Mode B length is a nonzero multiple of 128.

### B01: Basic single-block transpose — Passed

- **Configuration:** `mode=MODE_B`, `length=128`, no RAM wait states.
- **Input:** 128 distinct words: `RAM[src_addr + 4*i] = i + 1`, `i=0…127`.
- **Expected:** 128 RAM reads and 128 scratchpad writes. Input word `i` appears at `dst_addr + 4*((i % 16)*8 + i/16)`.

### B02: Two-block transpose and buffer switching — Passed

- **Configuration:** `mode=MODE_B`, `length=256`, no RAM wait states.
- **Input:** 256 distinct words: `RAM[src_addr + 4*i] = i + 1`, `i=0…255`.
- **Expected:** 256 reads and 256 writes. Each 128-word block is transposed independently; the second output block begins at `dst_addr + 512`.

### B03: Three-block buffer reuse — Passed

- **Configuration:** `mode=MODE_B`, `length=384`, no RAM wait states.
- **Input:** 384 distinct words.
- **Expected:** 384 reads and 384 writes. All three blocks match their reference addresses and data, including reuse of the first internal buffer.

### B04: RAM wait states — Passed

- **Configuration:** `mode=MODE_B`, `length=256`, with read wait states, including a block-boundary case.
- **Input:** 256 distinct words.
- **Expected:** The address remains stable during a wait. After the wait, all 256 accepted reads and transposed writes match the reference.

### B05: Bus arbitration — Passed

- **Configuration:** `mode=MODE_B`, `length=128` or `256`; delay or interrupt HYDRA's bus grant.
- **Input:** Distinct words.
- **Expected:** Reads resume at the correct address, without skipped or repeated transfers. All output addresses and data match the reference.

### B06: Invalid lengths — Passed

- **Configuration:** Try `length=0` and `length=64` in Mode B; B01 covers valid `length=128`.
- **Expected:** The DUT asserts `error` for each invalid length, with no RAM reads or scratchpad writes.

### B07: Back-to-back operations — Passed

- **Configuration:** Run two Mode B operations without reset, using different source and destination regions.
- **Input:** Distinct data for each operation.
- **Expected:** Both transposes match independently. Counters, addresses, and internal buffer state do not leak from the first operation into the second.

### B08: Seeded random Mode B — Passed

- **Configuration:** Select one to three blocks per seed: `length=128`, `256`, or `384`.
- **Input:** Preload a seed-dependent pattern with a distinct 32-bit value at each input position.
- **Expected:** Exactly `length` reads and `length` writes. The scoreboard verifies the RAM data and addresses and the transposed output order for every block.

## 4. Mode C Transform unit-level tests

Mode C converts each input word to one output byte. The reference applies the configured rounding, arithmetic shift, and signed or unsigned saturation in the specified order, then packs four bytes into one scratchpad word. A valid Mode C length is a nonzero multiple of four.

### C01: Basic data flow and packing — Passed

- **Configuration:** `length=4`, `scale_shift=0`, `round_en=0`, `signed_out=1`.
- **Input:** `1, 2, 3, 4`.
- **Expected:** Four reads and one write of `32'h0403_0201` at `dst_addr`.

### C02: Multiple output words — Passed

- **Configuration:** `length=8`; other settings match C01.
- **Input:** `1–8`.
- **Expected:** Write `32'h0403_0201` at `dst_addr` and `32'h0807_0605` at `dst_addr+4`. Check grouping and counts.

### C03: Shifting — Passed

- **Configuration:** C01 with `scale_shift=1`.
- **Input:** `1, 2, 3, 4`.
- **Expected:** One write of `32'h0201_0100`.

### C04: Rounding — Passed

- **Configuration:** `length=4`, `scale_shift=1`, `signed_out=1`; run with `round_en=0` and `1`.
- **Input:** `1, 2, 3, 4`.
- **Expected:** `32'h0201_0100` without rounding; `32'h0202_0101` with rounding.

### C05: Signed and unsigned saturation boundaries — Passed

- **Configuration:** No shift or rounding; run signed and unsigned output separately.
- **Input:** Values within, at, and beyond `[-128,127]` and `[0,255]`, in groups of four.
- **Expected:** In-range values remain unchanged and out-of-range values saturate. For example, signed inputs `-129, -128, -127, 0` produce `32'h0081_8080`.

### C06: RAM wait states — Passed

- **Configuration:** Start with C01 and insert RAM wait cycles during reads.
- **Expected:** Address and `HTRANS` remain stable while stalled. Only accepted reads advance the count. Exactly four addresses are read in order and one correct packed word is written.

### C07: Bus arbitration — Passed

- **Configuration:** Start with C02; delay the grant and exercise competing CPU traffic where supported.
- **Expected:** An ungranted request is not counted. On resumption, no read is lost or repeated and the output matches C02.

### C08: Length validation — Passed

- **Configuration:** `scale_shift=0`, `round_en=0`, `signed_out=1`; request `length=9`.
- **Expected:** The DUT reports an error; no RAM reads or scratchpad writes occur.

### C09: Back-to-back Mode C operations — Passed

- **Configuration:** Run two operations in one simulation with different source and destination addresses and input values.
- **Expected:** The second operation begins at its own first source address. Read count and packing state reset; no extra read or output contamination occurs.

### C10: Combined arithmetic corner cases — Passed

- **Configuration:** Use `scale_shift>0`, rounding on and off, and signed and unsigned output.
- **Input:** Positive and negative values around rounding thresholds and saturation limits.
- **Expected:** Each byte matches the independently calculated reference after rounding, shifting, and saturation in the specified order.

### C11: Seeded random Mode C — Passed

- **Configuration:** For each seed, choose `length` from `4, 8, 12, 16`, `scale_shift` from `1–4`, and randomize `round_en` and `signed_out`.
- **Input:** `length` seeded signed values from `−512` to `511`.
- **Expected:** Exactly `length` RAM reads and `length/4` scratchpad writes. Every output byte matches the scoreboard's independent calculation, with no UVM errors or fatals.

For C06–C11, the common checks also include accepted-read addresses, scratchpad addresses, completion, and no unexpected error or timeout. Record the wait-state or arbitration stimulus for the applicable runs.

## 5. HYDRA top-level integration tests

These tests exercise the complete path: CPU AHB configuration → MMR → Transform RAM reads → scratchpad writes → CPU AHB result readback. Valid runs require `STATUS=0`; invalid-length runs require an error indication and no RAM or scratchpad traffic.

### I01: Mode C basic end-to-end flow — Passed

- **Configuration:** Mode C, `length=4`, `scale_shift=0`, `round_en=0`, `signed_out=1`.
- **Input:** `1, 2, 3, 4`.
- **Expected:** Four RAM reads; CPU reads `32'h0403_0201` from scratchpad; STATUS has no error.

### I02: Mode B basic end-to-end flow — Passed

- **Configuration:** Mode B, `length=128`.
- **Input:** 128 distinct words, `1–128`.
- **Expected:** 128 reads; CPU checks all 128 output words in transposed order; STATUS has no error.

### I03: Mode C shifting, rounding, and multiple outputs — Passed

- **Configuration:** Mode C, `length=8`, `scale_shift=1`, `round_en=1`, `signed_out=1`.
- **Input:** `0–7`.
- **Expected:** Eight reads and two consecutive scratchpad writes. CPU readback matches `32'h0201_0100` and `32'h0403_0302`.

### I04: Mode C signed and unsigned outputs — Passed

- **Configuration:** Separate runs with `signed_out=1` and `0`; `length=4`, no shift or rounding.
- **Input:** `0x7F`, `0x80`, `0xFF`, `0x100`.
- **Expected:** CPU reads `32'h7F7F_7F7F` for signed output and `32'hFFFF_807F` for unsigned output. STATUS has no error.

### I05: Mode B two-block operation — Passed

- **Configuration:** Mode B, `length=256`.
- **Input:** 256 distinct words, `1–256`.
- **Expected:** 256 reads; CPU checks every output against the independent transpose, including the block boundary.

### I06: Invalid-length rejection — Passed

- **Configuration:** Run invalid Mode C and Mode B lengths in separate simulations.
- **Input:** No RAM preload is required.
- **Expected:** CPU observes the STATUS error indication; no RAM reads or scratchpad writes occur.

### I07: Consecutive operations across modes — Passed

- **Configuration:** Mode C followed by Mode B without reset; use different source and destination regions.
- **Input:** Distinct data for both operations.
- **Expected:** Both complete and CPU readback matches each reference result, without stale configuration or data.

### I08: Randomized Mode C end-to-end — Passed

- **Configuration:** Run reproducible seeds; randomize valid `length` (`4, 8, 12, 16`), `scale_shift` (`1–4`), signed output, rounding, and aligned source/destination addresses.
- **Input:** Seed-dependent signed values from `−512` to `511`.
- **Expected:** CPU readback matches every independently calculated and packed byte. `STATUS=0`; exactly `length` reads and `length/4` writes.

### I09: Randomized Mode B end-to-end — Passed

- **Configuration:** Run reproducible seeds with one or two 128-word blocks and valid aligned addresses.
- **Input:** Distinct seed-dependent values.
- **Expected:** CPU readback matches the independent 8 × 16 transpose for each block. `STATUS=0`; exactly `length` reads and `length` writes. Both the 128-word and 256-word cases have been observed passing.

## 6. Coverage and coverage-driven tests

### Functional configuration coverage

The initial merged functional configuration coverage was **94.44%** (22/26 bins). The uncovered bins were four combinations of Mode C signed output, rounding, and shifting settings. I identified these gaps in the coverage report and added targeted runs of the existing top-level random test to exercise them.

#### FC01: Close Mode C arithmetic configuration cross — Passed

- **Configuration:** Extend the top-level Mode C random regression with seed `404` and four targeted combinations of `signed_out`, `round_en`, and zero/nonzero `scale_shift`: `(0,0,1)`, `(0,1,1)`, `(0,1,0)`, and `(1,1,0)`.
- **Input:** Seeded RAM values from `−512` to `511`; each run uses the existing independent Mode C reference calculation.
- **Expected:** CPU readback matches every packed output word, with no UVM errors or fatals.
- **Coverage result:** The four previously missed arithmetic cross bins were hit, raising the cross from 4/8 to 8/8 and overall functional configuration coverage from **94.44%** (22/26 bins) to **100%** (26/26 bins).

### RTL code coverage

The integration regression also collects statement, branch, and FSM coverage for the DUT hierarchy under `/hydra_top_tb/dut`. The initial filtered RTL code coverage was **92.75%**. Missed branches were mapped to the RTL and reviewed for functional relevance before adding tests. This percentage describes the enabled code coverage metrics for this hierarchy; it is separate from the 100% functional configuration coverage.

#### CV01: Mode C long transfer and output-address wrap — Passed

- **Configuration:** Extend the top-level Mode C random test with seed `404`, `length=132`, `scale_shift=0`, `round_en=0`, and `signed_out=1`.
- **Input:** 132 seeded RAM words; the sequence independently calculates every packed output byte.
- **Expected:** 132 RAM reads and 33 scratchpad writes. CPU readback matches all 33 outputs, including the output after the first 128 inputs at `dst_addr+128`; STATUS reports no error.
- **Coverage result:** The previously missed `quant_curr` wrap and `offset` update branches were each hit once. Transform branch coverage rose from 118/126 to 120/126, and overall filtered RTL code coverage rose from 92.75% to 93.05%.

#### CV02: Clear sticky STATUS after invalid length — Passed

- **Configuration:** Extend I06 in separate Mode C and Mode B runs. Use invalid lengths of 3 and 64, respectively.
- **Expected:** Poll STATUS until its error bit is 1. Write STATUS through CPU AHB, then read it back as 0. Neither rejected operation causes a RAM read or scratchpad write.
- **Coverage result:** The MMR `STATUS` write branch was hit twice. MMR branch coverage rose from 15/21 to 16/21, statement coverage rose from 28/33 to 29/33, and overall filtered RTL code coverage rose from 93.05% to **93.33%**.

#### CV03: MMR configuration register readback — Coverage observed

- **Configuration:** Extend the top-level Mode C basic sequence to read back `SRC`, `DST`, and `LEN` through CPU AHB. Write `CTRL=0x106` without `START`, read it back, then write `CTRL=0x107` to start the operation.
- **Expected:** Readback equals the programmed values (`0x80000000`, `0x20010000`, `4`, and `0x106`), followed by the original Mode C result check.
- **Coverage result:** The merged report shows one read of each configuration register. Adding `SRC`, `DST`, and `LEN` readback raised MMR branch coverage from 16/21 to 18/21, statement coverage from 29/33 to 31/33, and overall filtered RTL code coverage from 93.33% to 93.91%. The later `CTRL` readback raised these figures to **19/21**, **32/33**, and **94.19%**, respectively. The pasted coverage reports do not include UVM error summaries for these runs.

#### CV04: Top-level CPU bus contention — Passed

- **Configuration:** Reuse the Mode B basic end-to-end test with `length=128` and enable CPU contention with `+CPU_CONTENTION`.
- **Stimulus:** Assert the CPU bus request after HYDRA receives a grant, hold it until HYDRA yields at a burst boundary, then release it and check that HYDRA regains the grant.
- **Expected:** The grant pauses and resumes, all 128 RAM reads and transposed scratchpad outputs remain correct, and the run has no UVM errors or fatals.
- **Coverage result:** The previously unhit arbiter branch at line 60 was hit 17 times. Arbiter branch coverage rose from 6/7 to **7/7 (100%)**, and overall filtered RTL code coverage rose from 94.19% to **94.49%**. The run confirmed that HYDRA yielded and regained the bus, with the Mode B result passing and no UVM errors or fatals.

#### CV05: Top-level RAM wait state — Passed

- **Configuration:** Reuse the Mode C basic end-to-end test with `+RAM_WAIT`; the RAM responder inserts two wait cycles after the first accepted read.
- **Expected:** Exactly four ordered RAM reads and one correctly packed scratchpad output (`0x04030201`), with no UVM errors or fatals.
- **Result:** The first and second RAM-read log entries were 30 ns apart, versus 10 ns for subsequent reads. The output check passed with zero UVM errors and fatals. The Transform `HREADY=0` branch count increased from one to two, but overall filtered RTL code coverage remained **94.49%** because this branch was already covered.

### Remaining code coverage review

- The final merged RTL code coverage is **94.49%**; arbiter and scratchpad branch coverage reached **100%**.
- Remaining uncovered branches mainly involve unmapped MMR addresses, unsupported operating modes, and redundant RTL conditions.
- One top-level branch requires a CPU-side wait state, which the current zero-wait-state testbench does not generate.
- The planned MMR, Mode B, Mode C, and top-level verification is complete; the remaining uncovered branches do not affect the results of these tests.


