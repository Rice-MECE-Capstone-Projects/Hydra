# RISC-V Core + UVM Verification Infrastructure [SEE TOP_CORE FOR MORE INFO]

## Overview

This repository contains the RTL implementation of a 5-stage RV32I RISC-V processor core along with multiple complementary verification environments built using SystemVerilog and UVM methodologies.

The project is structured to support:
- Full-core smoke testing
- Coverage-driven verification
- Modular subsystem validation
- Decoder and ALU scoreboarding
- Program-counter verification
- RISC-V-DV integration for randomized instruction generation

The primary verification environment is located in:

```text
TOP_CORE/
```

with the active full-core simulation infrastructure and verification files located in:

```text
TOP_CORE/project_files/
```

This repository supports both subsystem-level UVM verification and integrated full-core execution testing.

---

# Repository Structure

```text
CORE_VERIFICATION/
├── CORE_FILES/
│   └── CORE/
│       ├── branch_prediction.v
│       ├── dataMem.v
│       ├── decode.v
│       ├── excute.v
│       ├── hazard.v
│       ├── ins_mem.v
│       ├── params.vh
│       ├── pc.v
│       ├── regfile.v
│       ├── riscv32i.v
│       └── riscv32iTB.v
│
├── CORE_SMOKE/
│   └── CORE_TB/
│       ├── core_if.sv
│       ├── core_smoke_test_pkg.sv
│       ├── core_smoke_test.sv
│       ├── golden_decocder.sv
│       ├── tb_decoder_scoreboard.sv
│       └── tb_top.sv
│
├── EXECUTE_MODULE/
│   ├── design.sv
│   ├── execute_if.sv
│   ├── exec_driver.sv
│   ├── exec_monitor.sv
│   ├── exec_scoreboard.sv
│   ├── env.sv
│   ├── my_test.sv
│   ├── pkg_tx.sv
│   └── EXECUTE.mpf
│
├── TOP_CORE/
│   ├── CORE/
│   ├── CORE_TB/
│   ├── coverage/
│   ├── programs/
│   ├── project_files/
│   ├── program.hex
│   └── COVERAGE_SCOREBOARD_PROJECT.mpf
│
├── uvm_pc_tb/
│   ├── pc_driver.sv
│   ├── pc_env.sv
│   ├── pc_if.sv
│   ├── pc_pkg.sv
│   ├── pc_seq.sv
│   ├── pc_test.sv
│   ├── pc_txn.sv
│   ├── pc.v
│   ├── tb_top.sv
│   └── QUESTA_prj.mpf
│
└── verification/
    └── TOP_CORE/
```

---

# Major Verification Environments

## TOP_CORE — Full-Core Verification Environment

`TOP_CORE` is the primary integrated verification environment for the RV32I core.

This environment supports:
- Full-core execution testing
- Functional coverage collection
- Decoder scoreboarding
- ALU scoreboarding
- Branch verification
- BRAM-backed instruction/data memories
- RISC-V-DV generated program execution

The active simulation and verification infrastructure is located in:

```text
TOP_CORE/project_files/
```

### Key Files

| File | Purpose |
|---|---|
| `tb_smoke_riscv32i.sv` | Main full-core smoke testbench |
| `riscv32i.v` | Top-level DUT |
| `core_coverage.sv` | Functional coverage collection |
| `decoder_scoreboard.sv` | Decode-stage checking |
| `alu_scoreboard.sv` | ALU checking |
| `branch_scoreboard.sv` | Branch verification |
| `golden_alu_pkg.sv` | Golden ALU reference model |
| `golden_decocder.sv` | Golden decoder reference model |
| `bram_ins.sv` | Instruction memory BRAM |
| `bram_mem.sv` | Data memory BRAM |
| `ins_mem_model.sv` | Behavioral instruction memory |
| `program.hex` | Instruction image loaded at runtime |

### Coverage Infrastructure

Coverage artifacts are stored in:

```text
TOP_CORE/coverage/
```

