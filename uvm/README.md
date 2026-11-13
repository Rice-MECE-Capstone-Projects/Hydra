# HYDRA UVM Verification

This directory contains the UVM testbenches for HYDRA's memory-mapped registers (MMR), Mode B transpose, Mode C quantization, and integrated CPU-to-scratchpad operation.

## Directory guide

- `agent/`, `driver/`, `monitor/`, `sequence/`, `test/`, and related directories: CPU AHB/MMR unit verification.
- `uvm_transform/`: Mode B and Mode C unit verification, including a RAM responder and a reference scoreboard.
- `uvm_integration/`: top-level tests, functional coverage, and the regression script.
- [`../doc/Test_Plan.md`](../doc/Test_Plan.md): scenarios, expected results, and coverage details.
- [`../doc/proj.log`](../doc/proj.log): project log.

## Run the integration regression

Use QuestaSim 2023.2 with the HYDRA RTL, interfaces, `hydra_uvm_pkg`, and `transform_pkg` already compiled into the `work` library. From `uvm/uvm_integration/sim` run:

```bash
bash run_integration_cov.sh
```

The script compiles the integration package and testbench, runs directed and seeded random tests, merges the coverage databases, and writes `functional_coverage_report.txt` and `code_coverage_report.txt` in that `sim` directory. Per-run logs and databases are saved in a timestamped `cov_*` directory.

## Results

The documented unit and integration tests passed. The merged integration regression reached **100% functional configuration coverage** and **94.49% filtered RTL code coverage**. See the test plan for the coverage scope and remaining uncovered paths.
