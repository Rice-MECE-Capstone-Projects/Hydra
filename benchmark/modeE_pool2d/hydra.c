//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra.c
//
// Author: Giovanni Sirtori <gs86@rice.edu>
// Modified: bjw8 <bjw8@rice.edu> (Mode E 2D pooling, LeNet-5 layers), 10 Nov 2026
//
// Description: C code to benchmark HYDRA's Mode E 2D pooling on the two pooling layers of a
//              trained LeNet-5 in Wally. The activations come from a real MNIST test digit run
//              through the trained network (see lenet/train_export.py), so both HYDRA and the
//              software baseline pool real CNN feature maps. Both outputs are checked bit for
//              bit against the reference exported with the data. conv1 is also timed once on
//              the CPU, to put the pooling speedup in the context of a whole layer pair.
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
//      make [S=...] [O=...] [OP=...] [DUMP=...]
//  Examples:
//      make
//      make OP="MAX AVG" S="CICD WICD WIWD"
//      make DUMP=1          (also prints HYDRA's pool1 output for plot_lenet.py)
//  Defaults:
//      S=WICD
//      O=-O3_-funroll-loops
//      OP=MAX
//      DUMP=0
//  The pooling window is fixed at 2x2 (LeNet-5), so HYDRA is built with HYDRA_POOL_SIZE=2.

#include "../hydra.h"
#include "lenet_data.h"
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
#define POISON           0xDEADBEEFu

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

// MAX is LeNet-5's pooling here; AVG is the classic LeNet "subsampling" variant
#define MAX 0 // default
#define AVG 1

#ifndef OP
    #define OP MAX
#endif
#if (OP != MAX) && (OP != AVG)
    #error "OP must be in list {MAX, AVG}"
#endif
#if OP == AVG
    #define HYDRA_MMR_CTRL_OP HYDRA_MMR_CTRL_POOL_AVG
#else
    #define HYDRA_MMR_CTRL_OP HYDRA_MMR_CTRL_POOL_MAX
#endif
static const char *const OP_NAME[] = { "MAX", "AVG" };

#ifndef DUMP
    #define DUMP 0
#endif

#if POOL_SIZE != 2
    #error "LeNet-5 pools 2x2: build with POOL_SIZE=2 (and HYDRA_POOL_SIZE=2 in the RTL)"
#endif
#define K        POOL_SIZE
#define AVG_BITS 2 // log2(K*K)

#define POOL1_IN   (C1 * H1 * H1)               // 6x28x28  = 4704 words
#define POOL1_OUT  (POOL1_IN / (K * K))         // 6x14x14  = 1176 words
#define POOL2_IN   (C2 * H2 * H2)               // 16x10x10 = 1600 words
#define POOL2_OUT  (POOL2_IN / (K * K))         // 16x5x5   =  400 words

// HYDRA limits: whole windows, at most MAX_POOL_COLS (64) windows per row, output fits the
// 32 KB scratchpad
#if (H1 % K) || (H2 % K) || (H1 / K > 64) || (H2 / K > 64) || (POOL1_OUT > 8192)
    #error "LeNet shapes do not fit HYDRA's 2D pooling limits"
#endif

// Line-aligned buffers in cacheable main RAM
static int32_t src_buf [POOL1_IN] __attribute__((aligned(CACHE_LINE_BYTES)));
static int32_t dst_sw  [POOL1_OUT] __attribute__((aligned(CACHE_LINE_BYTES)));
static int32_t conv_out[POOL1_IN] __attribute__((aligned(CACHE_LINE_BYTES)));
static int32_t img_buf [IMG_DIM * IMG_DIM] __attribute__((aligned(CACHE_LINE_BYTES)));

typedef struct {
    const char    *name;
    uint32_t       c, h, w;       // input shape, CHW
    const int32_t *in;            // input activations
    const int32_t *ref;           // expected pooled output for OP
} layer_t;

