# Load-use hazard test
# The instruction immediately after each lw uses the loaded register.
# Hazard unit should stall the pipeline for exactly 1 cycle per load-use pair.

# Setup: store values into memory first (assume memory pre-initialized, or use these stores)
    addi  x1, x0, 100     # base address = 100
    addi  x2, x0, 42      # value to store
    sw    x2, 0(x1)        # mem[100] = 42
    addi  x3, x0, 99
    sw    x3, 4(x1)        # mem[104] = 99

    lw    x4, 0(x1)        # x4 = mem[100] = 42  <-- load
    add   x5, x4, x0       # x5 = x4 (LOAD-USE: stall 1 cycle)

    lw    x6, 4(x1)        # x6 = mem[104] = 99  <-- load
    sub   x7, x6, x4       # x7 = 99 - 42 = 57   (LOAD-USE: stall 1 cycle)