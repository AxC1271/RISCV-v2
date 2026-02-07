# RISCV-v2

## Overview 

### Harvard Architecture

<p align="center">
    <img src="./images/riscv-architecture.png" />
</p>

*Credit: Patterson & Hennessy, [Computer Organization and Design: RISC-V Edition](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-812275-4)*

Recall that the standard Harvard architecture looks like the above diagram. This is the model that we will follow for my **RISCV-v2 processor**, albeit with a few differences. For the previous rendition, it lacked multi-stage pipelining, hazard detection, any tangible way to interface with other peripheral devices, and it wasn't programmable, meaning that instructions had to be pre-loaded and synthesized as BRAM, making the design extremely unmodular. The previous iteration lacked pipelining, which made it prone to data hazards.

This iteration features a hazard detection unit to find these types of hazards. This RISCV-v2 processor also aims to increase performance though multi-stage pipelining, forwarding/branch units, and two different L1 caches for instructions and data. 

---

## Design Process

### Peripherals + Memory Mapped I/O

To make the core more interesting, I wanted to add the possibility of writing instructions serially to it via UART, and I also want the PMOD ports to be usable for interfacing with any external device. The bootloader includes a UART receiver which writes byte-sized words into an asynchronous FIFO. On the read port, a word assembler groups 4 bytes into a single instruction before writing it to the instruction memory. This is all done before the PC is allowed to run so the instructions can be loaded beforehand.

### Cache Architecture 

For the specific I-caches and D-caches in this processor, I will be implementing a direct-mapped cache hierarchy with a writeback policy for the I-cache due to its sequential nature. As for the D-cache, I chose to implement it using a 2-way set associative cache architecture with an LRU policy. As for why I decided to use those, you can check the `rtl-design/core_riscv/caches` directory for the technical explanation.

### Processor Architecture

I'm still implementing the RISC-V processor, much like my old processor. However, I've moved the instruction memory and data memory modules outside of the processor itself, so the core only encapsulates the following:
- Program Counter
- Register File
- Control Unit
- Arithmetic Logic Unit
- Branching Unit
- Forwarding Unit
- Hazard Detection Unit
- Immediate Generator
- Pipelining Registers

The memory and datapaths will be instantiated separately from the `RISC-V core` at the very top module.

---

## Verification (UVM)

This project will be tested under UVM as three different systems: the RISC-V standalone core, the AXI-interconnect, and the bootloader system. 

### RISC-V Core

### AXI-Interconnect

### Bootloader

---

## Video Demo

---

## Credits + References

### Diagrams and Figures

- **Harvard Architecture Overview**: Based on the classic 5-stage RISC pipeline diagram from Patterson, D.A. and Hennessy, J.L. (2017). 
  
- **Cache Associativity Diagrams**: 
  [CS Illustrated](https://csillustrated.berkeley.edu/PDFs/handouts/cache-3-associativity-handout.pdf), 
  UC Berkeley EECS Department

---

Thanks for stopping by!