static const layer_t LAYERS[] = {
    { "pool1", C1, H1, H1, lenet_pool1_in, (OP == AVG) ? lenet_pool1_avg : lenet_pool1_max },
    { "pool2", C2, H2, H2, lenet_pool2_in, (OP == AVG) ? lenet_pool2_avg : lenet_pool2_max },
};
#define NUM_LAYERS (sizeof(LAYERS) / sizeof(LAYERS[0]))

// -------------------------Buffer preparation (never timed)-------------------------
static void load_src(const layer_t *l) {
    for (uint32_t i = 0; i < l->c * l->h * l->w; i++)
        src_buf[i] = l->in[i];
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
static void cache_mgmt(const void *src, uint32_t src_bytes, const void *dst, uint32_t dst_bytes) {
    #if STATE == CICD // Flush both I$ and D$
        icache_invalidate();
        dcache_flush(src, src_bytes);
        dcache_flush(dst, dst_bytes);
    #elif STATE == WICD // Flush D$ only
        dcache_flush(src, src_bytes);
        dcache_flush(dst, dst_bytes);
    #elif STATE == WIWD // Don't flush either, but write back D$
        dcache_clean(src, src_bytes);
        dcache_clean(dst, dst_bytes);
    #else
        #error "No valid STATE selected. Please select among CICD, WICD, WIWD and try again."
    #endif
}

// -------------------------Timed kernels-------------------------
// HYDRA offload end to end: MMR programming + launch + transfer + completion poll
__attribute__((noipa))
uint32_t hydra_modeE_pool2d(uint32_t src, uint32_t dst, uint32_t len, uint32_t cols, perf_t *out) {
    uint32_t status;
    perf_t   t0, t1;

    // 1. Program memory addresses, transfer size and row width
    t0 = perf_begin();
    HYDRA_MMR->SRC  = src;
    HYDRA_MMR->DST  = dst;
    HYDRA_MMR->LEN  = len;
    HYDRA_MMR->COLS = cols;

    // 2. Program ctrl settings and start HYDRA
    HYDRA_MMR->CTRL = HYDRA_MMR_CTRL_START | HYDRA_MMR_CTRL_MODEE | HYDRA_MMR_CTRL_POOL_2D | HYDRA_MMR_CTRL_OP;

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

// Software baseline: textbook 2x2 pooling over a CHW tensor. With H % K == 0 the channels
// stack into one (C*H) x W image, so a single pair of row loops covers every channel.
__attribute__((noipa))
void pool2d_software(const int32_t *restrict src, int32_t *restrict dst,
                     uint32_t rows, uint32_t w, perf_t *out) {
    perf_t t0, t1;

    t0 = perf_begin();
    for (uint32_t oy = 0; oy < rows / K; oy++) {
        const int32_t *r = src + oy * K * w;
        for (uint32_t ox = 0; ox < w / K; ox++) {
            int32_t acc = r[ox * K];
            for (uint32_t dy = 0; dy < K; dy++)
                for (uint32_t dx = 0; dx < K; dx++) {
                    if (dy == 0 && dx == 0) continue;
                    int32_t v = r[dy * w + ox * K + dx];
                    #if OP == AVG
                        acc += v;
                    #else
                        acc = (v > acc) ? v : acc;
                    #endif
                }
            #if OP == AVG
                acc >>= AVG_BITS; // arithmetic shift, as in the RTL
            #endif
            *dst++ = acc;
        }
    }
    t1 = perf_end();

    *out = perf_delta(t1, t0);
}

// conv1 + ReLU in integer arithmetic: 6 maps of 28x28 from the 32x32 padded digit.
// This is the layer that feeds pool1, timed once for the end-to-end comparison.
__attribute__((noipa))
void conv1_int(const int32_t *restrict img, int32_t *restrict dst, perf_t *out) {
    perf_t t0, t1;

    t0 = perf_begin();
    for (uint32_t f = 0; f < C1; f++) {
        const int32_t *w = lenet_conv1_w + f * K1 * K1;
        for (uint32_t y = 0; y < H1; y++)
            for (uint32_t x = 0; x < H1; x++) {
                int32_t acc = lenet_conv1_b[f];
                for (uint32_t ky = 0; ky < K1; ky++)
                    for (uint32_t kx = 0; kx < K1; kx++)
                        acc += w[ky * K1 + kx] * img[(y + ky) * IMG_DIM + x + kx];
                *dst++ = (acc > 0) ? acc : 0;
            }
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
// Returns the first mismatching index + 1, or 0 if every output matches the reference
static uint32_t verify(const volatile int32_t *got, const int32_t *exp, uint32_t len) {
    for (uint32_t i = 0; i < len; i++)
        if (got[i] != exp[i])
            return (i + 1);
    return 0;
}
static void report_mismatch(const char *who, const layer_t *l,
                            const volatile int32_t *got, uint32_t idx) {
    uint32_t ow = l->w / K, oh = l->h / K;
    printf("[FAIL] %s %s mismatch at output (ch %" PRIu32 ", y %" PRIu32 ", x %" PRIu32 "): "
           "got=0x%08" PRIx32 " expected=0x%08" PRIx32 "\n\r",
           who, l->name, idx / (oh * ow), (idx / ow) % oh, idx % ow,
           (uint32_t)got[idx], (uint32_t)l->ref[idx]);
}

static void print_x100(const char *label, uint64_t num, uint64_t den) {
    uint64_t x100 = (num * 100 + den / 2) / den;
    printf("%s%" PRIu64 ".%02" PRIu64 "X", label, x100 / 100, x100 % 100);
}

// -------------------------One pooling layer-------------------------
static uint32_t run_layer(const layer_t *l, perf_t *hw, perf_t *sw) {
    uint32_t len  = l->c * l->h * l->w;
    uint32_t olen = len / (K * K);
    uint32_t rows = l->c * l->h;
    perf_t   discard;
    uint32_t bad;

    printf("%s: %" PRIu32 "x%" PRIu32 "x%" PRIu32 " -> %" PRIu32 "x%" PRIu32 "x%" PRIu32
           " (%" PRIu32 " -> %" PRIu32 " words)\n\r",
           l->name, l->c, l->h, l->w, l->c, l->h / K, l->w / K, len, olen);

    #if (STATE == WIWD) || (STATE == WICD)
        // 0. Warm-up Caches: train I$/D$ and branch predictor on both paths, but discard results
        load_src(l);
        cache_mgmt(src_buf, len * 4, dst_sw, olen * 4);
        if (hydra_modeE_pool2d((uint32_t)src_buf, HYDRA_SCRATCH_BASE, len, l->w, &discard)) {
            printf("[FAIL] HYDRA reported ERROR during warm-up (%s)\n\r", l->name);
            return 1;
        }
        pool2d_software(src_buf, dst_sw, rows, l->w, &discard);
    #endif

    // 1. Timed HYDRA run, then verify its scratchpad output
    load_src(l);
    poison_scratch(olen);
    cache_mgmt(src_buf, len * 4, dst_sw, olen * 4);
    if (hydra_modeE_pool2d((uint32_t)src_buf, HYDRA_SCRATCH_BASE, len, l->w, hw)) {
        printf("[FAIL] HYDRA reported ERROR (%s)\n\r", l->name);
        return 1;
    }
    if ((bad = verify((const volatile int32_t *)HYDRA_SCRATCH, l->ref, olen))) {
        report_mismatch("HYDRA", l, (const volatile int32_t *)HYDRA_SCRATCH, bad - 1);
        return 1;
    }
    #if DUMP
        if (l == &LAYERS[0])
            for (uint32_t i = 0; i < olen; i++)
                printf("DUMP %" PRIu32 " %" PRId32 "\n\r", i, (int32_t)HYDRA_SCRATCH[i]);
    #endif

    // 2. Timed software run, then verify its RAM output
    load_src(l);
    poison_dst_sw(olen);
    cache_mgmt(src_buf, len * 4, dst_sw, olen * 4);
    pool2d_software(src_buf, dst_sw, rows, l->w, sw);
    if ((bad = verify(dst_sw, l->ref, olen))) {
        report_mismatch("SOFTWARE", l, dst_sw, bad - 1);
        return 1;
    }

    // 3. Report after both measurements are captured
    printf("%s: HYDRA = %" PRIu64 " cyc, %" PRIu64 " instr | SW = %" PRIu64 " cyc %" PRIu64 " instr\n\r",
           l->name, hw->cycles, hw->instret, sw->cycles, sw->instret);
    printf("%s: MATCHES REFERENCE, ", l->name);
    print_x100("SPEEDUP = ", sw->cycles, hw->cycles);
    printf(", CPU reads %" PRIu32 " input words with SW, 0 with HYDRA\n\r", len);
    return 0;
}

// -------------------------conv1 + pool1 in context-------------------------
static uint32_t run_conv1(perf_t *conv) {
    perf_t   discard;
    uint32_t bad;

    for (uint32_t i = 0; i < IMG_DIM * IMG_DIM; i++)
        img_buf[i] = lenet_image[i];
    #if (STATE == WIWD) || (STATE == WICD)
        conv1_int(img_buf, conv_out, &discard);
    #endif
    for (uint32_t i = 0; i < POOL1_IN; i++)
        conv_out[i] = POISON;
    cache_mgmt(img_buf, sizeof(img_buf), conv_out, sizeof(conv_out));
    conv1_int(img_buf, conv_out, conv);
    if ((bad = verify(conv_out, lenet_pool1_in, POOL1_IN))) {
        printf("[FAIL] conv1 mismatch at index %" PRIu32 "\n\r", bad - 1);
        return 1;
    }
    printf("conv1: SW = %" PRIu64 " cyc, %" PRIu64 " instr, MATCHES REFERENCE\n\r",
           conv->cycles, conv->instret);
    return 0;
}

// -------------------------Main-------------------------
int main(void) {
    perf_t ovh, conv, hw[NUM_LAYERS], sw[NUM_LAYERS];

    measure_overhead(&ovh); // warm-up call
    measure_overhead(&ovh); // measured call

    printf("\n\r-------------------------HYDRA MODE E 2D POOLING: LeNet-5 (%s %dx%d, %s)-------------------------\n\r",
           OP_NAME[OP], K, K, STATE_NAME[STATE]);
    printf("MNIST test digit #%d, label %d, network prediction %d, test accuracy %d.%02d%%\n\r",
           LENET_INDEX, LENET_LABEL, LENET_PRED, LENET_ACC_X100 / 100, LENET_ACC_X100 % 100);
    printf("counter overhead: %" PRIu64 " cyc, %" PRIu64 " inst\n\r", ovh.cycles, ovh.instret);

    for (uint32_t i = 0; i < NUM_LAYERS; i++)
        if (run_layer(&LAYERS[i], &hw[i], &sw[i])) return 1;

    // Pooling's share of conv1 + pool1, and the speedup of that layer pair with HYDRA pooling
    if (run_conv1(&conv)) return 1;
    uint64_t seg_sw = conv.cycles + sw[0].cycles;
    uint64_t seg_hw = conv.cycles + hw[0].cycles;
    printf("conv1+pool1: SW = %" PRIu64 " cyc | with HYDRA pool1 = %" PRIu64 " cyc | pool1 share (SW) = %"
           PRIu64 ".%01" PRIu64 "%% | ", seg_sw, seg_hw,
           (sw[0].cycles * 1000 / seg_sw) / 10, (sw[0].cycles * 1000 / seg_sw) % 10);
    print_x100("SPEEDUP = ", seg_sw, seg_hw);
    printf("\n\r");

    printf("DONE\n\r");
    return 0;
}
