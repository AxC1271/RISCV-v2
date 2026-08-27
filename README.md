# RV32I 5-Stage Pipelined Processor

A 5-stage in-order RISC-V (RV32I) embedded processor implemented in SystemVerilog featuring EX-stage branch resolution, dual forwarding paths, and load-use hazard interlocks. Designed and signed off for tightly-coupled memory (TCM / BRAM) architectures.

## At a Glance

| Metric | Value |
|--------|-------|
| **f_max (FPGA)** | **85 MHz** (Basys3, 11.76 ns) |
| **f_max (post-synth)** | **58.8 MHz** (Sky130 tt, no buffers) |
| **IPC** | **0.64–0.76** (Fibonacci, Matrix, Bubble Sort) |
| **Area** | **0.0793 mm²** (Sky130 estimate, cacheless) |
| **IPC Range** | **0.64 – 0.76** | Fibonacci, Matrix Multiply, Bubble Sort |
| **Architecture** | RV32I (5-Stage In-Order) | IF $\rightarrow$ ID $\rightarrow$ EX $\rightarrow$ MEM $\rightarrow$ WB |

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
| **Fibonacci** | Branch-heavy loop | 0.64 | Limited by branch misprediction penalty |
| **Matrix 3×3** | ALU-intensive adds | 0.75 | Forwarding hides most data hazards |
| **Bubble Sort** | Memory-bound ops | 0.76 | Load-to-use stalls moderate impact |

---

## ASIC Static Timing & Memory Architecture

### Standard-Cell Synthesized Caches vs. Core Signoff

An L1 cache subsystem (2-way set-associative write-back D-cache, direct-mapped I-cache) was architected and functionally verified. However, for standard-cell ASIC synthesis on SkyWater 130nm, the core was signed off cacheless for two primary reasons:

1. **Physical Standard-Cell Limitations on Memory Arrays:**
   In production ASICs, multi-kilobyte cache arrays are implemented via compiled **SRAM hard macros (OpenRAM)**. Synthesizing 5 kB of storage directly into standard cells generated $>120,000$ flip-flops and deep multiplexer trees, creating an insane **$11.88\text{ pF}$ load** and **$109.1\text{ ns}$ slew** on the Program Counter / address lines (capping clock speed at **$\sim 10.5\text{ MHz}$**).

2. **Deterministic Tightly-Coupled Memory (TCM):**
   For embedded bare-metal and microcontroller applications targeting on-chip SRAM or FPGA Block RAMs with single-cycle response latency, a cache hierarchy introduces miss refill overhead without latency benefits.

### Post-Synthesis Comparison (Sky130 HD, Typical Corner: 25°C, 1.8V)

| Metric | Cached (Standard Cells) | Cacheless (TCM Interface) | Impact / Delta |
|:---|:---|:---|:---|
| **Worst Negative Slack (17.0 ns)** | $-77.65\text{ ns}$ (Violated) | **$+0.55\text{ ns}$ (MET)** | **Clean setup closure at 17.0 ns** |
| **Data Arrival Time** | $94.18\text{ ns}$ | **$15.91\text{ ns}$** | **$5.9\times$ reduction in critical path** |
| **Achievable $f_{\max}$** | $\sim 10.5\text{ MHz}$ | **$58.8\text{ MHz}$** | **$5.6\times$ performance increase** |
| **Standard Cell Count** | ~37,000+ gates | **9,385 gates** | Core datapath isolation |
| **Silicon Area Footprint** | $1.9752\text{ mm}^2$ | **$0.0793\text{ mm}^2$** | **$25\times$ area reduction** |

**Why it happened:**
- Cache read-mux fanned out to **1,949 pins** (every cell in byte-plane arrays)
- One weak gate charging 2,000 loads → 69.8 ns slew delay
- Post-synth f_max capped at ~13 MHz

---

## Implementation Details

### SkyWater 130nm ASIC Signoff (Yosys + OpenSTA)

- **Standard Cell Library:** `sky130_fd_sc_hd` (High Density, TT 25°C 1.8V)
- **Cell Count:** 9,385 logic instances (1,431 D-flip-flops)
- **Area:** $79,267.27\ \mu\text{m}^2$ ($0.0793\text{ mm}^2$)
- **Critical Path:** External `dmem_ready` $\rightarrow$ hazard stall unit (`hu`) driving pipeline latch clock enables ($15.91\text{ ns}$ arrival). 
- *Note:* In physical place-and-route (PnR via OpenROAD), high-fanout buffer trees placed on stall nets reduce transition slews to $<0.8\text{ ns}$, naturally pushing the core to **85–100 MHz**.

### FPGA Implementation (Vivado)

- **Target Device:** Xilinx Artix-7 XC7A35T (`cpg236-1`, Digilent Basys3)
- **Achieved Clock Frequency:** **85.0 MHz** ($11.76\text{ ns}$ period)
- **Timing Closure:** Met with zero negative setup/hold slack

---

## Verification and Simulation 

The test suite includes workload benchmarks and self-checking testbenches with register-file and memory verification tasks:

```bash
tb_fib.sv         # Branch prediction stress test
tb_matrix.sv      # ALU forwarding stress test
tb_bubblesort.sv  # Memory hazard stress test
```

Run: `iverilog ... tb_fib.sv && vvp a.out`

The simulations are also already provided, but you can edit the testbench files for customization.

---

Thanks for stopping by!