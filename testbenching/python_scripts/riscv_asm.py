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

# -------------------------------------------------------
# Encoding helpers
# -------------------------------------------------------

def sign_ext(val, bits):
    """Sign-extend val from bits width to Python int."""
    if val >= (1 << (bits - 1)):
        val -= (1 << bits)
    return val

def to_unsigned(val, bits):
    """Mask val to bits-wide unsigned."""
    return val & ((1 << bits) - 1)

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (to_unsigned(funct7, 7) << 25 |
            to_unsigned(rs2,    5) << 20 |
            to_unsigned(rs1,    5) << 15 |
            to_unsigned(funct3, 3) << 12 |
            to_unsigned(rd,     5) <<  7 |
            to_unsigned(opcode, 7))

def encode_i(imm, rs1, funct3, rd, opcode):
    return (to_unsigned(imm,    12) << 20 |
            to_unsigned(rs1,     5) << 15 |
            to_unsigned(funct3,  3) << 12 |
            to_unsigned(rd,      5) <<  7 |
            to_unsigned(opcode,  7))

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm = to_unsigned(imm, 12)
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0  =  imm       & 0x1F
    return (imm_11_5 << 25 |
            to_unsigned(rs2,    5) << 20 |
            to_unsigned(rs1,    5) << 15 |
            to_unsigned(funct3, 3) << 12 |
            imm_4_0 << 7           |
            to_unsigned(opcode, 7))

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm = to_unsigned(imm, 13)
    b12   = (imm >> 12) & 1
    b11   = (imm >> 11) & 1
    b10_5 = (imm >>  5) & 0x3F
    b4_1  = (imm >>  1) & 0xF
    return (b12   << 31 |
            b10_5 << 25 |
            to_unsigned(rs2,    5) << 20 |
            to_unsigned(rs1,    5) << 15 |
            to_unsigned(funct3, 3) << 12 |
            b4_1  <<  8 |
            b11   <<  7 |
            to_unsigned(opcode, 7))

def encode_u(imm, rd, opcode):
    return (to_unsigned(imm, 20) << 12 |
            to_unsigned(rd,   5) <<  7 |
            to_unsigned(opcode, 7))

def encode_j(imm, rd, opcode):
    imm = to_unsigned(imm, 21)
    b20    = (imm >> 20) & 1
    b10_1  = (imm >>  1) & 0x3FF
    b11    = (imm >> 11) & 1
    b19_12 = (imm >> 12) & 0xFF
    return (b20    << 31 |
            b19_12 << 12 |  # note: these two are swapped from intuition
            b11    << 20 |
            b10_1  << 21 |
            to_unsigned(rd, 5) << 7 |
            to_unsigned(opcode, 7))

# -------------------------------------------------------
# Register name → number
# -------------------------------------------------------
REGS = {f'x{i}': i for i in range(32)}
REGS.update({
    'zero':0, 'ra':1, 'sp':2, 'gp':3, 'tp':4,
    't0':5, 't1':6, 't2':7,
    's0':8, 'fp':8, 's1':9,
    'a0':10, 'a1':11, 'a2':12, 'a3':13,
    'a4':14, 'a5':15, 'a6':16, 'a7':17,
    's2':18, 's3':19, 's4':20, 's5':21,
    's6':22, 's7':23, 's8':24, 's9':25,
    's10':26, 's11':27,
    't3':28, 't4':29, 't5':30, 't6':31,
})

def reg(name):
    name = name.strip().lower()
    if name not in REGS:
        raise ValueError(f"Unknown register: {name}")
    return REGS[name]

# -------------------------------------------------------
# Individual instruction encoders
# -------------------------------------------------------

def addi(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b000, reg(rd), 0b0010011)

def add(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b000, reg(rd), 0b0110011)

def sub(rd, rs1, rs2):
    return encode_r(0b0100000, reg(rs2), reg(rs1), 0b000, reg(rd), 0b0110011)

def and_(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b111, reg(rd), 0b0110011)

def or_(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b110, reg(rd), 0b0110011)

def xor(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b100, reg(rd), 0b0110011)

def sll(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b001, reg(rd), 0b0110011)

def srl(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b101, reg(rd), 0b0110011)

def sra(rd, rs1, rs2):
    return encode_r(0b0100000, reg(rs2), reg(rs1), 0b101, reg(rd), 0b0110011)

def slt(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b010, reg(rd), 0b0110011)

