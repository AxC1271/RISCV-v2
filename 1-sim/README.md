# Setting up Icarus Verilog for Fast Testbenching

This folder simply has the infrastructure in how we are testbenching and validating the design of this `RISC-V v2 SoC` using Icarus Verilog before we use Vivado to synthesize and generate a working bitstream for an FPGA board. It's used for my own reference for rapid testbenching without relying on using Vivado on a VM. 
## Why Simulation Here (Not Formal)

This folder covers full-system and multi-cycle behavior — the core running real programs, Wishbone
transactions between modules, pipeline behavior over hundreds/thousands of cycles. Formal
verification doesn't fit well at this scale for a few concrete reasons:

- **State space explosion.** Formal proves properties by exhaustively reasoning over all reachable
  states. A single combinational ALU has a provable-in-seconds input space; an entire pipelined
  core with caches, a register file, and multiple in-flight instructions does not. BMC/k-induction
  either times out or needs so many hand-written invariants to make the proof tractable that it
  stops being faster than just simulating.
- **The properties themselves get harder to state.** "Does `res` equal the ISA-defined result for
  this opcode" is a clean, checkable claim. "Does the whole core correctly execute this RISC-V
  program and produce the right register/memory state at the end" is not something formal checks
  directly — you'd need to decompose it into dozens of per-module invariants, which is exactly
  what individual formal proofs are for.
- **This is where you actually want to see behavior, not just prove a property.** Waveforms,
  instruction traces, and IPC over a real program are the point of this folder — formal doesn't
  produce that; it just says pass/fail on a stated property.

Rule of thumb used throughout this repo: small, combinational, or shallow-sequential modules with
a large input space get formally verified in `../2-formal/` (see that folder's README
for the full argument and a worked case study). Full-system, multi-cycle, or performance-oriented
verification happens here, in simulation.

---

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

---

## Run Simulation

Having just generated that `hello_world.vvp` file, just use the vvp runtime engine to execute the compiled file:

```
vvp hello_world
```

---