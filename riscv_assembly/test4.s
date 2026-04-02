# Mixed workload for IPC measurement
# Includes ALU ops, loads/stores, branches, and a small loop.
# Count cycles vs retired instructions for IPC.

    addi  x1, x0, 0       # loop counter i = 0
    addi  x2, x0, 8       # loop bound = 8
    addi  x3, x0, 200     # base address for array

loop:
    slli  x4, x1, 2       # x4 = i * 4 (byte offset)
    add   x5, x3, x4      # x5 = base + offset
    lw    x6, 0(x5)        # x6 = array[i]
    addi  x6, x6, 1       # x6++
    sw    x6, 0(x5)        # array[i] = x6
    addi  x1, x1, 1       # i++
    blt   x1, x2, loop    # if i < 8, loop
    
    # post-loop: compute sum of first two elements
    lw    x7, 0(x3)        # x7 = array[0]
    lw    x8, 4(x3)        # x8 = array[1]
    add   x9, x7, x8       # x9 = array[0] + array[1]