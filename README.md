# RISCV-v2

## Overview 

### Harvard Architecture

<p align="center">
    <img src="./images/riscv-architecture.png" />
</p>

Recall that the standard Harvard architecture looks like the above diagram. This is the model that we will follow for my **RISCV-v2 processor**, albeit with a few differences. For the previous rendition, it lacked multi-stage pipelining, hazard detection, any tangible way to interface with other peripheral devices, and it wasn't programmable, meaning that instructions had to be pre-loaded and synthesized as BRAM, making the design extremely unmodular. The previous iteration lacked pipelining, which made it prone to data hazards.

This iteration features a hazard detection unit to find these types of hazards. This RISCV-v2 processor also aims to increase performance though multi-stage pipelining, forwarding/branch units, and two different L1 caches for instructions and data. 

---

## Design Process

### Peripherals + Memory Mapped I/O

To make the core more interesting, I wanted to add the possibility of writing instructions serially to it via UART, and I also want the PMOD ports to be usable for interfacing with any external device. The bootloader includes a UART receiver which writes byte-sized words into an asynchronous FIFO. On the read port, a word assembler groups 4 bytes into a single instruction before writing it to the instruction memory. This is all done before the PC is allowed to run so the instructions can be loaded beforehand.

### Cache Architecture 

For the specific I-caches and D-caches in this processor, I will be implementing a direct-mapped cache hierarchy with a writeback policy for the I-cache due to its sequential nature. As for the D-cache, I chose to implement it using a 2-way set associative cache architecture with an LRU policy. 


---

## Verification (UVM)

This project will be tested under UVM as two different systems: the RISC-V standalone core and the bootloader system. 

### RISC-V Core

### Bootloader

---

Thanks for stopping by!
