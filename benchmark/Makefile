#########################################################################################################
# Makefile
#
# Written: Wally's team (https://github.com/openhwfoundation/cvw/commits/main/examples/C/hello/Makefile)
# Modified: Giovanni Sirtori <gs86@rice.edu> (HYDRA integration), 27 Sep 2026
#
# Description: C code to benchmark integrated HYDRA vs baseline SW.
#
# A component of the HYDRA project.
# https:##github.com/Rice-MECE-Capstone-Projects/Hydra
#
# Copyright (C) 2025-26 Rice University
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
# except in compliance with the License, or, at your option, the Apache License version 2.0. You
# may obtain a copy of the License at
#
# https:##solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any work distributed under the
# License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific language governing permissions
# and limitations under the License.
#########################################################################################################

# Usage: make [TARGET=...] [OFLAG=...] [BFLAG=...] [SFLAG=...]

FOLDER  = wally/examples/C
TARGET ?= hydra
OFLAG  ?= -O3 -funroll-loops

ifneq ($(strip $(BFLAG)),)
	BFLAGS = -DBENCH_BLOCKS=$(BFLAG)
else
	BFLAGS =
endif
ifneq ($(strip $(SFLAG)),)
	SFLAGS = -DSTATE=$(SFLAG)
else
	SFLAGS =
endif

.PHONY: $(TARGET)

$(TARGET).objdump: $(TARGET)
	riscv64-unknown-elf-objdump -S -d $(TARGET) > $(TARGET).objdump

$(TARGET): $(TARGET).c Makefile
	riscv64-unknown-elf-gcc -o $(TARGET) -gdwarf-2 						\
	  $(OFLAG) $(BFLAGS) $(SFLAGS)							\
	  -march=rv32gc_zba_zbb_zbs_zicbom -mabi=ilp32d -mcmodel=medany				\
	  -nostdlib -static -lm -fno-tree-loop-distribute-patterns		                \
	  -T../$(FOLDER)/common/test.ld -I../$(FOLDER)/common			\
	  $(TARGET).c ../$(FOLDER)/common/crt.S ../$(FOLDER)/common/syscalls.c -lgcc
# Compiler flags:
#  -o $(TARGET) defines the name of the output file
#  -g generates debugging symbols for gdb
#  -O turns on basic optimization; -O3 turns on heavy optimization; omit for no optimization
#  -march=rv64gc -mabi=lp64d =mcmodel=medany generates code for RV64GC with doubles and long/ptrs = 64 bits
#  -static forces static linking (no dynamic shared libraries on bare metal)
#  -lm links the math library if necessary (when #include math.h)
#  -nostdlib avoids inserting standard startup files and default libraries
#     because we are using crt.s on bare metal
#  -fno-tree-loop-distribute-patterns turns replacing loops with memcpy/memset in the std library
#  -T specifies the linker file
#  -I specifies the include path (e.g. for util.h)
#  The last line defines the C files to compile.
#    crt.S is needed as our startup file to initialize the processor
#    syscalls.c implements printf through the HTIF for Spike
# other flags from riscv-tests makefiles that don't seem to be important
#	  -ffast-math -DPREALLOCATE=1 -std=gnu99  \
#     -fno-common -fno-builtin-printf -nostartfiles -lgcc \

clean:
	rm -f $(TARGET) $(TARGET).objdump* $(TARGET).memfile *log
