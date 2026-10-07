//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra.c
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: C code to benchmark HYDRA's integration in Wally.
//
// A component of the HYDRA project.
// https://github.com/Rice-MECE-Capstone-Projects/Hydra
//
// Copyright (C) 2025-26 Rice University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
//////////////////////////////////////////////////////////////////////////////////////////////////

// Please note (from wally/examples/C/hello/hello.c):
    // The Wally team has modified the Berkeley syscalls.c (in wally/examples/C/common)
    // to printf via UART rather than the syscall interface. It assumes the 
    // PC16550-compatible UART is at the default SiFive address of 0x10000000.
    // Note that there seem to be some discrepancies between the UART and Spike
    // such that using \n\r for new lines works best.

// Compile with:
//      make [TARGET=...] [OFLAG=...] [BFLAG=...] [SFLAG=...]
//          Defaults:
//              TARGET=hydra
//              OFLAG=-O3 -funroll-loops
//              BFLAG=MAX_BLOCKS
//              SFLAG=WICD
//          Valid BFLAG values: [1, MAX_BLOCKS]
//          Valid SFLAG values: CICD, WICD, WIWD
// Simulate with: wsim rv32gc --sim questa --elf hydra

#include "hydra.h"


// -------------------------Benchmark configuration-------------------------
// NOTE: Avoid sweeping MAX_BLOCKS, because it changes the distance between
//       src and dst in the cache. This changes their cache-set mapping and
//       can cause write-back fluctuations that distort the measured speedup.
//       Instead, sweep BENCH_BLOCKS using the provided Makefile.

#define MIN_BLOCKS       1
#define MAX_BLOCKS       64 // default
#define MAX_LEN          (NUM_ELEMS * MAX_BLOCKS)
#define POISON           0xDEADBEEFu
#define SEED             0x1234ABCDu

#ifndef BENCH_BLOCKS
    #define BENCH_BLOCKS MAX_BLOCKS
#endif
#if (BENCH_BLOCKS < 1) || (BENCH_BLOCKS > MAX_BLOCKS)
    #error "BENCH_BLOCKS must be in [1, MAX_BLOCKS]"
#endif

// CICD (Cold I$, Cold D$), WICD (Warm I$, Cold D$), WIWD (Warm I$, Warm D$)
#define CICD 0
#define WICD 1 // default
#define WIWD 2

#ifndef STATE
    #define STATE WICD
#endif
#if (STATE != CICD) && (STATE != WICD) && (STATE != WIWD)
    #error "STATE must be in list {CICD, WICD, WIWD}"
#endif
static const char *const STATE_NAME[] = { "CICD", "WICD", "WIWD" };

// Line-aligned buffers in cacheable main RAM
static uint32_t src_buf[MAX_LEN] __attribute__((aligned(CACHE_LINE_BYTES)));
static uint32_t dst_sw [MAX_LEN] __attribute__((aligned(CACHE_LINE_BYTES)));

// -------------------------Buffer preparation (never timed)-------------------------
static void init_src(uint32_t len) {
    uint32_t x = SEED;
    for (uint32_t i = 0; i < len; i++) {
        x = x * 1664525u + 1013904223u;
        src_buf[i] = x;
    }
}
static void poison_dst_sw(uint32_t len) {
    for (uint32_t i = 0; i < len; i++)
        dst_sw[i] = POISON;
}
static void poison_scratch(uint32_t len) {
    for (uint32_t i = 0; i < len; i++)
        HYDRA_SCRATCH[i] = POISON;
}

// Cache management block
static void cache_mgmt(uint32_t len) {
    #if STATE == CICD // Flush both I$ and D$
        icache_invalidate();
        dcache_flush(src_buf, len * sizeof(uint32_t));
        dcache_flush(dst_sw,  len * sizeof(uint32_t));
    #elif STATE == WICD // Flush D$ only
        dcache_flush(src_buf, len * sizeof(uint32_t));
        dcache_flush(dst_sw,  len * sizeof(uint32_t));
    #elif STATE == WIWD // Don't flush either, but write back D$
        dcache_clean(src_buf, len * sizeof(uint32_t));
        dcache_clean(dst_sw,  len * sizeof(uint32_t));
    #else
        #error "No valid STATE selected. Please select among CICD, WICD, WIWD and try again."         
    #endif
}

// -------------------------Timed kernels-------------------------
// HYDRA offload end to end: MMR programming + launch + transfer + completion poll
__attribute__((noipa))
uint32_t hydra_modeB(uint32_t src, uint32_t dst, uint32_t len, perf_t *out) {
    uint32_t status;
    perf_t   t0, t1;

    // 1. Program memory addresses and transfer size    
    t0 = perf_begin();
    HYDRA_MMR->SRC  = src;
    HYDRA_MMR->DST  = dst;
    HYDRA_MMR->LEN  = len;

    // 2. Program ctrl settings and start HYDRA
    HYDRA_MMR->CTRL = HYDRA_MMR_CTRL_START | HYDRA_MMR_CTRL_MODEB;

    // 3. Poll status register until done bit is set
    do {
        status = HYDRA_MMR->STATUS;
    } while (!(status & (HYDRA_MMR_STATUS_DONE | HYDRA_MMR_STATUS_ERROR)));
    t1 = perf_end();
    
    // 4. Clear error and done register after completion
    // printf("CLEARING HYDRA STATUS REGISTER\r");
    HYDRA_MMR->STATUS = 0;

    *out = perf_delta(t1, t0);
    return ((status & HYDRA_MMR_STATUS_ERROR) ? 1 : 0);
}

