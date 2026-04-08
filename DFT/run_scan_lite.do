vlib work
vmap work work

vlog params.vh
vlog pc.v
vlog regfile.v
vlog decode.v
vlog excute.v
vlog hazard.v
vlog branch_prediction.v
vlog dataMem.v
vlog ins_mem.v
vlog debug.v
vlog riscv32i.v
vlog atpg_scan_lite.v

vsim -voptargs=+acc -t 1ps work.atpg

run -all
quit -f
