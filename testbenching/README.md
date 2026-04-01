# Setting up Icarus Verilog for Fast Testbenching

This file explains the infrastructure in how we are testbenching and validating the design of this `RISC-V v2 SoC` using Icarus Verilog before we use Vivado to synthesize and generate a working bitstream for an FPGA board.

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

Use the following Python script `converter.py` to turn RISC-V instructions into the binaries needed for testbenching metrics.

```Python
    def convert_riscv():

```