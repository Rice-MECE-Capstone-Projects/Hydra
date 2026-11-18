#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -d work ]]; then
    vlib work
fi

vlog ../../../src/hydra/hydra_pkg.sv
vlog ../../interface/cpu_ahb_if.sv
vlog ../../uvm_transform/interface/transform_ctrl_if.sv
vlog ../../uvm_transform/interface/transform_ram_if.sv
vlog ../../uvm_transform/interface/transform_scratch_if.sv

vlog ../../../src/hydra/hydra_arbiter.sv
vlog ../../../src/hydra/hydra_mmr.sv
vlog ../../../src/hydra/hydra_scratchpad.sv
vlog ../../../src/hydra/hydra_transform.sv
vlog ../../../src/hydra/hydra_top.sv

vlog +incdir+../../package ../../package/hydra_uvm_pkg.sv
vlog +incdir+../../uvm_transform/package ../../uvm_transform/package/transform_pkg.sv
vlog +incdir+../package ../package/hydra_integration_pkg.sv
vlog ../../hydra_top_tb.sv
