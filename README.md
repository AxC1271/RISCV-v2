# RISCV-v2

A 5-stage pipelined RV32I processor in SystemVerilog, with hazard detection and forwarding, split L1 instruction/data caches *(studied in simulation; the synthesizable build is cacheless — [see below](#cache-architecture))*, and a formal + simulation verification flow spanning individual modules up through full-program execution.

Successor to a single-cycle v1 core built during last year; this iteration explores hazard handling, a memory hierarchy built to study, timing analysis, and a software stack designed to interface with the FPGA prototype.

---

## Key Features

- **ISA**: RV32I base integer instruction set
- **Pipeline**: 5-stage (IF / ID / EX / MEM / WB)
- **Hazard handling**: dedicated hazard detection unit covering fetch stalls, load-use stalls, and memory-wait stalls as a totally ordered freeze-set chain, plus forwarding to minimize stall cycles
- **Memory hierarchy** *(simulation model)*: direct-mapped I-cache, 2-way set-associative D-cache with LRU replacement — built and verified to study how a cache interacts with the pipeline, then **removed from the synthesizable design** because the D-cache was the critical path (see [Cache Architecture](#cache-architecture))
- **Peripherals** *(in progress)*: Wishbone interconnect with master/slave wrappers currently being written; bootloader, UART GPIO, SPI GPIO, timer peripheral, and RAM
- **Verified two ways**: formal verification (SymbiYosys/BMC) for individual modules with large, provable input spaces; Icarus-based simulation for full-CPU, multi-cycle, program-level behavior; see [Verification](#verification) below
- **Toolchain**: bare-metal C firmware with volatile-typed MMIO, custom linker script and startup assembly (`bare_metal/`), targeting this core directly rather than staying in simulation-only
- **Timing analysis**: static timing analysis for the CPU core (`timing_analysis/`) — cached and cacheless variants compared on Sky130

---

## Repository Structure

```
RISCV-v2/
├── bare_metal/                    # bare-metal C firmware, assembly, linker scripts
├── images/                        # diagrams referenced in this README
├── python_scripts/
│   ├── riscv_asm.py               # assembler: RISC-V instructions -> binaries for testbenching
│   └── firmware.py                # what I plan on using for transmitting code serially
├── rtl_design/                    # raw Verilog without the SVAs / testbench infrastructure
├── timing_analysis/               # static timing analysis through Xilinx and Sky130nm
├── verification/
│   ├── formal_verification/       # SymbiYosys/BMC proofs for individual modules (start here: core_formal/alu)
│   └── verilog_simulations/       # full-CPU RTL source + Icarus testbenches
├── constraints.xdc                # synthesis timing constraints
└── README.md                      # project summary + overview
```

---

## Overview

### Harvard Architecture

<p align="center">
    <img src="./images/riscv-architecture.png" />
</p>

*Credit: Patterson & Hennessy, [Computer Organization and Design: RISC-V Edition](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-812275-4)*

This is the model followed for **RISCV-v2**, with a few differences from the textbook diagram. The previous iteration (v1) lacked multi-stage pipelining, hazard detection, and any tangible way to interface with peripheral devices; instructions had to be pre-loaded and synthesized as BRAM, making the design extremely unmodular and prone to data hazards.

This iteration adds a hazard detection unit to catch those hazards, and aims to increase
performance through multi-stage pipelining, forwarding/branch units, and (in the simulation model) two separate L1 caches for instructions and data.

---

## Design Process

### Cache Architecture

For the I-cache and D-cache in this processor, I implemented a direct-mapped I-cache given its sequential access pattern, and a 2-way set-associative D-cache with an LRU replacement policy.

**Simulation vs. hardware — why the caches aren't synthesized.** I built both caches specifically to understand how a memory hierarchy interacts with the pipeline: the miss stalls, the writeback and eviction paths, how a D-cache miss freezes the whole pipeline. 
That's genuinely the point of having them here; it's an exercise in the mechanics of a real memory hierarchy.

But taking the design through synthesis made the tradeoff clear: the **D-cache was the critical path.** Its read logic drove a ~1,900-fanout net that dominated timing, and Sky130 static timing traced a −54 ns setup violation straight to it. On top of that, a cache only pays off by hiding *slow* memory — my backing memory is on-chip and single-cycle, so there was nothing to hide. IPC measurements across a memory-latency sweep confirmed it: at single-cycle latency the cacheless core is actually *faster*, because the cache still pays refill overhead with no reuse to amortize.

So the engineering decision was to make the **synthesizable design cacheless** — tightly-coupled memory wired straight to the core, the way a real bare-metal MCU works — while the cached version stays in simulation as the educational artifact it was built to be. Full timing + IPC analysis is in [`timing_analysis/`](timing_analysis/).

### Processor Architecture

Much like the old processor, but with instruction memory and data memory moved outside the
processor itself, so the core only encapsulates:

- Program Counter
- Register File
- Control Unit
- Arithmetic Logic Unit
- Branching Unit
- Forwarding Unit
- Hazard Detection Unit
- Immediate Generator
- Pipelining Registers

RTL source and the full-CPU testbenches both live under `verification/verilog_simulations/` — module-level testbenches aren't kept separately there; that folder's testbench targets the whole CPU, not individual units. Individual-module correctness
is instead handled formally, under `verification/formal_verification/`.

---

## Verification

Two complementary strategies, not one:

- **[`verification/formal_verification/`](verification/formal_verification/README.md)** — formal
  proofs (SymbiYosys + BMC) for individual modules where the input space is large but the logic is
  tractable enough to prove exhaustively. Includes the ALU (`core_formal/alu`, complete, with a
  documented case study of distinguishing a real RTL bug from a Yosys tooling artifact); the
  Wishbone bus wrappers are in progress alongside the interconnect itself.
- **[`verification/verilog_simulations/`](verification/verilog_simulations/README.md)** —
  Icarus Verilog testbenches for full-CPU, multi-cycle, program-level behavior that formal doesn't cover well (running real RISC-V programs, checking pipeline behavior over hundreds of cycles). This is also where the IPC instrumentation and the cache-vs-cacheless comparison live.

Each folder's README explains why that approach was chosen for that scope, and how to reproduce the
results.

---

## Status / Roadmap

- [x] 5-stage pipeline, hazard detection, forwarding
- [x] Split L1 I/D caches (direct-mapped I, 2-way set-associative D) — simulation model
- [x] Cacheless hardware variant (caches removed after they proved to be the critical path)
- [x] IPC / performance characterization (cache vs cacheless, across a memory-latency sweep)
- [x] Bare-metal C toolchain (linker script, startup assembly, MMIO)
- [x] Formal verification of individual modules (ALU complete)
- [x] Static timing analysis — Sky130 synthesis (cached vs cacheless); PnR closure + FPGA next
- [ ] Wishbone interconnect (master/slave wrappers) — in progress
- [ ] UART + SPI peripherals
- [ ] UART bootloader
- [ ] FPGA prototype (Basys3): bitstream + firmware over UART

---

## Credits + References

### Diagrams and Figures

- **Harvard Architecture Overview**: Based on the classic 5-stage RISC pipeline diagram from
  Patterson, D.A. and Hennessy, J.L. (2017).
- **Cache Associativity Diagrams**:
  [CS Illustrated](https://csillustrated.berkeley.edu/PDFs/handouts/cache-3-associativity-handout.pdf),
  UC Berkeley EECS Department

---

Thanks for stopping by!