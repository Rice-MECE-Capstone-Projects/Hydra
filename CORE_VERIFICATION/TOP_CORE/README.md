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

The environment is intentionally modular and designed for extension.

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

New modules can typically be integrated by:
1. adding interfaces
2. creating monitors
3. implementing behavioral golden models
4. attaching scoreboards
5. extending coverage groups

The current structure provides a reusable foundation for progressively more advanced processor verification workflows.

---

# Notes

- `TOP_CORE` is the primary integrated verification environment.
- `project_files/` contains the active simulation infrastructure.
- Coverage collection is driven through realistic program execution.
- Scoreboards compare DUT behavior against behavioral golden models.
- RISC-V-DV integration enables scalable randomized instruction testing.
- The environment is structured to support future RTL evolution and verification expansion.
