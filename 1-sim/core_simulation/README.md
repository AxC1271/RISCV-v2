# RISC-V Core (v2) — Pipelined RV32I Simulation

## Purpose

A 5-stage pipelined RV32I core (IF → ID → EX → MEM → WB) in SystemVerilog:

* Program Counter
* Register File (write-first bypass)
* Immediate Generator
* Control Unit (full RV32I decode, including LUI/AUIPC)
* Arithmetic Logic Unit
* Split L1 Instruction/Data Caches
* Hazard Unit + Forward Unit
* Branch Unit
* Pipeline Registers

The goal is a single core that runs real firmware — C compiled and linked at the reset vector, using `la`/`li`/`call`. That's why I implemented all of RV32I and not just a demo subset: `la` expands to `auipc + addi`, gcc emits sub-word loads/stores for `char`/`short`, and I wired EBREAK to a halt flag so a sim ends when the program says it's done instead of on some cycle count I picked.

> **Heads up on the caches:** they're in this simulation core and fully tested, but I left them **out of the synthesizable hardware build** on purpose. The reasoning and the data behind it are in [The cache decision](#the-cache-decision) below. Short version: at the memory speed my real hardware runs, the cache doesn't buy any throughput, and it's my worst timing path — so it stays a sim/verification piece, not silicon.

### Design decisions worth knowing before reading the RTL

**Jumps are done by the end of EX.** The link value (`pc+4`) gets muxed into the result before EX/MEM, and the redirect + flush happen in the same cycle. Nothing about "this was a jump" travels past EX — downstream it's just a value on its way to a register. Simpler than carrying jump signals the whole way down.

**Cache hits are combinational (zero wait).** The cache FSM only runs on a miss (writeback → allocate → back to idle); a hit comes straight out. One nice side effect: there's no in-flight fetch to squash when a branch redirects, because instruction data is only ever used against the *current* PC. That killed a whole class of squash logic I'd otherwise need.

**All stall logic lives in one place (`hazard_unit`).** Three cases, priority-ordered:

| Stall | Cause | What happens |
|---|---|---|
| `mem_stall` | D-cache miss | freeze the whole pipeline |
| `load_use_stall` | load in EX, next instr needs it | freeze PC + IF/ID, bubble into EX |
| `fetch_stall` | I-cache miss | freeze PC, bubble into ID |

The rule I care about: EX/MEM and MEM/WB only freeze on the full-pipeline stall. If you freeze the back half while the front half keeps moving, instructions run twice — that was the phantom re-execution bug in v1, and centralizing the control here is how I made sure it can't happen again.

**Sub-word loads/stores are handled in the core, not the cache.** Loads read the aligned word and do the byte/half extract + sign-extend in MEM; stores replicate the byte into the right lanes and drive a 4-bit `wstrb`. The cache itself stays word-based, which keeps it simple.

---

## What I tested

Self-checking testbench in Icarus Verilog. Three programs, picked with `+prog=N`:

**`prog=1` — the correctness run (32 checks).** One straight-line program that ends on EBREAK and hits everything: EX→EX and MEM→EX forwarding; a load-use pair (should be exactly one bubble); LUI/AUIPC checked against absolute addresses (this is what makes firmware `la` work); JAL link + two squashed instructions; JALR target `(rs1+imm)&~1` off an AUIPC base; a taken `beq` and a not-taken `bne`; the full sub-word set (two `sb`s into different byte lanes, then `lbu`/`lb`/`lh`/`sh`/`lw`/`lhu` against the mixed word `0xFFFF05FF`); `srai` on a negative number; `slt`/`sltu`; then final memory contents read straight out of the cache and backing memory.

**`prog=2` — forwarding + dirty-eviction stress (15 checks).** Store→load back-to-back, load-use feeding store data, and a loop with a 0x800 stride that lands on the same cache set every time so it's forced to evict dirty lines. The evicted data gets checked in backing memory to prove the writeback path actually ran.

**`prog=3` — cache-friendly hot loop (1 check).** A tight loop hammering one word that stays in the cache — one miss up front, then all hits. This one exists just for the IPC sweep.

## How I ran it

```
iverilog -g2012 -o riscv_sim *.sv
vvp riscv_sim +prog=1               # correctness
vvp riscv_sim +prog=1 +verbose      # + per-cycle pipeline monitor
vvp riscv_sim +prog=2               # eviction stress
vvp riscv_sim +prog=3 +lat=10       # hot loop, memory latency = 10 cycles
```

Register values are read out of `dut.rf.mem` and memory out of the cache arrays. All three pass (32 / 15 / 1).

One thing I want to flag: passing register values only tell you the *answer* was right, not that the pipeline got there the right way. So I also watched the `+verbose` monitor and checked the mechanics by hand:

* every redirect is followed by exactly two killed slots (the 2-cycle branch penalty),
* every load-use stall is exactly one bubble,
* nothing retires twice.

---

## Measuring IPC

Instructions per cycle = retired instructions ÷ total cycles. Sounds simple, but there's a catch: the pipeline is full of **bubbles** — empty slots inserted whenever it stalls or flushes — and a bubble looks identical to a real "do nothing" NOP. If I count those as retired instructions, my IPC is wrong.

So I tag every real instruction with a 1-bit `valid` flag when it's fetched, carry that flag down all five stages next to the instruction, and force it to 0 whenever a bubble gets made. At the end I only count the ones still flagged.

