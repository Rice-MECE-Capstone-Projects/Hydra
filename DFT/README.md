# Scan-Based DFT and RTL-Level ATPG Framework

## Overview

This project implements a lightweight scan-based Design-for-Test (DFT) framework at the RTL level to evaluate fault coverage in a pipelined RISC-V processor. The goal is to analyze fault detectability, improve coverage using different strategies, and investigate structural testability limitations.

---

## Features

- Scan chain-based fault injection and observation
- RTL-level ATPG framework (shift / capture / shift-out)
- Fault coverage evaluation (stuck-at faults)
- Multiple coverage improvement strategies:
  - Expanded scan sampling
  - Multiple iterations
  - Random pattern generation
- Targeted debugging for low-testability structures (pipeline reg3)

---

## DFT Architecture

The framework consists of three main components:

1. **Pattern Generation**
   - Deterministic patterns (all-0, all-1, alternating)
   - Random pattern generation

2. **Scan Control**
   - Shift-in: load internal states
   - Capture: run one cycle of functional logic
   - Shift-out: observe response

3. **Fault Evaluation**
   - Compare golden vs faulty outputs
   - Determine fault detectability

---

## Methodology

1. Build a scan-based ATPG framework at RTL level  
2. Measure baseline fault coverage (52.31%)  
3. Analyze coverage across pipeline stages  
4. Identify low-testability structure (pipeline reg3)  
5. Perform targeted debugging using waveform analysis  
6. Apply coverage improvement strategies on reg0/1/2  

---

## Results

| Method                 | Coverage |
|------------------------|----------|
| Baseline               | 52.31%   |
| Expanded Sampling      | 59.33%   |
| Multiple Iterations    | 64.63%   |
| Random Patterns        | 70.73%   |

Conclusion:
- Coverage improves with pattern diversity
- Random patterns provide the largest gain
- Some faults remain undetected due to structural limitations

---

## Key Insight

Pipeline reg3 shows significantly lower testability due to functional overwrite during capture**.  
Injected faults are eliminated before they can propagate, leading to low observability.

---

## Example Waveform Analysis

Waveform analysis shows:
- Fault is successfully injected during shift-in
- During capture, functional logic overwrites register values
- No observable difference remains after capture

---

## Limitations

- RTL-level fault injection (not gate-level ATPG)
- Limited observability for certain pipeline stages
- Strong functional updates reduce fault propagation

---

## Future Work

- Apply this methodology to new designs

---

## How to Run

### Compile
```bash
vlog +define+SYNTHESIS +incdir+. *.v
