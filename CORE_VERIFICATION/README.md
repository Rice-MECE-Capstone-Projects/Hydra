# TOP_CORE UVM Verification Environment

## Overview

The primary verification environment for this project is located in the `TOP_CORE` directory.

The main SystemVerilog source files, RTL modules, UVM components, scoreboards, monitors, coverage modules, and supporting infrastructure are located inside:

```text
TOP_CORE/project_files/
```

This directory contains the files required for compilation and simulation of the full-core UVM verification environment.

---

# UVM Setup Steps

## On Windows Platform

Using ModelSim SE (System Edition):

Create a new project, skip adding files initially, and run the following commands in the ModelSim command window. The setup below assumes the UVM library version installed is `modelsim-win64-10.7-se.exe`.

After successful installation and activation, the compiled UVM library and associated `.dll` files will be available in the ModelSim installation directory.

### Create the work library

```tcl
vlib work
```

### Set UVM library path

```tcl
set UVM_HOME D:/Modelsimse/verilog_src/uvm-1.1d
```

`UVM_HOME` indicates the location of the installed UVM library.

### Set working directory

```tcl
set WORK_HOME D:/M2/UVM/UVM_example/TOP_CORE/project_files
```

`WORK_HOME` should point to the `project_files` directory containing the verification and design source files.

### Compile the design and UVM environment

```tcl
vlog +incdir+$UVM_HOME/src -L mtiAvm -L mtiOvm -L mtiUvm -L mtiUPF ^
$UVM_HOME/src/uvm_pkg.sv ^
$WORK_HOME/*.sv
```

`sv_lib` should point to the location of the `uvm_dpi` package if required.

### Run simulation

```tcl
vsim -c -sv_lib D:/Modelsimse/uvm-1.1d/win64/uvm_dpi work.top_tb -voptargs=+acc
```

After running the commands, successful compilation and simulation should produce UVM output messages, scoreboard activity, and coverage results.

---

# On Linux Platform

## Rice CLEAR Environment

The primary verification environment is located under:

```text
TOP_CORE/project_files/
```

This directory contains the relevant RTL, UVM testbench files, scoreboards, monitors, and coverage components used for the full-core verification flow.

In a QuestaSim UVM environment, first ensure the shell is set to Bash:

```bash
echo $SHELL
```

If necessary, coordinate with IT to convert initialization files from `setup*.csh` to `setup*.sh` for proper EDA license sourcing.

Because UVM-1.2 is not compatible with QuestaSim 2023.1, switch to UVM-1.1d:

```bash
export UVM_HOME=/clear/apps/siemens-2023/questa/2023.2/questasim/verilog_src/uvm-1.1d
```

Navigate to the main verification directory:

```bash
cd TOP_CORE
```

---

## Compile the Design and Testbench

Compile the contents of `project_files/` while including the UVM sources:

```bash
vlog -sv -timescale 1ns/1ns -mfcu +incdir+./project_files+$UVM_HOME/src project_files/*.sv
```

If necessary, files may also be compiled separately:

```bash
vlog -sv -timescale 1ns/1ns -mfcu +incdir+./project_files+$UVM_HOME/src project_files/design.sv
```

```bash
vlog -sv -timescale 1ns/1ns -mfcu +incdir+./project_files+$UVM_HOME/src project_files/testbench.sv
```

---

## Run Simulation

Launch the simulator with:

```bash
vsim top_module_name
```

To run without the GUI:

```bash
vsim tbench_top -do "run -all; quit"
```

To collect coverage:

```bash
vsim -c -coverage tbench_top -do "run -all; quit"
```

---

## Successful Setup Indicators

A successful setup and run should display:
- UVM initialization messages
- Driver/monitor/scoreboard activity
- “TEST PASS” or equivalent completion messages
- Coverage statistics such as:

```text
Coverage is 66.67%
```

Coverage reports and UCDB files can then be merged or analyzed using `vcover`.

```bash
vcover merge
vcover report
```

---

## Notes

- `TOP_CORE` is the main verification directory.
- `project_files/` contains the active RTL and verification infrastructure.
- The environment is structured around a modular, coverage-driven UVM methodology for RISC-V core verification.
