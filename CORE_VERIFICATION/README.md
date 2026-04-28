# RISC-V Core + UVM Verification Infrastructure

## Overview

This repository contains the RTL implementation of a 5-stage RV32I core and several complementary verification environments built using SystemVerilog and UVM methodologies.

The repository is organized to support:
- subsystem-level verification
- full-core execution testing
- modular scoreboarding
- functional coverage collection
- RISC-V-DV randomized instruction testing
- reusable verification infrastructure

The primary integrated verification environment is:

```text
TOP_CORE/
```

which contains the active full-core simulation infrastructure and coverage-driven verification environment.

Additional environments support isolated module validation:
- `EXECUTE_MODULE/` — Execute-stage UVM verification
- `uvm_pc_tb/` — Program counter UVM verification
- `CORE_SMOKE/` — Lightweight smoke-test infrastructure
- `CORE_FILES/` — Shared RTL implementation files

---

# Repository Structure

```text
CORE_VERIFICATION/
├── CORE_FILES/
│   └── CORE/
│
├── CORE_SMOKE/
│   └── CORE_TB/
│
├── EXECUTE_MODULE/
│
├── TOP_CORE/
│   ├── CORE/
│   ├── CORE_TB/
│   ├── coverage/
│   ├── programs/
│   ├── project_files/
│   └── COVERAGE_SCOREBOARD_PROJECT.mpf
│
├── uvm_pc_tb/
│
└── verification/
```

---

# Environment Descriptions

## TOP_CORE — Full RISC-V Core Verification Environment

`TOP_CORE` contains the primary integrated verification infrastructure for the RV32I processor core.

This environment supports:
- execution of complete RISC-V programs
- functional coverage collection
- decoder scoreboarding
- ALU scoreboarding
- branch verification
- BRAM-backed instruction/data memories
- RISC-V-DV generated instruction streams

The active simulation infrastructure is located in:

```text
TOP_CORE/project_files/
```

### Main Verification Components

| File | Purpose |
|---|---|
| `tb_smoke_riscv32i.sv` | Main full-core simulation testbench |
| `riscv32i.v` | Top-level DUT |
| `core_coverage.sv` | Functional coverage collection |
| `decoder_scoreboard.sv` | Decoder scoreboard |
| `alu_scoreboard.sv` | ALU scoreboard |
| `branch_scoreboard.sv` | Branch verification scoreboard |
| `golden_alu_pkg.sv` | Golden ALU reference model |
| `golden_decocder.sv` | Golden decoder reference model |
| `core_if.sv` | Shared verification interface |
| `core_smoke_test.sv` | Smoke-test logic |
| `bram_ins.sv` | Instruction memory BRAM |
| `bram_mem.sv` | Data memory BRAM |
| `ins_mem_model.sv` | Behavioral instruction memory |
| `program.hex` | Active instruction image |

### Coverage Collection

Coverage is implemented in:

```text
project_files/core_coverage.sv
```

Current coverage infrastructure tracks:
- decoder activity
- ALU operations
- branch behavior
- instruction diversity

Coverage databases and reports are stored in:

```text
TOP_CORE/coverage/
```

### Program Execution

Programs are loaded through:

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

## EXECUTE_MODULE — Execute Stage UVM Environment

`EXECUTE_MODULE` provides a dedicated UVM verification environment for the execute stage of the RV32I pipeline.

This environment validates:
- ALU operations
- branch comparison logic
- operand forwarding behavior
- randomized execute-stage stimulus
- scoreboard correctness

### Main Components

| File | Purpose |
|---|---|
| `design.sv` | Execute-stage DUT |
| `execute_if.sv` | UVM interface |
| `exec_driver.sv` | Driver |
| `exec_monitor.sv` | Monitor |
| `exec_scoreboard.sv` | Execute-stage scoreboard |
| `pkg_tx.sv` | Transaction definitions |
| `env.sv` | UVM environment |
| `my_test.sv` | Example randomized test |

### Functionality

This environment validates:
1. Arithmetic operations
2. Logical operations
3. Shift operations
4. Set-less-than operations
5. Branch compare logic
6. Operand forwarding behavior
7. UVM driver/monitor/scoreboard infrastructure

This stage-level environment served as the prototype for the broader modular UVM methodology used throughout the repository.

---

## uvm_pc_tb — Program Counter UVM Environment

`uvm_pc_tb` contains a UVM environment specifically targeting the PC module.

### Main Components

| File | Purpose |
|---|---|
| `pc.v` | DUT |
| `pc_if.sv` | Interface |
| `pc_driver.sv` | Driver |
| `pc_env.sv` | UVM environment |
| `pc_pkg.sv` | Package definitions |
| `pc_seq.sv` | Sequence generation |
| `pc_test.sv` | UVM tests |
| `tb_top.sv` | Simulation top |

### Functionality

This environment validates:
1. Reset behavior
2. Sequential PC increments
3. Redirect handling
4. Branch/jump target behavior
5. PC control functionality

---

## CORE_FILES — Shared RTL Implementation

