# RISC-V Core

## Purpose

This is a single-core RISC-V core which performs pure computations, with:
* Program Counter
* Register File
* Immediate Generator
* Control Unit
* Arithmetic Logic Unit
* Data/Instruction Memory
* Data/Instruction Caches
* Hazard/Forwarding Unit
* Branch Unit
* Pipeline Registers

The overall scope of this project is to implement a single-core processor that can interact with peripherals and be programmed using a serial Python transmitter. For the testbench of this core, we are verifying a couple of parameters:

* Whether or not instructions write back correctly due to the pipeline
* Checking for pipeline hazards (RAW hazards, load-use hazards)
* Checking penalties for misses (ALU data hazards, branch penalties)

We will run discrete testbenches that will specifically test for these edge cases. Compared to a single-cycle processor, it's essential that we check the handling of data hazards and measure average IPC across randomized loads to compare performance to my older project RISC-V v1. 

---

## Test Assembly Programs

The first assembly program we will use will include a bunch of instructions that should trigger RAW hazards. We want to see if the writeback uses the correct value and that the CPU doesn't stall for the pipeline because of the forwarding logic.

```s
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
    and   x8, x7, x4      # x8 = x7 & x4 = 68   (EX->EX on x7, MEM->EX on x4)
```

Terminal Output (Icarus Verilog):
```
(.venv) achen1228@Andrews-MacBook-Pro-12 core_riscv_tb % vvp riscv_sim

[TB] CPU running...
  PASS  addi x1=10            x1                    = 0x0000000a
  PASS  addi x2=15            x2                    = 0x0000000f
  PASS  add x3=25             x3                    = 0x00000019
  PASS  slli x4=100           x4                    = 0x00000064
  PASS  sub x5=90             x5                    = 0x0000005a
  PASS  xor x6=85             x6                    = 0x00000055
  PASS  or x7=93              x7                    = 0x0000005d
  PASS  and x8=68             x8                    = 0x00000044

========== SUMMARY ==========
PASS: 8   FAIL: 0   TOTAL: 8
ALL TESTS PASSED
core_riscv_tb.sv:212: $finish called at 6065000 (1ps)
```

The next assembly program checks for load-use hazards. We expect to see the pipeline stall for exactly one cycle (the data of a load instruction isn't available until the end of mem, forcing the next instruction to stall because you'll have to wait until the load data is actually available).

```s
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
```

The third assembly program will check for branch penalties. We want to see the pipeline flush the IF/ID and ID/EX registers, which will stall the pipeline for 2 clock cycles.

```s
# Branch penalty test
# BEQ is taken (x1 == x1), causing a 2-cycle flush.
# Verify that the instructions at PC+4 and PC+8 are squashed (become NOPs in waveform).

    addi  x1, x0, 5       # x1 = 5
    addi  x2, x0, 5       # x2 = 5
    beq   x1, x2, target  # branch taken -> flush IF/ID, ID/EX
    addi  x3, x0, 99      # SQUASHED (should appear as NOP in waveform)
    addi  x4, x0, 88      # SQUASHED
target:
    addi  x5, x0, 1       # x5 = 1  (first instruction after branch resolves)
    addi  x6, x0, 2       # x6 = 2
```

Terminal Output (Icarus Verilog):
```
(.venv) achen1228@Andrews-MacBook-Pro-12 core_riscv_tb % vvp riscv_sim

[TB] CPU running...
  PASS  addi x1=5             x1                    = 0x00000005
  PASS  addi x2=5             x2                    = 0x00000005
  PASS  x3 squashed=0         x3                    = 0x00000000
  PASS  x4 squashed=0         x4                    = 0x00000000
  PASS  addi x5=1             x5                    = 0x00000001
  PASS  addi x6=2             x6                    = 0x00000002

========== SUMMARY ==========
PASS: 6   FAIL: 0   TOTAL: 6
ALL TESTS PASSED
core_riscv_tb.sv:255: $finish called at 6065000 (1ps)
```

The last assembly program will run a random set of instructions (not necessarily random, but should simulate the expected workload of a functional program) and we will measure the IPC using two counters; the amount of instructions and the amount of clock cycles. Ideally, we should see a 5x throughput (due to `t_comb `being considerably lower) compared to a single-core processor.

