#########################################################################################################
# dcache_sim.py
#
# Written: Giovanni Sirtori <gs86@rice.edu>, 09 Oct 2026
#
# Description: Python code to predict per-block D$ misses / dirty writebacks 
#              of modeB_software on Wally's. It implements a D-Cache model
#              that emulates Wally's own: 16 KB, 4-way, 64 B lines, PLRU, 
#              write-back + write-allocate, fill invalid way first.
#
# A component of the HYDRA project.
# https://github.com/Rice-MECE-Capstone-Projects/Hydra
#
# Copyright (C) 2025-26 Rice University
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
# except in compliance with the License, or, at your option, the Apache License version 2.0. You
# may obtain a copy of the License at
#
# https://solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any work distributed under the
# License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific language governing permissions
# and limitations under the License.
#########################################################################################################

# Usage: python3 dcache_sim.py <MAX_BLOCKS> [DST_BASE_HEX]
# Model: cycles/block ~= 604 + 16.39 * writebacks (fitted from WICD –O3 –funroll-loops logs)

import sys

LINE, SETS, WAYS = 64, 64, 4
MAXB = int(sys.argv[1]) if len(sys.argv) > 1 else 64
DST  = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x80004080   # dst_sw placed before src_buf in .bss
SRC  = DST + MAXB * 128 * 4

def victim(b):  return (0 if b[1] == 0 else 1) if b[0] == 0 else (2 if b[2] == 0 else 3)
def update(b, w):
    if w < 2: b[0], b[1] = 1, (1 if w == 0 else 0)
    else:     b[0], b[2] = 0, (1 if w == 2 else 0)

tags  = [[None] * WAYS for _ in range(SETS)]
dirty = [[0] * WAYS for _ in range(SETS)]
plru  = [[0, 0, 0] for _ in range(SETS)]

def access(addr, write, st):
    ln = addr // LINE; s, t = ln % SETS, ln // SETS
    if t in tags[s]: w = tags[s].index(t)
    else:
        st[0] += 1  # update misses count
        w = tags[s].index(None) if None in tags[s] else victim(plru[s])
        if tags[s][w] is not None and dirty[s][w]: st[1] += 1   # update writebacks count
        tags[s][w], dirty[s][w] = t, 0
    if write: dirty[s][w] = 1
    update(plru[s], w)

print(f"MAX_BLOCKS={MAXB}  dst=0x{DST:08x}  src=0x{SRC:08x}  set shift={(SRC - DST) // LINE % SETS}")
print("block  length   misses  writebacks  cycles (model)")
for b in range(MAXB):
    st, base = [0, 0], b * 128
    for r in range(8):
        for c in range(16):
            access(SRC + 4 * (base + c * 8 + r), 0, st)
            access(DST + 4 * (base + r * 16 + c), 1, st)
    print(f"{b+1:5d}  {(b+1)*128:6d}  {st[0]:6d}  {st[1]:10d}  {604 + 16.39*st[1]:14.0f}")