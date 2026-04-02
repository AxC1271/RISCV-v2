# RAW hazard / forwarding test
# Each instruction reads a register written by the immediately preceding instruction.
# With correct EX->EX and MEM->EX forwarding, zero stalls should occur.

_start:
    addi  x1, x0, 10      # x1 = 10
    addi  x2, x1, 5       # x2 = x1 + 5 = 15    (EX->EX forward on x1)
    add   x3, x1, x2      # x3 = x1 + x2 = 25   (EX->EX on x2, MEM->EX on x1)
    slli  x4, x3, 2       # x4 = x3 << 2 = 100  (EX->EX forward on x3)
    sub   x5, x4, x1      # x5 = x4 - x1 = 90   (EX->EX on x4, MEM->EX on x1)
    xor   x6, x5, x2      # x6 = x5 ^ x2 = 85   (EX->EX on x5, MEM->EX on x2)
    or    x7, x6, x3      # x7 = x6 | x3 = 93   (EX->EX on x6, MEM->EX on x3)
    and   x8, x7, x4      # x8 = x7 & x4 = 64   (EX->EX on x7, MEM->EX on x4)
