#!/usr/bin/env bash
set -u

run_dir="cov_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$run_dir"
ucdbs=()
fail_count=0

# Recompile the integration package and top testbench.
vlog +incdir+../package ../package/hydra_integration_pkg.sv \
    > "$run_dir/compile.log" 2>&1 || {
    cat "$run_dir/compile.log"
    exit 1
}

vlog ../../hydra_top_tb.sv >> "$run_dir/compile.log" 2>&1 || {
    cat "$run_dir/compile.log"
    exit 1
}

run_case() {
    local label="$1"
    local test_name="$2"
    local seed="$3"
    shift 3

    local log="$run_dir/$label.log"
    local ucdb="$run_dir/$label.ucdb"
    local rc=0

    echo "Running $label"

    vsim -c -coverage \
        -voptargs="+acc +cover=sbf+/hydra_top_tb/dut." \
        -sv_seed "$seed" work.hydra_top_tb \
        "+UVM_TESTNAME=$test_name" "$@" \
        -l "$log" \
        -do "coverage save -onexit -testname $label $ucdb; run -all; quit -f" \
        > "$run_dir/$label.console" 2>&1 || rc=$?

    if (( rc != 0 )) || [[ ! -s "$ucdb" ]] || \
       ! grep -q 'UVM Report Summary' "$log" || \
       ! grep -q '\[COV_SAMPLE\]' "$log" || \
       grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' "$log"
    then
        echo "FAIL: $label — see $log and $run_dir/$label.console"
        fail_count=$((fail_count + 1))
    else
        echo "PASS: $label"
        ucdbs+=("$ucdb")
    fi
}

run_case I01_c_basic       hydra_mode_c_basic_test           1
run_case I02_b_basic       hydra_mode_b_basic_test           1
run_case I03_c_shift_round hydra_mode_c_shift_round_test     1
run_case I04_c_signed      hydra_mode_c_signed_unsigned_test 1 +SIGNED_OUT=1
run_case I04_c_unsigned    hydra_mode_c_signed_unsigned_test 1 +SIGNED_OUT=0
run_case I05_b_two_blocks  hydra_mode_b_two_block_test       1
run_case I06_c_invalid     hydra_invalid_length_test        1 +INVALID_MODE=3
run_case I06_b_invalid     hydra_invalid_length_test        1 +INVALID_MODE=2
run_case I07_c_to_b        hydra_mode_c_to_b_test            1

run_case I08_c_seed_101    hydra_mode_c_random_test 101
run_case I08_c_seed_202    hydra_mode_c_random_test 202
run_case I08_c_seed_303    hydra_mode_c_random_test 303

# Close the remaining Mode C arithmetic cross bins.
run_case I08_c_u_r0_s1     hydra_mode_c_random_test 404 +C_SIGNED=0 +C_ROUND=0 +C_SHIFT=1
run_case I08_c_u_r1_s1     hydra_mode_c_random_test 404 +C_SIGNED=0 +C_ROUND=1 +C_SHIFT=1
run_case I08_c_u_r1_s0     hydra_mode_c_random_test 404 +C_SIGNED=0 +C_ROUND=1 +C_SHIFT=0
run_case I08_c_s_r1_s0     hydra_mode_c_random_test 404 +C_SIGNED=1 +C_ROUND=1 +C_SHIFT=0
run_case I08_c_length132    hydra_mode_c_random_test 404 +C_LENGTH=132 +C_SHIFT=0 +C_ROUND=0 +C_SIGNED=1

run_case I09_b_seed_101    hydra_mode_b_random_test 101
run_case I09_b_seed_202    hydra_mode_b_random_test 202
run_case I09_b_seed_303    hydra_mode_b_random_test 303
run_case I10_b_contention hydra_mode_b_basic_test 1 +CPU_CONTENTION
run_case I11_c_ram_wait hydra_mode_c_basic_test 1 +RAM_WAIT


if (( fail_count != 0 )); then
    echo "$fail_count run(s) failed. Coverage was not merged."
    exit 1
fi

vcover_bin=/clear/apps/siemens-2023/questa/2023.2/questasim/bin/vcover

"$vcover_bin" merge -64 "$run_dir/merged.ucdb" "${ucdbs[@]}" || exit 1

# Report configuration functional coverage.
"$vcover_bin" report -64 -cvg -details \
    -output "$run_dir/functional_coverage_report.txt" \
    "$run_dir/merged.ucdb" || exit 1

# Report RTL code coverage within the DUT hierarchy.
"$vcover_bin" report -64 -code sbf -details \
    -instance=/hydra_top_tb/dut. \
    -output "$run_dir/code_coverage_report.txt" \
    "$run_dir/merged.ucdb" || exit 1

cp "$run_dir/functional_coverage_report.txt" \
   "functional_coverage_report_$(basename "$run_dir").txt"
cp "$run_dir/functional_coverage_report.txt" functional_coverage_report.txt

cp "$run_dir/code_coverage_report.txt" \
   "code_coverage_report_$(basename "$run_dir").txt"
cp "$run_dir/code_coverage_report.txt" code_coverage_report.txt

echo "All runs passed."
echo "Functional coverage report: functional_coverage_report.txt"
echo "Code coverage report: code_coverage_report.txt"