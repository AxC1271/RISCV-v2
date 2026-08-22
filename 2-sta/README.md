# Static Timing Analysis: Sky130 ASIC (Post-Synthesis)

Timing analysis of the RV32I 5-stage pipeline using OpenSTA against the SkyWater Sky130 (130nm) open PDK. This document compares the cached variant (why it failed) against the cacheless design (why it succeeds).

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

## Why the Cached Design Failed

### The Problem: D-Cache Read-Index Mux

At 20ns clock constraint, the **cached core** returned:

```bash
WNS (Worst Negative Slack): −55.95 ns
TNS (Total Negative Slack): −321,252 ns
Implied f_max: ~13 MHz
```
That's unusable for a 5-stage pipeline in 130nm. Reading the critical path, I found that:

```bash
2.557 ns gate intrinsic delay
69.796 ns net capacitance delay
53.689 ns slew 
65.062 ns total arrival
```

I traced this back to the gate `_34649_`, which was a `o21ai_0` net driven by `dmem_wr_en` in my RTL.

**Why it fans out so much:**
- `dmem_wr_en` is high only during D-cache **WRITEBACK** state
- It selects which byte-plane's read-mux to enable
- That read-mux has **~1,949 pins** (every output of every cache cell)
- One weak gate charging two thousand loads = 69.8 ns of pure RC delay

A single fanout-critical path poisoned my entire design. This is the PRIMARY reason I chose to cut the caches out.

### Cache vs. No-Cache Trade-off

Two architectural reasons justified the removal:

1. **No throughput benefit at 1-cycle memory.** Backing memory is on-chip BRAM with ~1-cycle latency. A cache hides *slow* memory; there's nothing slow to hide. Our IPC sweep confirmed it: the cacheless core actually *runs faster* because the cache still pays refill overhead on every first-touch miss.

2. **Small cores don't cache anyway.** Caches are more useful with larger CPUs where memory access is actually expensive; think reading from disk for example. For a bare-metal application, this is the hoenst architecture.

---

## Results: Cached vs. Cacheless

### Chip Area & Complexity (post-synth, Sky130)

| Metric | Cached | Cacheless | Ratio |
|--------|--------|-----------|-------|
| Cells | ~37,000 | 9,385 | 0.25× |
| Flip-flops | 16,208 | 1,431 | 0.088× |
| Chip area (estimate) | 0.645 mm² | 0.074 mm² | 0.115× |
| Max fanout | 1,949 | 519 | 0.266× |

### Timing at 20ns Clock Period

| Metric | Cached | Cacheless | Delta |
|--------|--------|-----------|-------|
| **WNS (setup)** | **−55.95 ns** | **−10.22 ns** | **+45.73 ns ✓** |
| **TNS** | **−321,252 ns** | **−1,672 ns** | **+319,580 ns ✓** |
| Worst-path arrival | 73.95 ns | 30.03 ns | −43.92 ns |
| Hold slack | +0.42 ns | +0.43 ns | ✓ Both met |
| Implied f_max | ~13 MHz | ~33 MHz | **2.5× improvement** |

### Critical Path Shift

**With cache:** D-cache read-index mux (1,949 fanout)

**Without cache:** `dmem_ready` (input) → `mem_stall` logic (150 fanout)

```bash
Timing path 
0.000 v dmem_ready (in)
2.000 v dmem_ready (delay to arrival point)
12.979 ^ 06732/Y (o21ai_0)
14.019 v 07154/Y (o211ai_1)
1.035 ^ 10043/Y (a211oi_1)
─────────────────
30.033 ns total arrival

−10.22 ns slack (20ns period requirement)
```


This is a *real* microarchitectural path — memory says ready, unstall the entire pipeline in one cycle. Every load-stall design has this. At 150 fanout (vs. cache's 2,000), it's 5.5× less severe.

---

## Effective f_max by Corner

### Post-Synth (Yosys + ABC, no buffers)

| Corner | Cached | Cacheless |
|--------|--------|-----------|
| tt (25°C, 1.8V) | ~13 MHz | ~33 MHz |
| ss (worst-case setup) | ~10 MHz | ~25 MHz |
| ff (best-case setup) | ~18 MHz | ~45 MHz |


### FPGA (Vivado + Routing Fabric)

| | Measured |
|---|----------|
| Cacheless, Basys3 Artix-7 | **85 MHz (11.76 ns)** |

Routing fabric is buffered everywhere; `dmem_ready` probably isn't even the critical path post-PnR.

---

## If `dmem_ready` Binds After PnR (Future Mitigation)

The `dmem_ready` path is an artifact of bare synthesis (no buffers). Real PnR will handle it. But if it somehow still binds post-PnR, two options:

### Option 1: Let Place-and-Route Fix It (Recommended)

Add max-fanout constraint to the SDC:

```sdc
set_max_fanout 30 [get_nets dmem_ready]
```

`repair_design` automatically inserts buffers near load clusters. This is placement-aware and optimal.

### Option 2: Register the Stall Signal (RTL fix)

Latch `dmem_ready` and drive register enables from the registered copy:

```systemverilog
logic dmem_ready_ff;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dmem_ready_ff <= 1'b0;
    else dmem_ready_ff <= dmem_ready;
end

// Use dmem_ready_ff instead of dmem_ready for mem_stall
```

**Trade-off:** +1 cycle of memory stall latency, but breaks the fanout problem entirely.

**Note:** Manual signal duplication in RTL doesn't work—the synthesizer's `opt_merge` pass re-merges identical logic. Fanout balancing needs placement info the RTL doesn't have.

---