def sltu(rd, rs1, rs2):
    return encode_r(0b0000000, reg(rs2), reg(rs1), 0b011, reg(rd), 0b0110011)

def andi(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b111, reg(rd), 0b0010011)

def ori(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b110, reg(rd), 0b0010011)

def xori(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b100, reg(rd), 0b0010011)

def slti(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b010, reg(rd), 0b0010011)

def sltiu(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b011, reg(rd), 0b0010011)

def slli(rd, rs1, shamt):
    return encode_i((0b0000000 << 5) | (shamt & 0x1F), reg(rs1), 0b001, reg(rd), 0b0010011)

def srli(rd, rs1, shamt):
    return encode_i((0b0000000 << 5) | (shamt & 0x1F), reg(rs1), 0b101, reg(rd), 0b0010011)

def srai(rd, rs1, shamt):
    return encode_i((0b0100000 << 5) | (shamt & 0x1F), reg(rs1), 0b101, reg(rd), 0b0010011)

def lw(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b010, reg(rd), 0b0000011)

def lh(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b001, reg(rd), 0b0000011)

def lb(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b000, reg(rd), 0b0000011)

def lhu(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b101, reg(rd), 0b0000011)

def lbu(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b100, reg(rd), 0b0000011)

def sw(rs2, rs1, imm):
    return encode_s(imm, reg(rs2), reg(rs1), 0b010, 0b0100011)

def sh(rs2, rs1, imm):
    return encode_s(imm, reg(rs2), reg(rs1), 0b001, 0b0100011)

def sb(rs2, rs1, imm):
    return encode_s(imm, reg(rs2), reg(rs1), 0b000, 0b0100011)

def beq(rs1, rs2, imm):
    return encode_b(imm, reg(rs2), reg(rs1), 0b000, 0b1100011)

def bne(rs1, rs2, imm):
    return encode_b(imm, reg(rs2), reg(rs1), 0b001, 0b1100011)

def blt(rs1, rs2, imm):
    return encode_b(imm, reg(rs2), reg(rs1), 0b100, 0b1100011)

def bge(rs1, rs2, imm):
    return encode_b(imm, reg(rs2), reg(rs1), 0b101, 0b1100011)

def bltu(rs1, rs2, imm):
    return encode_b(imm, reg(rs2), reg(rs1), 0b110, 0b1100011)

def bgeu(rs1, rs2, imm):
    return encode_b(imm, reg(rs2), reg(rs1), 0b111, 0b1100011)

def lui(rd, imm):
    return encode_u(imm, reg(rd), 0b0110111)

def auipc(rd, imm):
    return encode_u(imm, reg(rd), 0b0010111)

def jal(rd, imm):
    return encode_j(imm, reg(rd), 0b1101111)

def jalr(rd, rs1, imm):
    return encode_i(imm, reg(rs1), 0b000, reg(rd), 0b1100111)

NOP = addi('x0', 'x0', 0)

# -------------------------------------------------------
# Helper: print a program as SystemVerilog imem[] lines
# -------------------------------------------------------

def print_program(name, instructions, base_addr=0):
    """
    instructions: list of (encoding, comment) tuples
    base_addr: byte address of first instruction
    """
    print(f"\n// {'='*60}")
    print(f"// {name}")
    print(f"// {'='*60}")
    for i, (enc, comment) in enumerate(instructions):
        word_addr = (base_addr >> 2) + i
        byte_addr = base_addr + i * 4
        print(f"imem['h{byte_addr:03X} >> 2] = 32'h{enc:08X}; // {comment}")

# -------------------------------------------------------
# Test programs
# -------------------------------------------------------

