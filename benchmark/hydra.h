//////////////////////////////////////////////////////////////////////////////////////////////////
// hydra.h
//
// Author: Giovanni Sirtori <gs86@rice.edu>
//
// Description: Header for C codes targeting HYDRA.
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

#ifndef HYDRA_H
#define HYDRA_H
    #include <stdio.h>
    #include <stdint.h>
    #include <stddef.h>
    #include <inttypes.h>

    #define CACHE_LINE_BYTES 64 // from wally/config/rv32gc/config.vh

    // ------------------------------Memory map-------------------------------
    #define HYDRA_MMR_BASE      0x20000000UL
    #define HYDRA_SCRATCH_BASE  0x20010000UL
    #define UNCORE_RAM_BASE     0x80000000UL

    typedef struct {
        volatile uint32_t CTRL;   // Offset 0x00
        volatile uint32_t SRC;    // Offset 0x04
        volatile uint32_t DST;    // Offset 0x08
        volatile uint32_t LEN;    // Offset 0x0C
        volatile uint32_t STATUS; // Offset 0x10
    } hydra_regs_t;

    #define HYDRA_MMR ((hydra_regs_t *)HYDRA_MMR_BASE)
    #define HYDRA_SCRATCH ((volatile uint32_t *)HYDRA_SCRATCH_BASE)
    #define RAM   ((volatile uint32_t *)UNCORE_RAM_BASE)

    // -------------------------Control / status bits-------------------------
    #define HYDRA_MMR_CTRL_START   ( 0b1 << 0)
    #define HYDRA_MMR_CTRL_IDLE    (0b00 << 1)
    #define HYDRA_MMR_CTRL_MODEA   (0b01 << 1)
    #define HYDRA_MMR_CTRL_MODEB   (0b10 << 1)
    #define HYDRA_MMR_CTRL_MODEC   (0b11 << 1)
    #define HYDRA_MMR_STATUS_DONE  ( 0b1 << 0)
    #define HYDRA_MMR_STATUS_ERROR ( 0b1 << 1)

    // ----------------------------Mode B geometry----------------------------
    #define BLOCK_ROWS 8
    #define BLOCK_COLS 16
    #define NUM_ELEMS  (BLOCK_ROWS * BLOCK_COLS) // from src/hydra_pkg.sv

    // -------------------------Performance counters--------------------------
    typedef struct {
        uint64_t cycles;
        uint64_t instret;
        uint64_t icacheMiss;
        uint64_t dcacheMiss;
    } perf_t;

    // Use "memory" clobber as compiler barrier
    #if __riscv_xlen == 32
        #define READ_CSR64(hi, lo) ({                                                   \
            uint32_t _h1, _l, _h2;                                                      \
            do {                                                                        \
                asm volatile ("csrr %0, " #hi : "=r"(_h1) :: "memory");                 \
                asm volatile ("csrr %0, " #lo : "=r"(_l)  :: "memory");                 \
                asm volatile ("csrr %0, " #hi : "=r"(_h2) :: "memory");                 \
            } while (_h1 != _h2); /* protect from counter rolling over */               \
            ((uint64_t)_h1 << 32) | _l;                                                 \
        })
    #else
        #define READ_CSR64(hi, lo) ({                                                   \
            uint64_t _v;                                                                \
            asm volatile ("csrr %0, " #lo : "=r"(_v) :: "memory");                      \
            _v;                                                                         \
        })
    #endif

    static inline uint64_t rd_cycle(void)   { return READ_CSR64(mcycleh,   mcycle);   }
    static inline uint64_t rd_instret(void) { return READ_CSR64(minstreth, minstret); }
    // HPM counter index from wally/src/privileged/csrc.sv
    static inline uint64_t rd_icacheMiss(void) { return READ_CSR64(mhpmcounter17h, mhpmcounter17); }
    static inline uint64_t rd_dcacheMiss(void) { return READ_CSR64(mhpmcounter14h, mhpmcounter14); }

    // Keep cycle reads innermost
    static inline perf_t perf_begin(void) {
        perf_t p = {
            // .dcacheMiss = rd_dcacheMiss(),
            // .icacheMiss = rd_icacheMiss(),
            .instret    = rd_instret(),
            .cycles     = rd_cycle(),
        };
        return p;
    }
    static inline perf_t perf_end(void) {
        perf_t p = {
            .cycles     = rd_cycle(),
            .instret    = rd_instret(),
            // .icacheMiss = rd_icacheMiss(),
            // .dcacheMiss = rd_dcacheMiss(),
        };
        return p;
    }
    static inline perf_t perf_delta(perf_t t1, perf_t t0) {
        perf_t d = {
            .cycles     = t1.cycles - t0.cycles,
            .instret    = t1.instret - t0.instret,
            // .icacheMiss = t1.icacheMiss - t0.icacheMiss,
            // .dcacheMiss = t1.dcacheMiss - t0.dcacheMiss,
        };
        return d;
    }


    // -------------------------Cache Management-------------------------
    // Zicbom CBO.CLEAN writes back (if dirty) one D$ line and keeps it resident
    static inline void dcache_clean(const void *p, size_t bytes) {
        uintptr_t a   = (uintptr_t)p & ~(uintptr_t)(CACHE_LINE_BYTES - 1);
        uintptr_t end = (uintptr_t)p + bytes;
        for (; a < end; a += CACHE_LINE_BYTES )
            asm volatile ("cbo.clean (%0)" :: "r"(a) : "memory");
    }
    // Zicbom CBO.FLUSH writes back (if dirty) and invalidate one D$ line 
    static inline void dcache_flush(const void *p, size_t bytes) {
        uintptr_t a   = (uintptr_t)p & ~(uintptr_t)(CACHE_LINE_BYTES - 1);
        uintptr_t end = (uintptr_t)p + bytes;
        for (; a < end; a += CACHE_LINE_BYTES )
            asm volatile ("cbo.flush (%0)" :: "r"(a) : "memory");
    }
    // In Wally, FENCE.I invalidates I$ but only clean D$ (from wally/src/ieu/controller.sv)
    static inline void icache_invalidate(void) {
        asm volatile ("fence.i" ::: "memory");
    }
#endif
