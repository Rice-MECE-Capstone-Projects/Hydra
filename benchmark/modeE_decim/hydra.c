//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra.c
//
// Author: Giovanni Sirtori <gs86@rice.edu>
// Modified: bjw8 <bjw8@rice.edu> (Mode E boxcar decimation), 2 Nov 2026
//
// Description: C code to benchmark HYDRA's Mode E as a decimate-by-R boxcar filter
//              (integrate-and-dump / first-order CIC) in Wally. Each output is the sum (SUM)
//              or average (AVG) of R consecutive input samples, which low-pass filters and
//              downsamples by R in one pass. The input is a sine plus white noise, so the
//              benchmark also reports the SNR gain of the decimator next to its speedup.
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

//  Run with:
//      make T=hydra [S=...] [B=...] [O=...] [P=...] [OP=...]
//  Examples:
//	    make T=hydra B=64-64 P="2 4 8 16"
//	    make T=hydra B=1-8 P=8 OP="SUM AVG"
//  Defaults:
//  	S=WICD
//  	B=1-MAX_BLOCKS
//  	O=-O3_-funroll-loops
//  	P=4  (decimation factor R; sets POOL_SIZE here and HYDRA_POOL_SIZE in the RTL)
//  	OP=AVG
//  Valid B values: [1, MAX_BLOCKS]
//  Valid S values: CICD, WICD, WIWD
//  Valid P values: powers of two >= 2
//  Valid OP values: SUM, AVG

#include "../hydra.h"
#include <stdlib.h>

// Print trap info instead of hanging silently on an unexpected exception
uintptr_t handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32]) {
    uintptr_t tval;
    (void)regs;
    asm volatile ("csrr %0, mtval" : "=r"(tval));
    printf("[TRAP] mcause=0x%08" PRIxPTR " mepc=0x%08" PRIxPTR
           " mtval=0x%08" PRIxPTR "\n\r", cause, epc, tval);
    exit(128);
}


// -------------------------Benchmark configuration-------------------------
// NOTE: Avoid sweeping MAX_BLOCKS, because it changes the distance between
//       src and dst in the cache. This changes their cache-set mapping and
//       can cause write-back fluctuations that distort the measured speedup.
//       Instead, sweep BENCH_BLOCKS using the provided Makefile.
#define MAX_BLOCKS       64 // default
#define MAX_LEN          (NUM_ELEMS * MAX_BLOCKS)
#define POISON           0xDEADBEEFu
#define SEED             0x1234ABCDu

#ifndef MIN_BLOCKS
    #define MIN_BLOCKS 1
#endif
#ifndef BENCH_BLOCKS
    #define BENCH_BLOCKS MAX_BLOCKS
#endif
#if (BENCH_BLOCKS < MIN_BLOCKS) || (BENCH_BLOCKS > MAX_BLOCKS)
    #error "BENCH_BLOCKS must be in [MIN_BLOCKS, MAX_BLOCKS]"
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

// SUM keeps the full-precision block sum; AVG shifts it right by log2(R)
#define SUM 0
#define AVG 1 // default

#ifndef OP
    #define OP AVG
#endif
#if (OP != SUM) && (OP != AVG)
    #error "OP must be in list {SUM, AVG}"
#endif
#if (POOL_SIZE < 2) || (POOL_SIZE & (POOL_SIZE - 1))
    #error "POOL_SIZE (decimation factor R) must be a power of two >= 2"
#endif
#if OP == AVG
    #define HYDRA_MMR_CTRL_OP HYDRA_MMR_CTRL_POOL_AVG
    #define DECIM_OUT(acc)    ((acc) >> POOL_BITS) // arithmetic shift, as in the RTL
#else
    #define HYDRA_MMR_CTRL_OP HYDRA_MMR_CTRL_POOL_SUM
    #define DECIM_OUT(acc)    (acc)
#endif
#define POOL_BITS        __builtin_ctz(POOL_SIZE)
static const char *const OP_NAME[] = { "SUM", "AVG" };

