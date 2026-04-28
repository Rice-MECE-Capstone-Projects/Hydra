# TOP_CORE — Full-Core RV32I Verification Environment

## Overview

`TOP_CORE` is the primary integrated verification environment for the RV32I processor core.

This environment combines:
- Full-core simulation
- Functional coverage collection
- Decoder scoreboarding
- ALU scoreboarding
- Branch verification
- BRAM-backed instruction and data memories
- RISC-V-DV randomized program execution

The infrastructure is designed around a modular, coverage-driven verification methodology intended to support:
- incremental verification bring-up
- subsystem isolation
- reusable scoreboards
- future RTL expansion
- additional module-level instrumentation
- integration with more advanced cores or pipelines

The active simulation infrastructure is located in:

```text
TOP_CORE/project_files/
```

---

# Directory Structure

```text
TOP_CORE/
├── CORE/
├── CORE_TB/
├── coverage/
├── programs/
├── project_files/
├── program.hex
├── COVERAGE_SCOREBOARD_PROJECT.mpf
└── transcript
```

---

# Main Active Simulation Files

## project_files/

The `project_files/` directory contains the active full-core verification infrastructure.

### Key Files

| File | Purpose |
|---|---|
| `tb_smoke_riscv32i.sv` | Main full-core simulation testbench |
| `riscv32i.v` | Top-level DUT |
| `core_coverage.sv` | Functional coverage collection |
| `decoder_scoreboard.sv` | Decoder scoreboard |
| `alu_scoreboard.sv` | ALU scoreboard |
| `branch_scoreboard.sv` | Branch verification scoreboard |
| `golden_alu_pkg.sv` | Golden ALU behavioral model |
| `golden_decocder.sv` | Golden decoder model |
| `core_if.sv` | Shared core interface |
| `core_smoke_test.sv` | Smoke test logic |
| `core_smoke_test_pkg.sv` | Shared package definitions |
| `bram_ins.sv` | Instruction memory BRAM |
| `bram_mem.sv` | Data memory BRAM |
| `ins_mem_model.sv` | Behavioral instruction memory |
| `program.hex` | Active instruction image loaded into memory |

---

# Verification Methodology

The environment uses a modular scoreboard and coverage-driven approach.

The core methodology consists of:
1. Running realistic instruction streams through the full pipeline
2. Monitoring internal DUT behavior
3. Comparing DUT outputs against behavioral golden models
4. Collecting functional coverage
5. Expanding instruction diversity using RISC-V-DV

This structure allows:
- subsystem reuse
- easy expansion
- incremental refinement
- integration of new pipeline stages or modules

---

# Functional Coverage

Coverage collection is implemented in:

```text
project_files/core_coverage.sv
```

Coverage is collected dynamically during full-core execution.

---

## Decoder Coverage

Decoder coverage tracks:
- opcode usage
- instruction-type activation
- decode behavior
- instruction diversity

Examples:
- R-type
- I-type
- load/store
- branch
- jump
- system/fence instructions

The decoder coverage model can be extended by:
- adding new coverpoints
- refining instruction categorization
- adding cross coverage
- incorporating pipeline-state conditions

---

## ALU Coverage

ALU coverage tracks:
- arithmetic operations
- logical operations
- shift operations
- comparison operations

Examples:
- ADD/SUB
- XOR/OR/AND
- SLT/SLTU
- SLL/SRL/SRA

The ALU scoreboard compares DUT results against:
- `golden_alu_pkg.sv`

Additional operations can be added by:
- extending the scoreboard
- adding opcode mappings
- updating ALU covergroups

---

## Branch Coverage

Branch verification tracks:
- branch decisions
- comparison outcomes
- redirect behavior
- branch instruction execution

Examples:
- BEQ
- BNE
- BLT
- BGE

The branch scoreboard validates:
- expected branch decisions
- redirect correctness
- comparison logic behavior

This framework can be expanded to:
- branch prediction verification
- hazard interaction testing
- pipeline flush verification
- speculative execution support

---

# Coverage Output

Coverage artifacts are stored in:

```text
TOP_CORE/coverage/
```

Example files:

| File | Purpose |
|---|---|
| `core_cov.ucdb` | Coverage database |
| `merged_cov.ucdb` | Merged coverage database |
| `core_cov_report.txt` | Coverage summary |
| `merged_coverage.txt` | Merged coverage report |

