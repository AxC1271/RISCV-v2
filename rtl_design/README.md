# RISC-V Core — Synthesizable Build (cacheless)

This is the version of the core I'm actually putting on hardware: a 5-stage
pipelined RV32I core with the caches taken out. It's Harvard (separate
instruction and data memory) and talks to memory directly, no cache in
between.

If you're looking for the cache work — the write-back D-cache, the three
stall domains, the eviction/writeback verification — that all lives in the
[cached simulation core](../core_simulation/) along with the STA case study.
This folder is the trimmed-down design meant to close timing and run on an
FPGA. Same pipeline, same instruction set, minus the memory hierarchy I
didn't need.

## Why cacheless

Short version: at the memory speed this thing actually runs, the cache didn't
help — it hurt — and it was my worst timing path. So I pulled it.

I measured this instead of guessing. I added an IPC counter to the testbench
(a valid bit threaded down the pipeline so bubbles don't get counted as
retired instructions) and a knob to fake different memory latencies, then ran
the same programs on both the cached and cacheless cores:

| | fast memory (1-cycle) | | slow memory (20-cycle) | |
|---|---|---|---|---|
| program | cached | **cacheless** | cached | **cacheless** |
| mixed | 0.296 | **0.755** | — | — |
| no reuse (thrash) | 0.331 | **0.727** | 0.034 | **0.040** |
| high reuse (hot loop) | 0.544 | **0.574** | **0.302** | 0.040 |

Two things to read off this:

**When memory is single-cycle (my target — on-chip BRAM), cacheless wins
every time.** On the low-reuse programs it wins by ~2.5×. The reason is that
the cache still pays its refill cost on every first-touch (it pulls in a whole
line) even when the memory behind it answers in one cycle. If memory is
already fast, the cache isn't free — it's overhead I'm paying for nothing.

**The cache only wins in one square: slow memory *and* data reuse** (the hot
loop at 20-cycle latency, 0.302 vs 0.040 — 7.5×). That's the case caches
exist for, and it's not the case I'm in. My backing memory is on-chip and
single-cycle; there's no slow memory to hide.

On top of that, the cache was my critical path. Post-synthesis STA against
Sky130 traced the worst path straight through the D-cache read logic — one
gate driving a ~1,949-fanout net into the array read muxes. So the cache cost
me throughput at my operating point *and* owned my timing. Removing it was the
easiest win available. Full detail in [`../timing_analysis/`](../timing_analysis/).

> Note: the caches aren't deleted from the project — they stay in the
> simulation core as the verification/teaching piece. I just don't instantiate
> them in the build I synthesize.

## What actually changed from the cached core

Removing the caches was surgical, not a redesign — it only touched two
pipeline stages and some wiring, because the memory interface was already a
clean boundary:

* **IF stage** — the instruction cache is gone. The PC drives the fetch port
  directly (`imem_addr = pc_current`), and the instruction comes back on
  `imem_rdata`.
* **MEM stage** — the data cache is gone. The address drives the data port
  directly, and the sub-word store lanes (`wstrb`) are now exposed on the
  core's port for the memory to apply (the cache used to do that internally).
* **Peripheral bypass is gone entirely.** With a write-back cache I needed a
  separate uncached path so MMIO stores wouldn't sit dirty in the cache. No
  cache, no coherence problem, so that whole path disappears. Every access is
  now one uniform path, and address decode (RAM vs GPIO vs UART) moves out to
  the bus where it belongs — the core doesn't know peripherals exist.
* **The hazard unit didn't change.** I only rewired its inputs: `fetch_ready`
  now comes from `imem_ready` instead of the I-cache, and `mem_ready` from
  `dmem_ready` instead of the D-cache. The stall *logic* was always written
  against generic ready signals, so it didn't care that the cache went away.

Everything else — the ALU, register file, control unit, immediate generator,
branch unit, forward unit, all four pipeline registers — is the exact same
files, shared with the cached core. Nothing forked.

## Pipeline control

Three stall cases, same as before, just now driven by real memory wait states
instead of cache misses:

| stall | cause | behavior |
|---|---|---|
| `mem_stall` | data memory not ready | freeze the whole pipeline |
| `load_use_stall` | load in EX, next instr needs it | freeze PC + IF/ID, bubble into EX |
| `fetch_stall` | instruction memory not ready | freeze PC, bubble into ID |

With single-cycle memory, `fetch_stall` and `mem_stall` basically never fire —
they exist for when the backing memory needs wait states (a synchronous BRAM
would hold `ready` low for a cycle, and these paths absorb it). The one that
matters day-to-day is `load_use_stall`, which is a pipeline hazard, not a
memory thing.

## Memory interface

Clean Harvard, two ports:

* **Instruction fetch** — read-only: `imem_addr` out, `imem_rdata`/`imem_ready`
  in. Read-only because you don't write instruction memory during execution.
* **Data** — read/write with byte lanes: `dmem_addr`, `dmem_wdata`,
  `dmem_wstrb[3:0]`, `dmem_rd_en`, `dmem_wr_en` out; `dmem_rdata`/`dmem_ready`
  in. One access outstanding, held until `dmem_ready`.

The data port is what the bus hangs off of. Right now it expects single-cycle
memory (`ready` asserted immediately), which maps to distributed RAM on the
FPGA. Moving to synchronous BRAM would make loads 2-cycle (one `mem_stall` per
load) but let the memory be much bigger — that's a deliberate tradeoff for
later, and the stall path is already there to handle it.

## Testing

Same self-checking testbench and three programs as the cached core, run with
`+prog=N` and `+lat=N`:

```
iverilog -g2012 -o nc_sim *.sv
vvp nc_sim +prog=1            # correctness sweep (32 checks)
vvp nc_sim +prog=2            # forwarding + store/load stress (15 checks)
vvp nc_sim +prog=3 +lat=10    # hot loop, memory latency 10
```

All three pass (32 / 15 / 1). The correctness coverage is identical to the
cached core — full RV32I, forwarding, load-use, JAL/JALR, branches, sub-word
loads/stores — since the datapath is the same. The only thing that changed is
how memory is reached.

## Next steps

* **Wishbone bus** — a small Wishbone (B4 classic) interconnect hangs off the
  data port: one master adapter, an address decoder, and RAM / GPIO / UART
  slaves. I chose Wishbone over AXI-Lite on purpose: one handshake instead of
  five channels, no bursts, no multiple outstanding transactions — none of
  which I need for a single blocking core. AXI-Lite's separate channels buy
  concurrency this core can't generate, so I'd be paying the complexity and
  then serializing it right back.
* **FPGA prototype** — cacheless core + bus + `basys3_top` + constraints →
  bitstream, then send firmware over UART and blink an LED from my own core.
* **Effective throughput** — f_max × IPC on both FPGA and Sky130, now that the
  cache fanout path is gone and the design should close timing.

## Known limitations (on purpose)

* No misaligned loads/stores — base RV32I has no trap machinery, and gcc with
  `-march=rv32i` won't emit them anyway.
* ECALL is a NOP until I add CSRs + trap handling.
* Single access outstanding — the core is blocking by design.