// Test signal: one 256-sample sine period plus uniform white noise, 16-bit samples in
// 32-bit words. Input SNR = 10*log10((A^2/2) / (N^2/3)) ~= 1.76 dB for A = N = 2^13
#define SINE_PERIOD      256
#define SINE_AMP         8191.0
#define SINE_COS         0.9996988186962042    // cos(2*pi/SINE_PERIOD)
#define SINE_SIN         0.024541228522912288  // sin(2*pi/SINE_PERIOD)
#define NOISE_SHIFT      18                    // noise = top 14 LCG bits, in [-2^13, 2^13)

// Line-aligned buffers in cacheable main RAM
static int32_t src_buf[MAX_LEN] __attribute__((aligned(CACHE_LINE_BYTES)));
static int32_t dst_sw [MAX_LEN / POOL_SIZE] __attribute__((aligned(CACHE_LINE_BYTES)));
static int32_t sine_tab[SINE_PERIOD];

// -------------------------Buffer preparation (never timed)-------------------------
// Rotation recurrence instead of libm sin(); error after one period is ~1e-13
static void init_sine(void) {
    double c = 1.0, s = 0.0, t;
    for (uint32_t i = 0; i < SINE_PERIOD; i++) {
        double v = SINE_AMP * s;
        sine_tab[i] = (int32_t)(v >= 0 ? v + 0.5 : v - 0.5);
        t = c * SINE_COS - s * SINE_SIN;
        s = s * SINE_COS + c * SINE_SIN;
        c = t;
    }
}
static void init_src(uint32_t len) {
    uint32_t x = SEED;
    for (uint32_t i = 0; i < len; i++) {
        x = x * 1664525u + 1013904223u;
        src_buf[i] = sine_tab[i % SINE_PERIOD] + ((int32_t)x >> NOISE_SHIFT);
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
        dcache_flush(src_buf, len * sizeof(int32_t));
        dcache_flush(dst_sw,  len / POOL_SIZE * sizeof(int32_t));
    #elif STATE == WICD // Flush D$ only
        dcache_flush(src_buf, len * sizeof(int32_t));
        dcache_flush(dst_sw,  len / POOL_SIZE * sizeof(int32_t));
    #elif STATE == WIWD // Don't flush either, but write back D$
        dcache_clean(src_buf, len * sizeof(int32_t));
        dcache_clean(dst_sw,  len / POOL_SIZE * sizeof(int32_t));
    #else
        #error "No valid STATE selected. Please select among CICD, WICD, WIWD and try again."
    #endif
}

// -------------------------Timed kernels-------------------------
// HYDRA offload end to end: MMR programming + launch + transfer + completion poll
__attribute__((noipa))
uint32_t hydra_modeE_decim(uint32_t src, uint32_t dst, uint32_t len, perf_t *out) {
    uint32_t status;
    perf_t   t0, t1;

    // 1. Program memory addresses and transfer size
    t0 = perf_begin();
    HYDRA_MMR->SRC  = src;
    HYDRA_MMR->DST  = dst;
    HYDRA_MMR->LEN  = len;

    // 2. Program ctrl settings and start HYDRA
    HYDRA_MMR->CTRL = HYDRA_MMR_CTRL_START | HYDRA_MMR_CTRL_MODEE | HYDRA_MMR_CTRL_OP;

    // 3. Poll status register until done bit is set
    do {
        status = HYDRA_MMR->STATUS;
    } while (!(status & (HYDRA_MMR_STATUS_DONE | HYDRA_MMR_STATUS_ERROR)));
    t1 = perf_end();

    // 4. Clear error and done register after completion
    HYDRA_MMR->STATUS = 0;

    *out = perf_delta(t1, t0);
    return ((status & HYDRA_MMR_STATUS_ERROR) ? 1 : 0);
}

// Software Baseline: boxcar low-pass + decimate-by-R. Only the kept outputs are computed
// (block sum, then shift), the same work as HYDRA. A full-rate R-tap FIR followed by
// discarding R-1 of every R outputs would compute the same result ~R times slower.
__attribute__((noipa))
void modeE_decim_software(const int32_t *restrict src, int32_t *restrict dst,
                          uint32_t len, perf_t *out) {
    perf_t t0, t1;

    t0 = perf_begin();
    for (uint32_t i = 0; i < len; i += POOL_SIZE) {
        int32_t acc = 0;
        for (uint32_t j = 0; j < POOL_SIZE; j++)
            acc += src[i + j];
        dst[i / POOL_SIZE] = DECIM_OUT(acc);
    }
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
static inline int32_t golden_e_decim(uint32_t out_idx) {
    uint32_t first = out_idx * POOL_SIZE;
    int32_t  acc   = 0;
    for (uint32_t i = 0; i < POOL_SIZE; i++)
        acc += src_buf[first + i];
    return DECIM_OUT(acc);
}

// Returns the first mismatching output index + 1, or 0 if the decimation is correct
static uint32_t verify(const volatile int32_t *dst, uint32_t out_len) {
    for (uint32_t i = 0; i < out_len; i++)
        if (dst[i] != golden_e_decim(i))
            return (i + 1);
    return 0;
}
static void report_mismatch(const char *who, const volatile int32_t *dst, uint32_t idx) {
    printf("[FAIL] %s mismatch at output index %" PRIu32 " (input group starts at %" PRIu32 "): "
           "got=0x%08" PRIx32 " expected=0x%08" PRIx32 "\n\r",
           who, idx, idx * POOL_SIZE, (uint32_t)dst[idx], (uint32_t)golden_e_decim(idx));
}

// -------------------------Non-Timed kernels: SNR-------------------------
// log2 by repeated squaring, so no libm is needed; accurate to ~1e-9 for x > 0
static double log2_d(double x) {
    double r = 0.0, b = 0.5;
    while (x >= 2.0) { x *= 0.5; r += 1.0; }
    while (x <  1.0) { x *= 2.0; r -= 1.0; }
    for (int i = 0; i < 30; i++, b *= 0.5) {
        x *= x;
        if (x >= 2.0) { x *= 0.5; r += b; }
    }
    return r;
}
static double db10(double ratio) { return 3.0102999566398120 * log2_d(ratio); } // 10*log10

// printf here has no %f, so print dB values as fixed point with two decimals
static void print_db(const char *label, double db) {
    int32_t q = (int32_t)(db >= 0 ? db * 100 + 0.5 : db * 100 - 0.5);
    uint32_t a = (uint32_t)(q < 0 ? -q : q);
    printf("%s%s%" PRIu32 ".%02" PRIu32 " dB", label, q < 0 ? "-" : "", a / 100, a % 100);
}

// Input:  signal = clean sine, noise = input - sine.
// Output: signal = the clean sine passed through the same exact (unrounded) decimator,
//         noise  = output - that signal (decimated noise plus the AVG shift's rounding).
// The boxcar's small passband droop on the sine is in the reference, so it is not counted
// as noise. For white noise the expected gain is 10*log10(R).
static void report_snr(const volatile int32_t *dst, uint32_t len) {
    double sig_in = 0, noise_in = 0, sig_out = 0, noise_out = 0;
    double scale = (OP == AVG) ? 1.0 / POOL_SIZE : 1.0;

    for (uint32_t i = 0; i < len; i++) {
        double s = sine_tab[i % SINE_PERIOD];
        double n = src_buf[i] - s;
        sig_in   += s * s;
        noise_in += n * n;
    }
    for (uint32_t k = 0; k < len / POOL_SIZE; k++) {
        double ref = 0;
        for (uint32_t j = 0; j < POOL_SIZE; j++)
            ref += sine_tab[(k * POOL_SIZE + j) % SINE_PERIOD];
        ref *= scale;
        double e = dst[k] - ref;
        sig_out   += ref * ref;
        noise_out += e * e;
    }

    double snr_in  = db10(sig_in / noise_in);
    double snr_out = db10(sig_out / noise_out);
    printf("len = %" PRIu32 ": ", len);
    print_db("SNR in = ", snr_in);
    print_db(", SNR out = ", snr_out);
    print_db(", SNR GAIN = ", snr_out - snr_in);
    print_db(" (white-noise theory 10log10(R) = ", db10(POOL_SIZE));
    printf(")\n\r");
}

// -------------------------One data point-------------------------
static uint32_t run_point(uint32_t len) {
    uint32_t src_addr = (uint32_t)src_buf;
    uint32_t out_len  = len / POOL_SIZE;
    perf_t  hw, sw, discard;
    uint32_t bad;

    printf("STARTING BENCHMARK WITH %" PRIu32 " INPUT ELEMENTS\n\r", len);

    #if (STATE == WIWD) || (STATE == WICD)
        // 0. Warm-up Caches: train I$/D$ and branch predictor on both paths, but discard results
        init_src(len);
        if (hydra_modeE_decim(src_addr, HYDRA_SCRATCH_BASE, len, &discard)) {
            printf("[FAIL] HYDRA reported ERROR during warm-up (len=%" PRIu32 ")\n\r", len);
            return 1;
        }
        modeE_decim_software(src_buf, dst_sw, len, &discard);
    #endif

    // 1. Timed HYDRA run, then verify its scratchpad output
    init_src(len);
    poison_scratch(out_len);
    cache_mgmt(len);
    if (hydra_modeE_decim(src_addr, HYDRA_SCRATCH_BASE, len, &hw)) {
        printf("[FAIL] HYDRA reported ERROR (len=%" PRIu32 ")\n\r", len);
        return 1;
    }
    else if ((bad = verify((const volatile int32_t *)HYDRA_SCRATCH, out_len))) {
        report_mismatch("HYDRA", (const volatile int32_t *)HYDRA_SCRATCH, bad - 1);
        return 1;
    }
    printf("HYDRA TRANSFER SUCCESSFUL\n\r");

    // 2. Timed software run, then verify its RAM output
    init_src(len);
    poison_dst_sw(out_len);
    cache_mgmt(len);
    modeE_decim_software(src_buf, dst_sw, len, &sw);
    if ((bad = verify(dst_sw, out_len))) {
        report_mismatch("SOFTWARE", dst_sw, bad - 1);
        return 1;
    }

    // 3. Report after both measurements are captured. Both outputs match the golden model
    //    bit for bit, so the SNR is computed once, from HYDRA's scratchpad output
    uint64_t speedup_x100 = (sw.cycles * 100 + hw.cycles / 2) / hw.cycles;
    printf("len = %" PRIu32 ": HYDRA = %" PRIu64 " cyc, %" PRIu64 " instr | SW = %" PRIu64 " cyc %" PRIu64 " instr \r",
            len, hw.cycles, hw.instret, sw.cycles, sw.instret);
    printf("len = %" PRIu32 ": SPEEDUP = %" PRIu64 ".%02" PRIu64 "X\n\r",
            len, speedup_x100 / 100, speedup_x100 % 100);
    report_snr((const volatile int32_t *)HYDRA_SCRATCH, len);

    return 0;
}

// -------------------------Main-------------------------
int main(void) {
    perf_t ovh;

    measure_overhead(&ovh); // warm-up call
    measure_overhead(&ovh); // measured call
    init_sine();

    printf("\n\r-------------------------HYDRA MODE E DECIMATION (%s, R = %d, %s, blocks %"PRIu32":%" PRIu32 ")-------------------------\r",
            OP_NAME[OP], POOL_SIZE, STATE_NAME[STATE], MIN_BLOCKS, BENCH_BLOCKS);
    printf("\t\t\t\t\t\t\t counter overhead: %" PRIu64 " cyc, %" PRIu64 " inst\n\r", ovh.cycles, ovh.instret);

    for (uint32_t b = MIN_BLOCKS; b <= BENCH_BLOCKS; b++)
        if (run_point(NUM_ELEMS * b)) return 1;

    printf("DONE\n\r");
    return 0;
}