---

# Program Execution Flow

Programs are executed by loading a Verilog-compatible HEX file into instruction memory.

Instruction loading occurs through:

```systemverilog
$readmemh("program.hex", mem_array);
```

The active instruction image is:

```text
TOP_CORE/program.hex
```

Additional example programs are stored in:

```text
TOP_CORE/programs/
```

---

# Running Simulation

## Linux / Rice CLEAR Environment

Use UVM-1.1d:

```bash
export UVM_HOME=/clear/apps/siemens-2023/questa/2023.2/questasim/verilog_src/uvm-1.1d
```

Navigate to the environment:

```bash
cd TOP_CORE
```

---

# Compilation

Compile all project files:

```bash
vlog -sv -timescale 1ns/1ns -mfcu \
+incdir+./project_files+$UVM_HOME/src \
project_files/*.sv
```

---

# Running the Smoke Test

Run the main simulation:

```bash
vsim work.tb_smoke_riscv32i
run -all
```

Expected output includes:
- UVM startup messages
- scoreboard activity
- coverage collection
- smoke-test completion

A successful smoke test typically confirms:
- PC progression
- decode correctness
- instruction execution
- final termination condition

---

# Coverage Collection

Run simulation with coverage enabled:

```bash
vsim -c -coverage work.tb_smoke_riscv32i -do "run -all; quit"
```

---

# Generating Coverage Reports

Generate coverage reports using:

```bash
vcover report core_cov.ucdb
```

Merge multiple coverage runs:

```bash
vcover merge merged_cov.ucdb *.ucdb
```

Generate merged report:

```bash
vcover report merged_cov.ucdb
```

Coverage reports may also be redirected to text:

```bash
vcover report merged_cov.ucdb > merged_coverage.txt
```

---

# RISC-V-DV Integration

This environment supports integration with Google RISC-V-DV.

RISC-V-DV is used to generate randomized RV32I instruction programs that execute through the full pipeline.

---

# Installing RISC-V-DV

Clone the repository:

```bash
git clone https://github.com/google/riscv-dv.git
cd riscv-dv
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Install the RISC-V toolchain:

```bash
sudo apt install gcc-riscv64-unknown-elf
```

Verify installation:

```bash
riscv32-unknown-elf-gcc --version
python3 run.py --help
```

---

# Generating Randomized Programs

Generate randomized RV32I programs:

```bash
python3 run.py \
    --test riscv_rand_instr_test \
    --isa rv32i \
    --instr_cnt=200
```

Optional constraints:

```bash
--no_load_store
--no_branch_jump
--no_csr_instr
```

Generated assembly files:

```text
out_0.S
```

---

# Compiling Assembly → ELF

Compile generated assembly:

```bash
riscv32-unknown-elf-gcc \
    -march=rv32i \
    -mabi=ilp32 \
    -nostdlib \
    -T linker.ld \
    out_0.S \
    -o out_0.elf
```

---

# Example Linker Script

```ld
ENTRY(_start)