def program_raw_hazards():
    """
    RAW hazard / forwarding test.
    Expected results: x1=10 x2=15 x3=25 x4=100 x5=90 x6=85 x7=93 x8=64
    """
    prog = [
        (addi('x1','x0', 10),  "addi x1, x0, 10      # x1 = 10"),
        (addi('x2','x1',  5),  "addi x2, x1, 5       # x2 = 15  (EX->EX on x1)"),
        (add ('x3','x1','x2'), "add  x3, x1, x2      # x3 = 25  (EX->EX x2, MEM->EX x1)"),
        (slli('x4','x3',  2),  "slli x4, x3, 2       # x4 = 100 (EX->EX on x3)"),
        (sub ('x5','x4','x1'), "sub  x5, x4, x1      # x5 = 90  (EX->EX x4, MEM->EX x1)"),
        (xor ('x6','x5','x2'), "xor  x6, x5, x2      # x6 = 85  (EX->EX x5, MEM->EX x2)"),
        (or_ ('x7','x6','x3'), "or   x7, x6, x3      # x7 = 93  (EX->EX x6, MEM->EX x3)"),
        (and_('x8','x7','x4'), "and  x8, x7, x4      # x8 = 64  (EX->EX x7, MEM->EX x4)"),
    ]
    print_program("Program 1: RAW Hazard / Forwarding Test", prog)
    print()
    print("// Expected register values:")
    print("// x1=10  x2=15  x3=25  x4=100  x5=90  x6=85  x7=93  x8=64")
    print()
    print("// SystemVerilog checks:")
    checks = [
        (1, 10,  "addi x1=10"),
        (2, 15,  "addi x2=15"),
        (3, 25,  "add x3=25"),
        (4, 100, "slli x4=100"),
        (5, 90,  "sub x5=90"),
        (6, 85,  "xor x6=85"),
        (7, 93,  "or x7=93"),
        (8, 64,  "and x8=64"),
    ]
    for rn, exp, lbl in checks:
        print(f'check_reg({rn:2d}, 32\'d{exp:<5}, "{lbl}");')

def program_load_use():
    """
    Load-use hazard test.
    Stores values then loads and uses them immediately.
    Expected: x4=42, x5=42, x6=99, x7=57
    """
    # base=100, store 42 at [100], 99 at [104]
    prog = [
        (addi('x1','x0',100), "addi x1, x0, 100    # base address = 100"),
        (addi('x2','x0', 42), "addi x2, x0, 42     # value = 42"),
        (sw  ('x2','x1',  0), "sw   x2, 0(x1)      # mem[100] = 42"),
        (addi('x3','x0', 99), "addi x3, x0, 99     # value = 99"),
        (sw  ('x3','x1',  4), "sw   x3, 4(x1)      # mem[104] = 99"),
        (lw  ('x4','x1',  0), "lw   x4, 0(x1)      # x4 = 42  <load>"),
        (add ('x5','x4','x0'),"add  x5, x4, x0     # x5 = x4  LOAD-USE stall"),
        (lw  ('x6','x1',  4), "lw   x6, 4(x1)      # x6 = 99  <load>"),
        (sub ('x7','x6','x4'),"sub  x7, x6, x4     # x7 = 57  LOAD-USE stall"),
    ]
    print_program("Program 2: Load-Use Hazard Test", prog)
    print()
    print("// Expected register values:")
    print("// x4=42  x5=42  x6=99  x7=57")
    print()
    print("// SystemVerilog checks:")
    checks = [
        (4, 42, "lw x4=42"),
        (5, 42, "add x5=42"),
        (6, 99, "lw x6=99"),
        (7, 57, "sub x7=57"),
    ]
    for rn, exp, lbl in checks:
        print(f'check_reg({rn:2d}, 32\'d{exp:<5}, "{lbl}");')
    print('check_dmem(32\'h00000064, 32\'d42,  "sw x2 -> mem[100]");')
    print('check_dmem(32\'h00000068, 32\'d99,  "sw x3 -> mem[104]");')

def program_branch_penalty():
    """
    Branch penalty test.
    BEQ taken — 2 instructions squashed.
    Expected: x1=5, x2=5, x5=1, x6=2; x3 and x4 should be 0 (squashed).
    """
    # beq offset: target is at pc+12 (3 instructions forward, so imm=12)
    # Layout:
    #   0x00: addi x1, x0, 5
    #   0x04: addi x2, x0, 5
    #   0x08: beq x1, x2, +12   -> jumps to 0x14
    #   0x0C: addi x3, x0, 99   <- squashed
    #   0x10: addi x4, x0, 88   <- squashed
    #   0x14: addi x5, x0, 1    <- target
    #   0x18: addi x6, x0, 2
    prog = [
        (addi('x1','x0',  5), "addi x1, x0, 5      # x1 = 5"),
        (addi('x2','x0',  5), "addi x2, x0, 5      # x2 = 5"),
        (beq ('x1','x2', 12), "beq  x1, x2, +12    # taken -> flush IF/ID, ID/EX"),
        (addi('x3','x0', 99), "addi x3, x0, 99     # SQUASHED"),
        (addi('x4','x0', 88), "addi x4, x0, 88     # SQUASHED"),
        (addi('x5','x0',  1), "addi x5, x0, 1      # x5 = 1  (branch target)"),
        (addi('x6','x0',  2), "addi x6, x0, 2      # x6 = 2"),
    ]
    print_program("Program 3: Branch Penalty Test", prog)
    print()
    print("// Expected: x1=5 x2=5 x5=1 x6=2")
    print("// x3 and x4 should be 0 (squashed by branch flush)")
    print()
    print("// SystemVerilog checks:")
    checks = [
        (1,  5, "addi x1=5"),
        (2,  5, "addi x2=5"),
        (3,  0, "x3 squashed=0"),
        (4,  0, "x4 squashed=0"),
        (5,  1, "addi x5=1"),
        (6,  2, "addi x6=2"),
    ]
    for rn, exp, lbl in checks:
        print(f'check_reg({rn:2d}, 32\'d{exp:<5}, "{lbl}");')