```s
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
```

### Static Timing Analysis

We will run synthesis/implementation later to determine the maximum clock frequency that we could hypothetically run the processor at. Recall that:

Setup Condition:
$$
t_{clk} + t_{skew} \geq T_{cq} + T_{comb} + T_{setup}
$$

Hold Condition:
$$
t_{cq} + t_{comb} \geq t_{hold} + t_{skew}
$$

For FPGA tools like Xilinx (which I'll be using to synthesize), the hold condition is usually resolved by buffers being automatically inserted along the datapath if it's too fast. For our purposes, I would like to stress test this processor design by seeing the fastest clock frequency that our processor can handle before we start seeing negative setup slack. 

## Simulation + Waveform

First Workload: RAW Hazards

```
    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // nop (addi x0, x0, 0)
            imem['h000 >> 2] = 32'h00A00093; // addi x1, x0, 10      # x1 = 10
            imem['h004 >> 2] = 32'h00508113; // addi x2, x1, 5       # x2 = 15  (EX->EX on x1)
            imem['h008 >> 2] = 32'h002081B3; // add  x3, x1, x2      # x3 = 25  (EX->EX x2, MEM->EX x1)
            imem['h00C >> 2] = 32'h00219213; // slli x4, x3, 2       # x4 = 100 (EX->EX on x3)
            imem['h010 >> 2] = 32'h401202B3; // sub  x5, x4, x1      # x5 = 90  (EX->EX x4, MEM->EX x1)
            imem['h014 >> 2] = 32'h0022C333; // xor  x6, x5, x2      # x6 = 85  (EX->EX x5, MEM->EX x2)
            imem['h018 >> 2] = 32'h003363B3; // or   x7, x6, x3      # x7 = 93  (EX->EX x6, MEM->EX x3)
            imem['h01C >> 2] = 32'h0043F433; // and  x8, x7, x4      # x8 = 64  (EX->EX x7, MEM->EX x4)
    end
```

Second Workload: Load-Use Hazards

```
    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // nop (addi x0, x0, 0)
            imem['h000 >> 2] = 32'h06400093; // addi x1, x0, 100    # base address = 100
            imem['h004 >> 2] = 32'h02A00113; // addi x2, x0, 42     # value = 42
            imem['h008 >> 2] = 32'h0020A023; // sw   x2, 0(x1)      # mem[100] = 42
            imem['h00C >> 2] = 32'h06300193; // addi x3, x0, 99     # value = 99
            imem['h010 >> 2] = 32'h0030A223; // sw   x3, 4(x1)      # mem[104] = 99
            imem['h014 >> 2] = 32'h0000A203; // lw   x4, 0(x1)      # x4 = 42  <load>
            imem['h018 >> 2] = 32'h000202B3; // add  x5, x4, x0     # x5 = x4  LOAD-USE stall
            imem['h01C >> 2] = 32'h0040A303; // lw   x6, 4(x1)      # x6 = 99  <load>
            imem['h020 >> 2] = 32'h404303B3; // sub  x7, x6, x4     # x7 = 57  LOAD-USE stall
    end
```

Third Workload: Branch Penalties

```
    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // nop (addi x0, x0, 0)
            imem['h000 >> 2] = 32'h00500093; // addi x1, x0, 5      # x1 = 5
            imem['h004 >> 2] = 32'h00500113; // addi x2, x0, 5      # x2 = 5
            imem['h008 >> 2] = 32'h00208663; // beq  x1, x2, +12    # taken -> flush IF/ID, ID/EX
            imem['h00C >> 2] = 32'h06300193; // addi x3, x0, 99     # SQUASHED
            imem['h010 >> 2] = 32'h05800213; // addi x4, x0, 88     # SQUASHED
            imem['h014 >> 2] = 32'h00100293; // addi x5, x0, 1      # x5 = 1  (branch target)
            imem['h018 >> 2] = 32'h00200313; // addi x6, x0, 2      # x6 = 2
    end
```

---

## Timing Report


---

## References

---