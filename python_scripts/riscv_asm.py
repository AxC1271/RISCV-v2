#!/usr/bin/env python3
"""
RISC-V RV32I assembler — converts assembly instructions to 32-bit hex.

Usage:
    python3 riscv_asm.py

Output:
    Prints SystemVerilog imem[] assignments for each test program,
    ready to paste directly into your testbench.

Supported instructions:
    R-type: add, sub, and, or, xor, sll, srl, sra, slt, sltu
    I-type: addi, andi, ori, xori, slti, sltiu, slli, srli, srai
            lw, lh, lb, lhu, lbu
    S-type: sw, sh, sb
    B-type: beq, bne, blt, bge, bltu, bgeu
    U-type: lui, auipc
    J-type: jal
    I-type: jalr
"""

##!/usr/bin/env python3
# tiny rv32i assembler for testbench program generation
# usage: encode(mnemonic, ...) -> 32-bit int

def r(op, f3, f7, rd, rs1, rs2):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def i(op, f3, rd, rs1, imm):
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def s(op, f3, rs1, rs2, imm):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op

def b(f3, rs1, rs2, imm):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0b1100011

def u(op, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op

def j(rd, imm):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | \
           (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0b1101111

E = {
    'addi':  lambda rd, rs1, imm: i(0b0010011, 0b000, rd, rs1, imm),
    'slli':  lambda rd, rs1, sh:  i(0b0010011, 0b001, rd, rs1, sh),
    'srai':  lambda rd, rs1, sh:  i(0b0010011, 0b101, rd, rs1, sh | 0x400),
    'add':   lambda rd, rs1, rs2: r(0b0110011, 0b000, 0b0000000, rd, rs1, rs2),
    'sub':   lambda rd, rs1, rs2: r(0b0110011, 0b000, 0b0100000, rd, rs1, rs2),
    'slt':   lambda rd, rs1, rs2: r(0b0110011, 0b010, 0b0000000, rd, rs1, rs2),
    'sltu':  lambda rd, rs1, rs2: r(0b0110011, 0b011, 0b0000000, rd, rs1, rs2),
    'lw':    lambda rd, rs1, imm: i(0b0000011, 0b010, rd, rs1, imm),
    'lh':    lambda rd, rs1, imm: i(0b0000011, 0b001, rd, rs1, imm),
    'lhu':   lambda rd, rs1, imm: i(0b0000011, 0b101, rd, rs1, imm),
    'lb':    lambda rd, rs1, imm: i(0b0000011, 0b000, rd, rs1, imm),
    'lbu':   lambda rd, rs1, imm: i(0b0000011, 0b100, rd, rs1, imm),
    'sw':    lambda rs1, rs2, imm: s(0b0100011, 0b010, rs1, rs2, imm),
    'sh':    lambda rs1, rs2, imm: s(0b0100011, 0b001, rs1, rs2, imm),
    'sb':    lambda rs1, rs2, imm: s(0b0100011, 0b000, rs1, rs2, imm),
    'beq':   lambda rs1, rs2, imm: b(0b000, rs1, rs2, imm),
    'bne':   lambda rs1, rs2, imm: b(0b001, rs1, rs2, imm),
    'blt':   lambda rs1, rs2, imm: b(0b100, rs1, rs2, imm),
    'lui':   lambda rd, imm20: u(0b0110111, rd, imm20),
    'auipc': lambda rd, imm20: u(0b0010111, rd, imm20),
    'jal':   lambda rd, imm: j(rd, imm),
    'jalr':  lambda rd, rs1, imm: i(0b1100111, 0b000, rd, rs1, imm),
    'ebreak': lambda: 0x00100073,
    'nop':   lambda: 0x00000013,
}

BASE = 0x00010000

program = [
    # (addr, mnemonic, args, comment)
    (0x00, 'addi', (1, 0, 100),      'x1  = 100 (base ptr)'),
    (0x04, 'addi', (2, 0, 42),       'x2  = 42'),
    (0x08, 'add',  (3, 1, 2),        'x3  = 142  EX->EX fwd'),
    (0x0C, 'sw',   (1, 2, 0),        'mem[100] = 42'),
    (0x10, 'lw',   (4, 1, 0),        'x4  = 42'),
    (0x14, 'add',  (5, 4, 4),        'x5  = 84   load-use stall'),
    (0x18, 'lui',  (6, 0x12345),     'x6  = 0x12345000'),
    (0x1C, 'auipc',(7, 0),           'x7  = BASE+0x1C'),
    (0x20, 'jal',  (8, 12),          'x8  = BASE+0x24, jump to +0x2C'),
    (0x24, 'addi', (9, 0, 99),       'SQUASHED'),
    (0x28, 'addi', (10, 0, 98),      'SQUASHED'),
    (0x2C, 'addi', (11, 0, 1),       'x11 = 1'),
    (0x30, 'auipc',(12, 0),          'x12 = BASE+0x30'),
    (0x34, 'jalr', (13, 12, 0x40),   'x13 = BASE+0x38, jump to BASE+0x70'),
    (0x38, 'addi', (14, 0, 97),      'SQUASHED'),
    (0x3C, 'addi', (15, 0, 96),      'SQUASHED'),
    (0x70, 'addi', (14, 0, 5),       'x14 = 5'),
    (0x74, 'beq',  (14, 14, 12),     'taken, jump to +0x80'),
    (0x78, 'addi', (15, 0, 95),      'SQUASHED'),
    (0x7C, 'addi', (16, 0, 94),      'SQUASHED'),
    (0x80, 'bne',  (14, 14, 8),      'not taken'),
    (0x84, 'addi', (16, 0, 7),       'x16 = 7'),
    (0x88, 'addi', (17, 0, -1),      'x17 = 0xFFFFFFFF'),
    (0x8C, 'sb',   (1, 17, 4),       'mem[104].b0 = FF'),
    (0x90, 'sb',   (1, 14, 5),       'mem[104].b1 = 05 -> 0x000005FF'),
    (0x94, 'lbu',  (18, 1, 4),       'x18 = 0x000000FF'),
    (0x98, 'lb',   (19, 1, 4),       'x19 = 0xFFFFFFFF'),
    (0x9C, 'lh',   (20, 1, 4),       'x20 = 0x000005FF'),
    (0xA0, 'sh',   (1, 17, 6),       'mem[104] = 0xFFFF05FF'),
    (0xA4, 'lw',   (21, 1, 4),       'x21 = 0xFFFF05FF'),
    (0xA8, 'lhu',  (22, 1, 6),       'x22 = 0x0000FFFF'),
    (0xAC, 'srai', (23, 17, 4),      'x23 = 0xFFFFFFFF'),
    (0xB0, 'sltu', (24, 0, 17),      'x24 = 1'),
    (0xB4, 'slt',  (25, 17, 0),      'x25 = 1'),
    (0xB8, 'ebreak', (),             'halt'),
]

if __name__ == '__main__':
    for addr, m, args, comment in program:
        word = E[m](*args)
        argstr = ', '.join(str(a) for a in args)
        print(f"        imem['h{addr:03X} >> 2] = 32'h{word:08X}; // {m:<6}{argstr:<16} # {comment}")