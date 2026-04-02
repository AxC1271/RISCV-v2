# Setting up Icarus Verilog for Fast Testbenching

This folder simply has the infrastructure in how we are testbenching and validating the design of this `RISC-V v2 SoC` using Icarus Verilog before we use Vivado to synthesize and generate a working bitstream for an FPGA board. It's used for my own reference for rapid testbenching without relying on using Vivado on a VM. If you want detailed READMEs and testbench analysis on each individual component, check the `axi_mmio` and `core_riscv` folders for more information.

## Compile Source Code

To compile a Verilog file using Icarus Verilog, you run:

```
iverilog -g2012 -o hello_world design.v
```

For our purposes, since we are running an entire core with multiple moving parts, we would like to use a `.txt` file so we don't have to list each individual component on every simulation.

```
iverilog -g2012 -o hello_world -c files.txt
```

In both cases, you will generate a `.vvp` file called `hello_world` (or any name you prefer). 

## Run Simulation

Having just generated that `hello_world.vvp` file, just use the vvp runetime engine to execute the compiled file:

```
vvp hello_world
```

## Test Load Program

Use the Python script `riscv_asm.py` in the **python_scripts** folder to turn RISC-V instructions into the binaries needed for testbenching metrics.

