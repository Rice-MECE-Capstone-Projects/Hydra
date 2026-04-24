# Scan-Based DFT and RTL-Level ATPG Framework

## Overview

This project implements a lightweight scan-based Design-for-Testability (DFT) framework at the RTL level for a pipelined RISC-V processor. The goal is to evaluate stuck-at fault coverage, improve test effectiveness through multiple ATPG strategies, and analyze structural testability limitations in different pipeline stages.

The work focuses on scan-chain controllability, observability, fault injection, response comparison, and coverage improvement.

---

## Features

- RTL-level scan chain implementation
- Scan shift / capture / shift-out testing flow
- Stuck-at fault coverage evaluation
- Multiple ATPG optimization strategies
- Pipeline stage-level testability analysis
- Root-cause debugging for low-coverage structures
- QuestaSim simulation flow

---

## DFT Architecture

The framework consists of the following components:

1. **Pattern Generator**
   - Deterministic patterns
   - Random patterns

2. **Scan Controller**
   - Shift-in test states
   - Capture functional response
   - Shift-out scan results

3. **Fault Comparator**
   - Golden vs faulty response comparison

4. **Coverage Evaluation**
   - Fault detection statistics
   - Coverage reporting

---

## Scan Chain Structure

The processor pipeline registers are connected into one scan chain:

```text
Scan In -> pipeReg0 -> pipeReg1 -> pipeReg2 -> pipeReg3 -> Scan Out
```

Approximate chain length: **1604 bits**

---

## Methodology

1. Build RTL-level scan-based ATPG framework
2. Measure baseline fault coverage
3. Analyze coverage across pipeline stages
4. Identify low-testability stage: pipeReg3
5. Debug pipeReg3 using waveform analysis
6. Improve coverage on pipeReg0, pipeReg1, and pipeReg2 using multiple strategies

---

## Results

| Method | Coverage |
|---|---:|
| Baseline | 52.31% |
| Expanded Sampling | 59.33% |
| Multiple Iterations | 64.63% |
| Random Patterns | 70.73% |

### Key Observation

Pipeline reg3 showed significantly lower fault coverage than earlier stages.

Waveform debugging revealed that faults injected into pipeReg3 are overwritten during the capture phase:

```verilog
pipeReg3 <= pipeReg3_wire;
```

As a result, many injected faults disappear before becoming observable.

---

## How to Run

This project was verified using **QuestaSim 2023.2**.

### 1. Create Simulation Library

```bash
vlib work
```

### 2. Compile All RTL and Testbench Files

```bash
vlog +define+SYNTHESIS +incdir+. *.v
```

This compiles processor RTL, scan logic, and ATPG testbenches.

### 3. Run Baseline Coverage Test

```bash
vsim -c atpg_scan_lite -do "run -all; quit"
```

### 4. Run Expanded Sampling Test

```bash
vsim -c atpg_scan_lite_expand_sampling -do "run -all; quit"
```

### 5. Run Multiple Iteration Test

```bash
vsim -c atpg_scan_lite_iterations -do "run -all; quit"
```

### 6. Run Random Pattern Test

```bash
vsim -c atpg_scan_lite_random -do "run -all; quit"
```

### 7. Run Pipeline Reg3 Debug Test

```bash
vsim atpg_pr3_debug_fields_tb
run -all
```

### 8. Open GUI Waveform Mode

```bash
vsim atpg_pr3_debug_fields_tb
add wave *
run -all
```

---

## Expected Output

- Baseline coverage near 52%
- Improved coverage up to 70%
- Waveform evidence showing pipeReg3 overwrite during capture

---

## Limitations

- Certain stages have limited observability
- Functional overwrite reduces fault propagation

---

## Future Work

- Apply this methodology to new processor designs
