Overview

This part implements Design for Testability techniques on a pipelined RISC-V processor to improve test coverage and enable efficient post-silicon testing. A scan-based testing architecture was integrated into the RTL design by converting the pipeline registers into a scan chain. This allows internal flip-flop states to be shifted in and out during test mode, enabling controllability and observability of internal nodes.

Scan Architecture

A full scan chain was implemented across the pipeline registers:

scan_in
   │
pipeReg0  (IF stage)
   │
pipeReg1  (Decode stage)
   │
pipeReg2  (Execute stage)
   │
pipeReg3  (Memory/Writeback stage)
   │
scan_out

During scan mode, the registers form a shift register:

else if (scan_en) begin
    pipeReg0 <= {pipeReg0[63:0], scan_in};
    pipeReg1 <= {pipeReg1[511:0], pipeReg0[64]};
    pipeReg2 <= {pipeReg2[511:0], pipeReg1[512]};
    pipeReg3 <= {pipeReg3[511:0], pipeReg2[512]};
end

This allows test vectors to be shifted into the design and internal states to be observed.

Scan Chain Specification

Component	Width
pipeReg0	65 bits
pipeReg1	513 bits
pipeReg2	513 bits
pipeReg3	513 bits

Total scan chain length:

65 + 513 + 513 + 513 = 1604 flip-flops

Test Modes

The design operates in two modes:

Functional Mode:scan_en = 0; Pipeline registers behave normally.
Scan Mode:scan_en = 1; Registers are connected as a shift chain and controlled by:scan_in/scan_out

DFT Signals

Signal	Description
scan_en	Enables scan shift mode
scan_in	Serial input for scan chain
scan_out	Serial output for scan chain