def program_mixed_ipc():
    """
    Mixed workload for IPC measurement.
    Loop 8 times: load array[i], increment, store back.
    base address = 200 (0xC8), array pre-initialized to 0.
    After loop: array[0..7] = 1, x9 = array[0]+array[1] = 2
    """
    # Layout (byte addresses):
    # 0x00: addi x1, x0, 0      loop counter
    # 0x04: addi x2, x0, 8      loop bound
    # 0x08: addi x3, x0, 200    base address
    # loop: (0x0C)
    # 0x0C: slli x4, x1, 2      x4 = i*4
    # 0x10: add  x5, x3, x4     x5 = base + offset
    # 0x14: lw   x6, 0(x5)      x6 = array[i]
    # 0x18: addi x6, x6, 1      x6++
    # 0x1C: sw   x6, 0(x5)      array[i] = x6
    # 0x20: addi x1, x1, 1      i++
    # 0x24: blt  x1, x2, -24    if i<8 goto loop  (offset = 0x0C - 0x24 = -24)
    # post:
    # 0x28: lw   x7, 0(x3)      x7 = array[0] = 1
    # 0x2C: lw   x8, 4(x3)      x8 = array[1] = 1
    # 0x30: add  x9, x7, x8     x9 = 2
    prog = [
        (addi('x1','x0',  0),  "addi x1, x0, 0      # i = 0"),
        (addi('x2','x0',  8),  "addi x2, x0, 8      # bound = 8"),
        (addi('x3','x0',200),  "addi x3, x0, 200    # base addr = 200"),
        # loop body
        (slli('x4','x1',  2),  "slli x4, x1, 2      # x4 = i*4"),
        (add ('x5','x3','x4'), "add  x5, x3, x4     # x5 = base+offset"),
        (lw  ('x6','x5',  0),  "lw   x6, 0(x5)      # x6 = array[i]"),
        (addi('x6','x6',  1),  "addi x6, x6, 1      # x6++"),
        (sw  ('x6','x5',  0),  "sw   x6, 0(x5)      # array[i] = x6"),
        (addi('x1','x1',  1),  "addi x1, x1, 1      # i++"),
        (blt ('x1','x2',-24),  "blt  x1, x2, -24    # if i<8, loop"),
        # post-loop
        (lw  ('x7','x3',  0),  "lw   x7, 0(x3)      # x7 = array[0] = 1"),
        (lw  ('x8','x3',  4),  "lw   x8, 4(x3)      # x8 = array[1] = 1"),
        (add ('x9','x7','x8'), "add  x9, x7, x8     # x9 = array[0]+array[1] = 2"),
    ]
    print_program("Program 4: Mixed Workload / IPC Measurement", prog)
    print()
    print("// Expected after loop: array[0..7] all = 1")
    print("// x7=1  x8=1  x9=2")
    print()
    print("// SystemVerilog checks:")
    checks = [
        (7, 1, "lw x7=array[0]=1"),
        (8, 1, "lw x8=array[1]=1"),
        (9, 2, "add x9=2"),
    ]
    for rn, exp, lbl in checks:
        print(f'check_reg({rn:2d}, 32\'d{exp:<5}, "{lbl}");')
    for i in range(8):
        addr = 200 + i * 4
        print(f'check_dmem(32\'h{addr:08X}, 32\'d1, "array[{i}]=1");')


# Main program
if __name__ == "__main__":
    print("// Usage: load one program at a time into imem[] at offset 0.")
    print("// All byte addresses start at 0x000.")
    print()

    program_raw_hazards()
    print("\n" + "="*70 + "\n")
    program_load_use()
    print("\n" + "="*70 + "\n")
    program_branch_penalty()
    print("\n" + "="*70 + "\n")
    program_mixed_ipc()