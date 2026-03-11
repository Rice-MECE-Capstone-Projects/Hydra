# run_scan.do — ATPG 真正扫描流程
# 用法：vsim -do run_scan.do -batch < /dev/null > atpg_scan_out.txt 2>&1

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
vlog atpg_scan.v

vsim -voptargs=+acc -t 1ps work.atpg_scan

run -all
quit -f