// Software Baseline: same block transpose with destination written sequentially
__attribute__((noipa))
void modeB_software(const uint32_t *restrict src, uint32_t *restrict dst,
                    uint32_t len, perf_t *out) {
    perf_t t0, t1;

    t0 = perf_begin();
    for (uint32_t base = 0; base < len; base += NUM_ELEMS)
        for (uint32_t r = 0; r < BLOCK_COLS; r++)
            for (uint32_t c = 0; c < BLOCK_ROWS; c++)
                dst[base + r * BLOCK_ROWS + c] = src[base + c * BLOCK_COLS + r];
    t1 = perf_end();

    *out = perf_delta(t1, t0);
}

// Compute the fixed cost of measurements
__attribute__((noipa))
void measure_overhead(perf_t *out) {
    perf_t t0 = perf_begin();
    perf_t t1 = perf_end();
    *out = perf_delta(t1, t0);
}

// -------------------------Non-Timed kernels: Verification-------------------------
static inline uint32_t golden_b(uint32_t out_idx) {
    uint32_t blk   = out_idx / NUM_ELEMS;
    uint32_t local = out_idx % NUM_ELEMS;
    uint32_t r     = local / BLOCK_ROWS;
    uint32_t c     = local % BLOCK_ROWS;
    return src_buf[blk * NUM_ELEMS + c * BLOCK_COLS + r];
}

// Returns the first mismatching index or 0 if the transpose is correct
static uint32_t verify(const volatile uint32_t *dst, uint32_t len) {
    for (uint32_t i = 0; i < len; i++)
        if (dst[i] != golden_b(i))
            return (i + 1);
    return 0;
}
static void report_mismatch(const char *who, const volatile uint32_t *dst, uint32_t idx) {
    uint32_t local = idx % NUM_ELEMS;
    printf("[FAIL] %s mismatch at index %" PRIu32 " (%" PRIu32 ", %" PRIu32 "): "
           "got=0x%08" PRIx32 " expected=0x%08" PRIx32 "\n\r",
           who, idx, local / BLOCK_ROWS + 1, local % BLOCK_ROWS + 1,
           dst[idx], golden_b(idx));
}

// -------------------------One data point-------------------------
static uint32_t run_point(uint32_t len) {
    uint32_t src_addr = (uint32_t)src_buf;
    perf_t  hw, sw, discard;
    uint32_t bad;

    printf("STARTING BENCHMARK WITH %" PRIu32 " ELEMENTS\n\r", len);

    #if (STATE == WIWD) || (STATE == WICD)
        // 0. Warm-up Caches: train I$/D$ and branch predictor on both paths, but discard results
        init_src(len);
        if (hydra_modeB(src_addr, HYDRA_SCRATCH_BASE, len, &discard)) {
            printf("[FAIL] HYDRA reported ERROR during warm-up (len=%" PRIu32 ")\n\r", len);
            return 1;
        }
        modeB_software(src_buf, dst_sw, len, &discard);            
    #endif

    // 1. Timed HYDRA run, then verify its scratchpad output
    init_src(len);
    poison_scratch(len);
    cache_mgmt(len);
    if (hydra_modeB(src_addr, HYDRA_SCRATCH_BASE, len, &hw)) {
        printf("[FAIL] HYDRA reported ERROR (len=%" PRIu32 ")\n\r", len);
        return 1;
    }
    else if ((bad = verify(HYDRA_SCRATCH, len))) {
        report_mismatch("HYDRA", HYDRA_SCRATCH, bad - 1);
        return 1;
    }
    printf("HYDRA TRANSFER SUCCESSFUL\n\r");

    // 2. Timed software run, then verify its RAM output
    init_src(len);
    poison_dst_sw(len);
    cache_mgmt(len);
    modeB_software(src_buf, dst_sw, len, &sw);
    if ((bad = verify(dst_sw, len))) {
        report_mismatch("SOFTWARE", dst_sw, bad - 1);
        return 1;
    }

    // 3. Report after both measurements are captured
    uint64_t speedup_x100 = (sw.cycles * 100 + hw.cycles / 2) / hw.cycles;
    uint64_t eff_x100     = ((uint64_t)len * 10000 + hw.cycles / 2) / hw.cycles; // compare with 1 word/cycle
    printf("len = %" PRIu32 ": HYDRA = %" PRIu64 " cyc, %" PRIu64 " instr | SW = %" PRIu64 " cyc %" PRIu64 " instr \r",
            len, hw.cycles, hw.instret, sw.cycles, sw.instret);
    // printf("len = %" PRIu32 ": HYDRA = %" PRIu64 " I$ misses, %" PRIu64 " D$ misses | SW = %" PRIu64 " I$ misses %" PRIu64 " D$ misses \r",
    //         len, hw.icacheMiss, hw.dcacheMiss, sw.icacheMiss, sw.dcacheMiss);
    printf("len = %" PRIu32 ": SPEEDUP = %" PRIu64 ".%02" PRIu64 "X, BUS EFFICIENCY = %" PRIu64 ".%02" PRIu64 "%%\n\r",
            len, speedup_x100 / 100, speedup_x100 % 100, eff_x100 / 100, eff_x100 % 100);

    return 0;
}

// -------------------------Main-------------------------
int main(void) {
    perf_t ovh;

    measure_overhead(&ovh); // warm-up call
    measure_overhead(&ovh); // measured call

    printf("\n\r-------------------------HYDRA MODE B CHARACTERIZATION (%s, %" PRIu32 " blocks)-------------------------\r", 
            STATE_NAME[STATE], BENCH_BLOCKS);
    printf("\t\t\t\t\t\t\t counter overhead: %" PRIu64 " cyc, %" PRIu64 " inst\n\r", ovh.cycles, ovh.instret);

    for (uint32_t b = MIN_BLOCKS; b <= BENCH_BLOCKS; b++)
        if (run_point(NUM_ELEMS * b)) return 1;

    printf("DONE\n\r");
    return 0;
}
