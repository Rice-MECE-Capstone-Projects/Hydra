.section .text
.global _start

_start:
    addi x1, x0, 1
    addi x2, x0, 2

    fence           # should hit opcode=F_TYPE_FENCE, inst_typ=F
    fence.i         # should also hit F_TYPE_FENCE, inst_typ=F

    ebreak          # should hit opcode=I_Type_ECALL, inst_typ=I_ECALL
    ecall           # should hit opcode=I_Type_ECALL, inst_typ=I_ECALL

    # success trailer: write DEADBEEF to memory_offset 0x600
    lui   x15, 0xDEADC
    addi  x15, x15, -273       # 0xEEF as signed 12-bit => -273
    addi  x10, x0, 0x600
    sw    x15, 0(x10)

done:
    jal x0, done