This includes:
- `.ucdb` coverage databases
- merged coverage reports
- text-based coverage summaries

### Program Execution

Programs are loaded through:

```systemverilog
$readmemh("program.hex", mem_array);
```

Example program images are stored in:

```text
TOP_CORE/programs/
```

---

## EXECUTE_MODULE — Execute Stage UVM Environment

`EXECUTE_MODULE` contains a dedicated UVM environment for isolated execute-stage verification.

This environment validates:
- ALU operations
- comparison logic
- forwarding behavior
- randomized execute-stage stimulus
- scoreboard correctness

### Key Files

| File | Purpose |
|---|---|
| `design.sv` | Execute-stage DUT |
| `execute_if.sv` | UVM interface |
| `exec_driver.sv` | Stimulus driver |
| `exec_monitor.sv` | DUT monitor |
| `exec_scoreboard.sv` | ALU scoreboard |
| `pkg_tx.sv` | Transaction definitions |
| `env.sv` | UVM environment |
| `my_test.sv` | Example randomized test |

---

## uvm_pc_tb — Program Counter UVM Environment

`uvm_pc_tb` contains a UVM verification environment for the program counter module.

This environment validates:
- reset behavior
- sequential PC increments
- redirect/jump handling
- PC control behavior

### Key Files

| File | Purpose |
|---|---|
| `pc.v` | DUT |
| `pc_if.sv` | PC interface |
| `pc_driver.sv` | Driver |
| `pc_env.sv` | UVM environment |
| `pc_pkg.sv` | Package definitions |
| `pc_seq.sv` | Sequence generation |
| `pc_test.sv` | UVM tests |
| `tb_top.sv` | Simulation top |

---

# RTL Core Files

The RTL implementation of the RV32I processor core is located in:

```text
CORE_FILES/CORE/
```

Core modules include:
- `pc.v`
- `decode.v`
- `excute.v`
- `hazard.v`
- `branch_prediction.v`
- `regfile.v`
- `dataMem.v`
- `ins_mem.v`
- `riscv32i.v`

These modules are reused throughout the verification environments.

---

# Smoke Test Infrastructure

Basic smoke-test and scoreboard infrastructure is located in:

```text
CORE_SMOKE/CORE_TB/
```

This includes:
- interfaces
- decoder scoreboards
- basic full-core validation infrastructure
- early bring-up testing utilities

---

# General Simulation Setup

## Linux / Rice CLEAR Environment

Ensure Bash is active:

```bash
echo $SHELL
```

Use UVM-1.1d:

```bash
export UVM_HOME=/clear/apps/siemens-2023/questa/2023.2/questasim/verilog_src/uvm-1.1d
```

---

# TOP_CORE Compilation Example

Navigate into the environment:

```bash
cd TOP_CORE
```

Compile:

```bash
vlog -sv -timescale 1ns/1ns -mfcu +incdir+./project_files+$UVM_HOME/src project_files/*.sv
```

Run:

```bash
vsim work.tb_smoke_riscv32i
run -all
```

Coverage run:

```bash
vsim -c -coverage work.tb_smoke_riscv32i -do "run -all; quit"
```

---

# Coverage Collection

Coverage reports can be generated using:

```bash
vcover merge
vcover report
```

Coverage databases are stored as:

```text
*.ucdb
```

inside:

```text
TOP_CORE/coverage/
```

---

# RISC-V-DV Integration

This project supports integration with Google RISC-V-DV for randomized instruction-stream generation.

Typical workflow:
1. Generate randomized RV32I assembly
2. Compile to ELF
3. Convert ELF → Verilog HEX
4. Load generated `.hex` into `TOP_CORE/program.hex`
5. Run full-core verification

---

# Notes

- `TOP_CORE` is the primary integrated verification environment.
- `project_files/` contains the active simulation infrastructure and scoreboards.
- The verification flow is modular and designed to support incremental extension as the RTL evolves.
- Multiple environments exist to support isolated subsystem validation before full-core integration.
