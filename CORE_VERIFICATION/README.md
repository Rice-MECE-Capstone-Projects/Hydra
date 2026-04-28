# RISC-V Core + UVM Verification Infrastructure [SEE TOP_CORE FOR MORE DETAILS]

## Overview

This repository contains the RTL implementation of a 5-stage RV32I core and several complementary verification environments built using SystemVerilog and UVM methodologies.

The repository supports:
- subsystem-level verification
- modular UVM environments
- scoreboard-driven checking
- functional coverage collection
- full-core execution testing
- randomized instruction generation using RISC-V-DV

The primary integrated verification environment is:

```text
TOP_CORE/
```

which contains the active full-core simulation infrastructure and coverage-driven verification environment.

Additional environments support isolated module verification:
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

# TOP_CORE — Full RISC-V Core Verification Environment

## Overview

`TOP_CORE` contains the primary integrated verification infrastructure for the RV32I processor core.

This environment supports:
- execution of complete RISC-V programs
- decoder scoreboarding
- ALU scoreboarding
- branch verification
- functional coverage collection
- BRAM-backed instruction/data memories
- RISC-V-DV generated instruction streams

The active simulation infrastructure is located in:

```text
TOP_CORE/project_files/
```

---

## Main Verification Components

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

---

## Functional Coverage

Coverage is implemented in:

```text
project_files/core_coverage.sv
```

Coverage currently tracks:
- decoder activity
- ALU operation usage
- branch behavior
- instruction diversity

Coverage databases and reports are stored in:

```text
TOP_CORE/coverage/
```

Example files:
- `core_cov.ucdb`
- `merged_cov.ucdb`
- `core_cov_report.txt`
- `merged_coverage.txt`

---

## Program Execution

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

# How to Run TOP_CORE

## 1. Open the Project Structure

### Option A — From the Terminal

```bash
cd TOP_CORE
vsim -gui COVERAGE_SCOREBOARD_PROJECT.mpf
```

This opens the preconfigured Questa project with all required files already loaded.

---

### Option B — From the GUI

1. Start Questa/ModelSim
2. Select:

```text
File → Open → Project…
```

3. Navigate to:

```text
TOP_CORE/
```

4. Open:

```text
COVERAGE_SCOREBOARD_PROJECT.mpf
```

---

## 2. Compile the Project

### GUI Method

```text
Compile → Compile All
```

---

### Command-Line Method

```bash
vsim -c -do "project open COVERAGE_SCOREBOARD_PROJECT.mpf; project compileall; quit"
```

Watch the Transcript window and ensure:
- 0 compile errors
- all files compile successfully

If files are modified later (especially `program.hex`), recompile before rerunning simulation.

---

## 3. Run the Full-Core Smoke Test

The primary simulation top is:

```text
tb_smoke_riscv32i.sv
```

---

### GUI Method (not recommended)

1. Locate:

```text
tb_smoke_riscv32i.sv
```

in the Project window.

2. Right-click the module:
```text
tb_smoke_riscv32i
```

3. Select:
```text
Simulate
```

4. In the Transcript:
```tcl
run -all
```

---

### Recommended Command-Line Method

Inside the Transcript:

```tcl
vsim work.tb_smoke_riscv32i
run -all
```

---

## Expected Smoke-Test Behavior

Simulation output should show:
- startup banner
- scoreboard activity
- instruction execution
- end-of-test assertion
- coverage statistics

The smoke test:
- loads `program.hex`
- instantiates the RV32I core
- executes the program
- collects coverage
- validates behavior against scoreboards

A successful test typically confirms:
- PC progression
- decode correctness
- ALU correctness
- successful program completion

---

## Running With Coverage Enabled

```tcl
vsim -c -coverage work.tb_smoke_riscv32i -do "run -all; quit"
```

---

## Generating Coverage Reports

Generate report:

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

## Running the Decoder Scoreboard Test

The decoder scoreboard environment uses:
- `decoder_scoreboard.sv`
- `golden_decocder.sv`
- `core_smoke_test_pkg.sv`
- `core_smoke_test.sv`
- `core_if.sv`

Simulation top:
```text
tb_decoder_scoreboard.sv
```

---

### GUI Method

1. Locate:
```text
tb_decoder_scoreboard.sv
```

2. Right-click:
```text
tb_decoder_scoreboard
```

3. Select:
```text
Simulate
```

4. Run:
```tcl
run -all
```

---

### Recommended Command-Line Method

```tcl
vsim work.tb_decoder_scoreboard
run -all
```

This test:
- instantiates the full core
- monitors decoder outputs
- compares DUT behavior against `golden_decocder.sv`
- reports mismatches through the scoreboard

---

## Typical TOP_CORE Workflow

Compile after edits:

```text
Compile → Compile All
```

Run smoke test:

```tcl
vsim -voptargs=+acc work.tb_smoke_riscv32i
run -all
```

Run decoder scoreboard:

```tcl
vsim -voptargs=+acc work.tb_decoder_scoreboard
run -all
```

---

# EXECUTE_MODULE — Execute Stage UVM Environment

## Overview

`EXECUTE_MODULE` provides a dedicated UVM verification environment for the execute stage.

This environment validates:
- ALU operations
- branch comparison logic
- forwarding behavior
- randomized execute-stage stimulus
- scoreboard correctness

---

## Main Components

| File | Purpose |
|---|---|
| `design.sv` | Execute-stage DUT |
| `execute_if.sv` | UVM interface |
| `exec_driver.sv` | Driver |
| `exec_monitor.sv` | Monitor |
| `exec_scoreboard.sv` | Scoreboard |
| `pkg_tx.sv` | Transaction definitions |
| `env.sv` | UVM environment |
| `my_test.sv` | Example randomized test |

---

# How to Run EXECUTE_MODULE

## 1. Open the Execute Project

```bash
cd EXECUTE_MODULE
vsim -gui EXECUTE.mpf
```

---

## 2. Compile All Files

### GUI Method

```text
Compile → Compile All
```

---

### Transcript Method

```tcl
project compileall
```

---

## 3. Load the Simulation Top

Simulation top:

```text
tb_top
```

---

### GUI Method

```text
Simulate → Simulate…
```

Select:
```text
work.tb_top
```

---

### Command-Line Method

```tcl
vsim work.tb_top
run -all
```

---

# uvm_pc_tb — Program Counter UVM Environment

## Overview

`uvm_pc_tb` contains a UVM environment specifically targeting the PC module.

This environment validates:
- reset behavior
- sequential PC increments
- redirect handling
- branch/jump target behavior

---

## Main Components

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

---

# How to Run uvm_pc_tb

## 1. Open the Project

```bash
cd uvm_pc_tb
vsim -gui QUESTA_prj.mpf
```

---

## 2. Compile All Files

### GUI Method

```text
Compile → Compile All
```

---

## 3. Load the Simulation Top

Simulation top:

```text
tb_top
```

---

### GUI Method

```text
Simulate → Simulate → work.tb_top
```

---

### Command-Line Method

```tcl
vsim work.tb_top
run -all
```

---

# CORE_FILES — Shared RTL Implementation

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

These modules are reused across multiple verification environments.

---

# CORE_SMOKE — Lightweight Smoke-Test Infrastructure

`CORE_SMOKE` contains lightweight scoreboard and smoke-test infrastructure used during early bring-up.

Main files include:
- `core_if.sv`
- `core_smoke_test_pkg.sv`
- `core_smoke_test.sv`
- `golden_decocder.sv`
- `tb_decoder_scoreboard.sv`

This environment provides simplified decoder validation before transitioning into the more feature-complete `TOP_CORE` environment.

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
