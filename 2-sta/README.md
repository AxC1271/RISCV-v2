# Static Timing Analysis: Sky130 ASIC (Post-Synthesis)

Timing analysis of the RV32I 5-stage pipeline using OpenSTA against the SkyWater Sky130 (130nm) open PDK. This document characterizes the timing bottlenecks of the standard-cell synthesized cached variant against the signed-off cacheless core.

## Setup

### OpenSTA + Docker

No Homebrew formula; building from source on macOS requires Xcode Tcl/Flex/Bison wars. Docker is simpler.

**Requirements:**
- Docker Desktop running (not just installed; `open -a Docker` if needed)
- Apple Silicon requires amd64 emulation (`--platform linux/amd64`)

```bash
docker pull openroad/opensta
docker run --platform linux/amd64 -it -v $(pwd):/data openroad/opensta
```

Drops into OpenSTA Tcl prompt (`%`). Exit with `exit` (not `quit`).

### Sky130 Liberty Files

```bash
pip install volare --break-system-packages
volare enable --pdk sky130 $(volare ls-remote --pdk sky130 | head -1)
cp "$(find ~/.volare -name 'sky130_fd_sc_hd__tt_025C_1v80.lib' | head -1)" .
```

`sky130_fd_sc_hd` = high-density cells. `tt_025C_1v80` = typical corner (25°C, 1.8V). For worst-case, swap to `ss_` (slow-slow setup) or `ff_` (fast-fast hold).

## Synthesis + STA Flow

Both designs use the same RTL sources (`../0-rtl/`); only the top module differs.

```bash
# Synthesize both variants
yosys -s synth_cacheless.ys  # → core_riscv_cacheless_synth.v
yosys -s synth_cached.ys     # → core_riscv_cached_synth.v

# Run timing analysis
docker run --platform linux/amd64 -it -v $(pwd):/data openroad/opensta
% source /data/sta_cacheless.tcl
% source /data/sta_cached.tcl
```

To find f_max, edit the `-period` value in `constraints.sdc` and re-source until WNS crosses zero.

---

## Analysis: Standard-Cell Caches vs. Core Signoff

### The Bottleneck with Synthesized Standard-Cell Caches

When synthesizing the multi-kilobyte cache arrays directly into standard cells (without compiled SRAM macros), OpenSTA reported severe setup violations:

```bash
Clock Period: 17.00 ns
WNS (Worst Negative Slack): -77.65 ns
TNS (Total Negative Slack): -3,777,731.00 ns
Data Arrival Time:          94.18 ns
Achievable f_max:          ~10.5 MHz
```
That's unusable for a 5-stage pipeline in 130nm. Reading the critical path, I found that:

```bash
Pin / Net                   Cap (pF)    Slew (ns)   Delay (ns)   Time (ns)
---------------------------------------------------------------------------
pc_reg/_132_/Q (dfxtp_1)    11.875      109.095     76.764       76.764
icache/_15714_/X (mux4_2)    0.002        2.787     11.792       88.556
...
pc_reg/_132_/D (dfxtp_1)     0.002        1.151      0.000       94.178
```

**Why Standard-Cell Caches Degraded Timing:**
- Yosys synthesizes both caches (I-cache which was 1 kB and D-cache which was 4 kB) into pure flip-flops instead of dedicated SRAM hard macros.

- Synthesizing the tag and data stores into standard cells mapped the memory into $>120,000$ flip-flops and combinational multiplexer trees.

### Cache vs. No-Cache Trade-off

Two architectural reasons justified the removal:

1. **No throughput benefit at 1-cycle memory.** Backing memory is on-chip BRAM with ~1-cycle latency. A cache hides *slow* memory; there's nothing slow to hide. Our IPC sweep confirmed it: the cacheless core actually *runs faster* because the cache still pays refill overhead on every first-touch miss.

2. **Small cores don't cache anyway.** Caches are more useful with larger CPUs where memory access is actually expensive; think reading from disk for example. For a bare-metal application, this is the honest architecture. My original intention was to port this to an FPGA, where BRAM latency is deterministic.

You could argue that I could've found a way to optimize timing, find the SRAM macros, redone the analysis, and achieved a much higher analysis. For my scope, I felt it was a rational engineering choice to remove them, save on area and power (especially considering the original application, the extra hardware usage provides little to no benefit), and keep the design simpler.

---

## Results: Cached vs. Cacheless

### Chip Area & Complexity (post-synth, Sky130)

| Metric | Cached | Cacheless | Ratio |
|--------|--------|-----------|-------|
| Logic Cells | ~37,000 | 9,385 | 0.25× |
| Flip-flops | >120,000 | 1,431 | 0.012× |
| Chip area (estimate) | 1.975 mm² | 0.0793 mm² | 0.04× |
| Max Slew | 109.1 ns | 10.53ns | 0.096× |

### Timing at 17ns Clock Period

| Metric | Cached | Cacheless | Delta |
|--------|--------|-----------|-------|
| **WNS (setup)** | **−77.65 ns** | **+0.55 ns** | **+78.20 ns ✓** |
| **TNS** | **−3,777,731 ns** | **0.00 ns** | **Clean Closure ✓** |
| Worst-path arrival | 94.18 ns | 15.91 ns | −78.27 ns |
| Hold slack | +0.17 ns | +0.43 ns | ✓ Both met |
| Implied f_max | ~10.5 MHz | ~58.8 MHz | **5.6× improvement** |

### Critical Path Shift

**With cache:** Program counter fanout to synthesized I-cache word-line read multiplexers ($11.875\text{ pF}$ load, $109.1\text{ ns}$ slew).

**Without cache:** External dmem_ready input distributing through hazard stall logic (hu) across pipeline registers:

```bash
Pin / Net                         Cap (pF)   Slew (ns)   Delay (ns)   Time (ns)
-------------------------------------------------------------------------------
dmem_ready (input port)           0.001      0.022       2.007        2.007
hu/_28_/Y (nand2b_1)              0.011      0.123       0.138        2.146
hu/_30_/Y (nand2_1)               1.535     10.532       7.867       10.012
hu/_49_/Y (a21oi_1)               0.004      1.495       2.397       12.409
idex/_385_/Y (nand2b_1)           0.464      4.577       3.413       15.822
idex/_763_/Y (nor2_1)             0.002      0.433       0.087       15.909
idex/_768_/D (dfxtp_1)            -          -           0.000       15.909
```

This is an expected pre-layout path: gate hu/_30_ drives a global pipeline stall line with high unbuffered fanout ($1.535\text{ pF}$), which is easily resolved by buffer tree insertion during physical placement.

---

### FPGA (Vivado + Routing Fabric)

| | Measured |
|---|----------|
| Cacheless, Basys3 Artix-7 | **85 MHz (11.76 ns)** |

Routing fabric is buffered everywhere; `dmem_ready` probably isn't even the critical path post-PnR.

---