SECTIONS {
  . = 0x0;

  .text : {
    *(.text*)
  }
}
```

---

# Converting ELF → Verilog HEX

Convert ELF into a Verilog-compatible HEX file:

```bash
riscv32-unknown-elf-objcopy -O verilog out_0.elf out_0.hex
```

Resulting format:

```text
00b50533
403505b3
00c58633
...
```

Each line corresponds to a 32-bit instruction word.

---

# Loading Programs Into TOP_CORE

Copy the generated HEX file into:

```text
TOP_CORE/program.hex
```

Example:

```bash
cp out_0.hex TOP_CORE/program.hex
```

Then rerun simulation.

---

# Expanding the Environment

The verification framework is intentionally modular and designed to support incremental expansion as the processor RTL evolves.

The current structure separates:
- DUT integration
- interfaces
- scoreboards
- golden behavioral models
- coverage collection
- memory infrastructure
- program generation

This allows new functionality to be added with minimal disruption to existing infrastructure.

Possible expansions include:
- additional scoreboards
- hazard verification
- forwarding verification
- memory consistency checking
- cache support
- branch prediction verification
- CSR validation
- exception handling
- pipeline flush verification
- architectural reference models
- cross-coverage refinement
- constrained-random UVM sequences
- multi-core support
- out-of-order pipeline instrumentation
- speculative execution tracking

---

# Adding New Scoreboards Into TOP_CORE

The existing framework already demonstrates the general structure required for integrating new scoreboard-driven verification components.

Current examples include:
- `decoder_scoreboard.sv`
- `alu_scoreboard.sv`
- `branch_scoreboard.sv`

These can be used as templates for future module-level verification components.

---

## General Scoreboard Integration Flow

A new scoreboard is typically integrated through the following steps:

### 1. Expose DUT Signals Through Interfaces

Relevant DUT signals should first be exposed through:
- `core_if.sv`
- dedicated module interfaces
- pipeline-stage observation signals

Examples:
- pipeline valid bits
- stall signals
- forwarding selects
- cache hit/miss indicators
- branch prediction metadata
- CSR writes
- exception flags

This ensures monitors and scoreboards remain decoupled from direct DUT hierarchy references.

---

### 2. Create a Behavioral Golden Model

A behavioral reference model should be implemented to generate expected outputs.

Examples:
- forwarding decision logic
- branch prediction logic
- cache state tracking
- CSR state updates
- hazard detection behavior

The golden model should:
- avoid cycle-level RTL duplication
- operate behaviorally
- remain implementation-independent
- focus on architectural correctness

Examples already present:
- `golden_alu_pkg.sv`
- `golden_decocder.sv`

---

### 3. Create a Monitor or Observation Layer

The monitor collects:
- DUT outputs
- internal control signals
- pipeline metadata
- transaction state

For pipeline-aware modules, this often includes:
- instruction opcode
- source/destination registers
- valid bits
- PC values
- branch targets
- memory addresses

The monitor should package this information into transaction-like structures before forwarding to the scoreboard.

---

### 4. Implement the Scoreboard

The scoreboard compares:
- DUT behavior
- expected behavior from the golden model

The scoreboard may:
- immediately compare results
- maintain state history
- track outstanding transactions
- model pipeline timing

Typical scoreboard responsibilities:
- mismatch reporting
- assertion triggering
- debug logging
- scoreboard statistics
- pass/fail tracking

---

### 5. Integrate Functional Coverage

Coverage should be integrated alongside scoreboard development.

Typical additions include:
- new covergroups
- cross coverage
- state transition coverage
- control-flow coverage
- pipeline interaction coverage

Examples:
- forwarding source combinations
- stall cause combinations
- branch prediction accuracy
- exception type coverage
- cache eviction patterns

Coverage is currently centralized in:

```text
project_files/core_coverage.sv
```

though future expansion may separate coverage into module-specific files.

---

# Example Expansion Targets

## Hazard Verification

Potential additions:
- RAW hazard detection coverage
- stall insertion checking
- forwarding-vs-stall correctness
- pipeline bubble tracking

Possible signals:
- `stall`
- `flush`
- source/destination register dependencies
- valid bits

---

## Cache Verification

Potential additions:
- cache hit/miss scoreboards
- memory consistency checking
- refill verification
- eviction tracking
- writeback verification

Would likely require:
- transaction-level memory monitors
- cache state models
- memory latency modeling

---

## CSR Verification

Potential additions:
- CSR access legality
- privilege checks
- exception generation
- CSR state tracking

Would require:
- CSR behavioral model
- CSR access monitor
- architectural state comparison

---

## Exception / Flush Verification

Potential additions:
- illegal instruction handling
- pipeline flush correctness
- redirect timing validation
- interrupt entry/return verification

Would require:
- precise PC tracking
- pipeline-valid tracking
- exception-state monitoring

---

# Adapting the Framework to Wally

The framework was intentionally developed in a sufficiently modular way that it can serve as a foundation for integration with more advanced open-source RISC-V cores such as Wally.

Wally introduces substantially more architectural complexity than the current RV32I implementation, including:
- deeper pipelines
- more advanced hazard handling
- branch prediction infrastructure
- caches
- privilege support
- CSR infrastructure
- MMU/TLB behavior
- potentially multiple issue/control paths depending on configuration

The existing framework would not need to be discarded; instead, the methodology can be incrementally extended.

---

# Expected Architectural Changes Required for Wally

## 1. Expanded Interface Instrumentation

The current framework primarily monitors:
- decode outputs
- ALU behavior
- branch decisions
- basic pipeline state

Wally integration would require exposing significantly more metadata through interfaces.

Examples include:
- pipeline stage valid bits
- stall/flush controls
- forwarding selects
- branch prediction metadata
- CSR accesses
- exception state
- privilege mode
- cache transactions
- MMU translations
- TLB misses
- commit-stage architectural state

The preferred approach would be:
- one interface per major subsystem
- shared transaction structures
- centralized monitor aggregation

rather than directly probing deep DUT hierarchy paths.

---

## 2. Pipeline-Aware Scoreboarding

The current scoreboards are primarily localized and stage-focused.

Wally would require:
- multi-stage transaction tracking
- in-flight instruction bookkeeping
- pipeline flush awareness
- speculative execution handling
- commit-stage validation

This would likely require transitioning toward:
- transaction-based pipeline scoreboards
- reorder-aware instruction tracking
- instruction tags or sequence IDs
- architectural state synchronization

---

## 3. Architectural State Scoreboarding

The current framework validates:
- localized module behavior
- decoder correctness
- ALU correctness
- branch correctness

Wally adaptation would benefit from adding:
- architectural register-state scoreboarding
- memory-state checking
- commit-stage validation

A future extension could compare:
- DUT architectural state
- reference model architectural state

after each retired instruction.

This would significantly improve:
- end-to-end validation
- exception correctness
- pipeline recovery validation

---

## 4. Coverage Expansion for Deep Pipelines

Current coverage is instruction-centric and module-centric.

Wally would require significantly richer coverage models.

Examples:
- hazard resolution combinations
- branch predictor states
- cache coherence behavior
- exception-entry paths
- TLB refill scenarios
- privilege transitions
- pipeline flush causes
- speculation recovery paths

Cross coverage would become substantially more important.

Examples:
- branch mispredict × flush type
- cache miss × stall source
- exception × privilege mode
- forwarding path × instruction class

---

## 5. RISC-V-DV Scaling

The current framework already supports RISC-V-DV integration, which provides a strong foundation for Wally adaptation.

However, Wally would require:
- broader ISA support
- CSR instruction generation
- privileged instruction testing
- memory-intensive workloads
- branch-heavy workloads
- exception-heavy workloads

Likely changes:
- enabling full RV32IM or RV64 support
- adding constrained-random stress programs
- integrating directed corner-case sequences
- generating privilege-mode transitions
- randomized interrupt injection

---

## 6. Memory-System Verification

The current framework uses relatively simple BRAM-backed memories.

Wally adaptation would likely require:
- cache-aware memory models
- latency injection
- memory response randomization
- AXI/AHB/APB monitoring
- transaction-level memory scoreboards

The verification environment would move closer to:
- full SoC-style verification
- transaction-level monitoring
- protocol-aware scoreboards

---

## 7. UVM Migration Strategy

The safest migration path would likely be incremental.

Recommended progression:
1. Integrate Wally RTL into existing TOP_CORE flow
2. Re-establish smoke-test functionality
3. Reconnect decoder/ALU scoreboards
4. Add pipeline-state interfaces
5. Add commit-stage monitoring
6. Expand coverage infrastructure
7. Introduce architectural-state scoreboarding
8. Introduce cache/MMU verification
9. Add constrained-random stress testing

This avoids attempting a complete verification rewrite immediately.

---

# Long-Term Verification Direction

The current framework is intentionally structured as a reusable verification foundation rather than a fixed one-off testbench.

The design philosophy emphasizes:
- modular scoreboards
- reusable interfaces
- scalable coverage collection
- incremental subsystem validation
- realistic instruction execution
- compatibility with randomized program generation

This allows the framework to evolve alongside increasingly sophisticated processor implementations while preserving existing infrastructure and methodology.

---

# Notes

- `TOP_CORE` is the primary integrated verification environment.
- `project_files/` contains the active simulation infrastructure.
- Coverage collection is driven through realistic program execution.
- Scoreboards compare DUT behavior against behavioral golden models.
- RISC-V-DV integration enables scalable randomized instruction testing.
- The environment is structured to support future RTL evolution and verification expansion.
- The modular methodology is intended to support migration toward more advanced processor architectures such as Wally with incremental infrastructure growth rather than complete redesign.
