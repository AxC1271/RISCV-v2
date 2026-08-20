# RV32I 5-Stage Pipelined Processor

A high-performance RISC-V embedded processor with hazard detection, data forwarding, and formal verification. Optimized for tight-coupled BRAM (MCU-style architecture, no caches).

## At a Glance

| Metric | Value |
|--------|-------|
| **f_max (FPGA)** | **85 MHz** (Basys3, 11.76 ns) |
| **f_max (post-synth)** | **33 MHz** (Sky130 tt, no buffers) |
| **IPC** | **0.64–0.76** (Fibonacci, Matrix, Bubble Sort) |
| **Area** | **0.074 mm²** (Sky130 estimate, cacheless) |
| **Formal proofs** | Clean on ALU, hazard, branch, regfile |

---

## Core Architecture 

- **ISA:** RV32I (32-bit integer ops only)
- **Issue Width:** 1 per cycle (in-order)
- **Memory:** Tight-coupled BRAM (1-cycle latency)
- **Registers:** 32×32, dual-read, single-write

---

## Performance Analysis

### IPC Benchmarks

| Benchmark | Type | IPC | Notes |
|-----------|------|-----|-------|
| **Fibonacci(30)** | Branch-heavy loop | 0.64 | Limited by branch misprediction penalty |
| **Matrix 3×3** | ALU-intensive adds | 0.75 | Forwarding hides most data hazards |
| **Bubble Sort** | Memory-bound ops | 0.76 | Load-to-use stalls moderate impact |

---

### Timing: Why Caches Were Removed

**tl;dr:** Removed D-cache because it became the critical path (1,949-fanout mux), not because the core was slow.

| Metric | Cached | Cacheless | Improvement |
|--------|--------|-----------|-------------|
| Post-synth WNS | −55.95 ns | −10.22 ns | **45.7 ns** |
| Post-synth f_max | ~13 MHz | ~33 MHz | **2.5×** |
| FPGA f_max | — | 85 MHz | — |
| End-to-end throughput | ~7 MIPS | ~19 MIPS | **2.6×** |

**Why it happened:**
- Cache read-mux fanned out to **1,949 pins** (every cell in byte-plane arrays)
- One weak gate charging 2,000 loads → 69.8 ns slew delay
- Post-synth f_max capped at ~13 MHz

---

## Verification & Quality

### Formal Proofs (SymbiYosys)

Clean BMC (bounded model checking) passes on:

- **ALU:** All arithmetic/logic opcodes (add, sub, and, or, sll, srl, sra, slt, sltu)
- **Hazard Unit:** Forwarding mux single-assignment, load-use blocking
- **Branch Logic:** Correct flush on misprediction, PC recovery
- **Register File:** No WAR/WAW hazards in concurrent R/W

---

### Simulation Testbenches

Three workload-specific benches + IPC instrumentation:

```bash
tb_fib.sv         # Branch prediction stress test
tb_matrix.sv      # ALU forwarding stress test
tb_bubblesort.sv  # Memory hazard stress test
```

Run: `iverilog ... tb_fib.sv && vvp a.out`

The simulations are also already provided, but you can edit the testbench files for customization.

---

## Implementation

### Synthesis (Sky130, post-synth)

- **Cells:** 9,385 gate instances
- **Flops:** 1,431 (32×32 regfile + pipeline latches)
- **Area:** ~0.074 mm² (Sky130 estimate)
- **Critical path:** `dmem_ready` → `mem_stall` (150 fanout, 17.7 ns slew)

Expected post-PnR: **50–80 MHz** (buffer insertion fixes fanout)

---

### FPGA (Vivado, Basys3 Artix-7)

- **Device:** xc7a35tcpg236
- **Frequency:** **85 MHz** (11.76 ns critical path)
- **Timing:** Met with positive slack
- **Status:** Functional (bootloader receive circuit issue unresolved; simulation verified)

---

Thanks for stopping by!