The RTL implementation of the RV32I core is stored in:

```text
CORE_FILES/CORE/
```

Key RTL modules include:
- `pc.v`
- `decode.v`
- `excute.v`
- `hazard.v`
- `branch_prediction.v`
- `regfile.v`
- `dataMem.v`
- `ins_mem.v`
- `riscv32i.v`

These files are reused across multiple verification environments.

---

## CORE_SMOKE — Lightweight Smoke-Test Infrastructure

`CORE_SMOKE` contains lightweight full-core smoke-test infrastructure used for early bring-up and decoder validation.

Main files include:
- `core_if.sv`
- `core_smoke_test_pkg.sv`
- `core_smoke_test.sv`
- `golden_decocder.sv`
- `tb_decoder_scoreboard.sv`

This environment provides simplified scoreboard-driven validation before transitioning into the more feature-complete `TOP_CORE` environment.

---

# General Setup Notes

## Work Library Initialization

If the project is new on the machine and Questa reports:

```text
library work not found
```

run once in the Transcript:

```tcl
vlib work
vmap work work
```

then recompile.

---

# Linux / Rice CLEAR Environment Setup

Verify Bash shell:

```bash
echo $SHELL
```

Use UVM-1.1d:

```bash
export UVM_HOME=/clear/apps/siemens-2023/questa/2023.2/questasim/verilog_src/uvm-1.1d
```

---

# Running TOP_CORE

## Open the Project

```bash
cd TOP_CORE
vsim -gui COVERAGE_SCOREBOARD_PROJECT.mpf
```

---

## Compile All Files

GUI:
```text
Compile → Compile All
```

Command-line:
```bash
vsim -c -do "project open COVERAGE_SCOREBOARD_PROJECT.mpf; project compileall; quit"
```

---

## Run the Full-Core Smoke Test

```bash
vsim work.tb_smoke_riscv32i
run -all
```

This test:
- loads `program.hex`
- instantiates the full RV32I core
- executes the instruction stream
- collects coverage
- drives scoreboard comparisons

Expected transcript output includes:
- smoke-test startup messages
- scoreboard activity
- end-of-test assertions
- coverage statistics

---

# Coverage Collection

Run with coverage enabled:

```bash
vsim -c -coverage work.tb_smoke_riscv32i -do "run -all; quit"
```

Generate coverage reports:

```bash
vcover report core_cov.ucdb
```

Merge multiple runs:

```bash
vcover merge merged_cov.ucdb *.ucdb
```

Generate merged report:

```bash
vcover report merged_cov.ucdb > merged_coverage.txt
```

---

# Running EXECUTE_MODULE

Open the project:

```bash
cd EXECUTE_MODULE
vsim -gui EXECUTE.mpf
```

Compile:
```text
Compile → Compile All
```

Run:
```bash
vsim work.tb_top
run -all
```

---

# Running uvm_pc_tb

Open the project:

```bash
cd uvm_pc_tb
vsim -gui QUESTA_prj.mpf
```

Compile:
```text
Compile → Compile All
```

Run:
```bash
vsim work.tb_top
run -all
```

---

# RISC-V-DV Integration and Program Generation

This repository supports integration with Google RISC-V-DV for randomized instruction generation.

Programs generated with RISC-V-DV can be compiled and executed directly in `TOP_CORE`.

---

# Installing RISC-V-DV

Clone:
```bash
git clone https://github.com/google/riscv-dv.git
cd riscv-dv
```

Install dependencies:
```bash
pip install -r requirements.txt
```

Install toolchain:
```bash
sudo apt install gcc-riscv64-unknown-elf
```

Verify:
```bash
riscv32-unknown-elf-gcc --version
python3 run.py --help
```

---

# Generating Randomized Programs

Example RV32I generation:

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

Generated assembly:
```text
out_0.S
```

---

# Compiling Assembly → ELF

```bash
riscv32-unknown-elf-gcc \
    -march=rv32i \
    -mabi=ilp32 \
    -nostdlib \
    -T linker.ld \
    out_0.S \
    -o out_0.elf
```

Example linker script:

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

```bash
riscv32-unknown-elf-objcopy -O verilog out_0.elf out_0.hex
```

Example HEX format:

```text
00b50533
403505b3
00c58633
...
```

---

# Loading Programs Into TOP_CORE

Copy generated HEX files into:

```text
TOP_CORE/program.hex
```

Example:

```bash
cp out_0.hex TOP_CORE/program.hex
```

Then rerun simulation.

---

# Extending the Verification Environment

The repository is intentionally modular and designed for future expansion.

Possible extensions include:
- additional scoreboards
- hazard verification
- forwarding verification
- cache verification
- CSR validation
- exception handling
- pipeline flush verification
- branch prediction verification
- architectural reference models
- cross-coverage refinement
- constrained-random UVM sequences

New modules can generally be integrated by:
1. creating interfaces
2. adding monitors
3. implementing golden behavioral models
4. attaching scoreboards
5. extending covergroups

The existing structure is intended to provide a reusable foundation for progressively more advanced processor verification workflows.