```systemverilog
// set when a real instruction is fetched...
assign if_valid = run && icache_ready;
// ...carried through ifid -> idex -> exmem -> memwb; each register
// zeroes valid on flush/reset (bubble = valid 0) and holds it on stall.
```

```systemverilog
if (cpu_enable && !debug_halted) begin
    cycle_count <= cycle_count + 1;
    // the !memwb_stall check matters: during a full freeze the WB
    // instruction just sits there, and counting wb_valid on its own
    // would re-count it every frozen cycle.
    if (dut.wb_valid && !dut.memwb_stall)
        retire_count <= retire_count + 1;
end
// IPC = real'(retire_count) / real'(cycle_count)
```

Counting starts when the CPU is enabled and stops the cycle it halts, so reset doesn't pollute the number.

### The memory-latency knob

My test memory used to always answer in one cycle. I added a `+lat=N` setting that makes it wait N cycles before answering, so I can pretend memory is slow and see how the core copes. The important part: **cache hits still answer instantly** — only misses wait — so this knob is exactly what shows whether the cache is pulling its weight.

### What I measured

| program | reuse | IPC @lat=1 | @lat=5 | @lat=10 | @lat=20 | got worse by |
|---|---|---|---|---|---|---|
| `prog=2` (thrash) | none | 0.331 | 0.116 | 0.064 | 0.034 | **9.8×** |
| `prog=3` (hot loop) | high | 0.544 | 0.465 | 0.394 | 0.302 | **1.8×** |

The last column is the interesting one — it's how much IPC dropped going from fast memory (lat=1) to slow memory (lat=20), i.e. first number ÷ last number.

The thrash program has no data reuse, so almost every access misses and eats the full memory latency. Make memory 20× slower and it runs ~9.8× worse — basically what a cacheless design would do. The hot loop reuses the same word every iteration, so after the first miss it never touches memory again; the same 20× slowdown only costs it 1.8×. That gap between 1.8 and 9.8 is the cache earning its keep — but only because the hot loop actually reuses data. No reuse, no benefit.

Worth being honest about the absolute numbers: these are short programs (37–206 instructions), so IPC is dragged down by pipeline fill and small loop counts. The *shape* across the sweep is what I trust, not the exact value. A 1000-iteration loop would give a cleaner steady-state number.

---

## The cache decision

The caches are the biggest piece of verification work in this core — three stall cases, load-use hazards, the miss FSMs, the dirty-eviction writeback path. That's the part I'm proud of, and it's the warm-up for the memory-ordering work I actually want to do. But once the goal changed from *"show the pipeline works"* to *"close timing on real hardware,"* the caches stopped being worth it, and the IPC sweep is why.

Look at the **lat=1** column — that's my real target, on-chip memory that answers in one cycle. Even the cache-friendly hot loop only hits **0.544 IPC**, and that ceiling isn't memory's fault — it's the load-use stall and the branch penalty in the loop. When memory is already single-cycle there are no misses to hide, so a cacheless core hits the same 0.544. The cache only helps when memory is slow *and* the program reuses data, and my hardware is neither.

On top of that, the cache costs me on timing. Post-synthesis STA against Sky130 (see [`../timing_analysis/`](../timing_analysis/)) put my worst path straight through the D-cache read logic — one gate driving a **1,949-fanout** net into the array read muxes. So it's not just neutral, it's my critical path.

Put together:

* **Timing:** the cache owns my critical path.
* **IPC at single-cycle memory:** no gain — a cacheless core matches it.

Something that's my worst timing path *and* buys me nothing at the speed I actually run is the easiest thing to cut. So the caches come out of the hardware build and the core becomes tightly-coupled memory, like a normal bare-metal MCU. They stay here in sim as the verification piece and the timing case study. I didn't cut them on a hunch — I built them, measured both sides, and the numbers said to.

---

## Static Timing Analysis

Full writeup in [`../timing_analysis/README.md`](../timing_analysis/). The short version of the first Sky130 run: WNS came back at −53.9 ns (~13 MHz), which is obviously not the real speed — it's a tooling artifact. One gate ate 57.7 of the 71.9 ns because it was driving ~1,949 loads (the D-cache read net above) with no buffering. Bare Yosys+ABC doesn't insert buffer trees; a real place-and-route flow does. FPGAs never show this because their routing is buffered everywhere — which is itself a real difference between the two flows, not just a different number. Hold passed fine (+0.42 ns). The honest speed number comes after place-and-route, with buffering and real wire delays.

The conditions I'm sweeping against:

$$t_{clk} + t_{skew} \geq T_{cq} + T_{comb} + T_{setup} \qquad t_{cq} + t_{comb} \geq t_{hold} + t_{skew}$$

The number that actually matters for comparing designs is **effective throughput = f_max × IPC**. A single-cycle core is IPC 1.0 by definition but its clock has to cover the entire datapath. Computing that product for both the cached and cacheless cores, on FPGA and Sky130, is what this whole project is building toward.

## Known limitations (on purpose)

* No misaligned loads/stores — base RV32I has no trap machinery, and gcc with `-march=rv32i` won't emit them anyway.
* ECALL is a NOP until I add CSRs + trap handling.
* Caches are blocking, one miss at a time.

## References

* *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*
* Patterson & Hennessy, *Computer Organization and Design, RISC-V Edition* — for the hazard/forwarding structure