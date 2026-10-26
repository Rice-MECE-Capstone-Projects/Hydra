#########################################################################################################
# Makefile
#
# Written: Wally's team (https://github.com/openhwfoundation/cvw/commits/main/examples/C/hello/Makefile)
# Modified: Giovanni Sirtori <gs86@rice.edu> (HYDRA integration), 27 Sep 2026
#
# Description: C code to benchmark integrated HYDRA vs baseline SW.
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

# Usage: make [compile, clean] [T=...] [S=...] [B=...] [O=...] [P=...]
# Examples:
#	make T="hydra test"	O="-O2 -O3_fun-roll-loops" B="5-20 40-40" S="CICD WICD WIWD"
# 	make compile T="test1 test2" O=-O1 B=32-64 S=WIWD
#	make B=1-8 P="4 8 16"
#	make clean T="hydra test"
# Defaults:
#	T=hydra
#	S=WICD
#	B=1-MAX_BLOCKS
#	O=-O3_-funroll-loops
#	P=4 (pooling window; sets both POOL_SIZE in C and HYDRA_POOL_SIZE in the RTL)

# NOTE: 1. 	for multiple compiler optimization args, concatenate them with '_'
#			like shown in example above
#		2. 	'compile' recipe only accepts one arguments for O, B, S


WALLY_DIR	= ../../wally/examples/C
# Pre-build the memfile here: elf2hex fails when Questa runs it (Questa's libstdc++ is too old)
WALLY_BIN	= ../../wally/bin
OUT_DIR		= ./log

T	?= hydra
S	?= WICD
B	?= 1-MAX_BLOCKS
O	?= -O3_-funroll-loops
P	?= 4


.PHONY: all

all:
	@mkdir -p $(OUT_DIR)
	@for t in $(T); do	\
		for s in $(S); do	\
			for b in $(B); do	\
				for o in $(O); do 	\
					for p in $(P); do	\
						o_new=$${o//_/ };	\
						$(MAKE) --no-print-directory compile						\
							TARGET=$$t												\
							SFLAG="-DSTATE=$$s" 									\
							OFLAG="$$o_new"											\
							PFLAG="-DPOOL_SIZE=$$p"									\
							BFLAG="-DMIN_BLOCKS=$${b%%-*} -DBENCH_BLOCKS=$${b#*-}";	\
						echo "Running file '$$t.c' with S=$$s, B=$$b, O=$$o_new, P=$$p";	\
						wsim rv32gc --sim questa --elf $$t 							\
							--define "+define+HYDRA_POOL_SIZE=$$p"					\
							> "$(OUT_DIR)/$${s}__$${b}__$${o}__P$${p}.log" || exit $$?;	\
						echo "Output saved to $(OUT_DIR)/$${s}__$${b}__$${o}__P$${p}.log";	\
					done; \
				done; \
			done; \
		done; \
	done

TARGET	?= 	$(T)
SFLAG	?= 	"-DSTATE=$(S)"
BFLAG	?=	-DMIN_BLOCKS=$(word 1, $(subst -, ,$(B))) \
			-DBENCH_BLOCKS=$(word 2, $(subst -, ,$(B)))
OFLAG	?= 	$(subst _, ,$(O))
PFLAG	?=	-DPOOL_SIZE=$(P)
compile:
	@for t in $(TARGET); do	\
		echo ">>> Compiling file '$$t.c' with $(SFLAG), $(BFLAG), $(OFLAG), $(PFLAG)";	\
		riscv64-unknown-elf-gcc -o $$t -gdwarf-2							\
			$(SFLAG) $(BFLAG) $(OFLAG) $(PFLAG)										\
			-march=rv32gc_zba_zbb_zbs_zicbom -mabi=ilp32d -mcmodel=medany			\
			-nostdlib -static -lm -fno-tree-loop-distribute-patterns				\
			-T$(WALLY_DIR)/common/test.ld -I$(WALLY_DIR)/common						\
			$${t}.c $(WALLY_DIR)/common/crt.S $(WALLY_DIR)/common/syscalls.c -lgcc;	\
		riscv64-unknown-elf-objdump -S -d $$t > "$${t}.objdump";			\
		$(WALLY_BIN)/elf2hex $$t "$${t}.memfile";							\
		$(WALLY_BIN)/extractFunctionRadix.sh "$${t}.objdump";				\
	done
	
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
#	  -ffast-math -DPREALLOCATE=1 -std=gnu99
#     -fno-common -fno-builtin-printf -nostartfiles -lgcc

clean:
	@for t in $(T); do	\
		rm -f $$t $$t.objdump* $$t.memfile;	\
	done
