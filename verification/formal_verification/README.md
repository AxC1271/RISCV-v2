# Setting up SymbiYosys for Formal Verification

This folder has the infrastructure for formally verifying individual RTL modules using
SymbiYosys (`sby`) and Yosys, before those modules get integrated and simulated as part of the
full core in `../simulation_verification/`. If you want a worked example of the flow end-to-end,
check the `core_formal/alu` folder.

## Why Formal Here (Not Simulation)

This folder covers small, combinational, or shallow-sequential modules where the input space is
too large to meaningfully sample with a testbench, but the logic itself is simple enough that a
solver can reason over it exhaustively. A 32-bit ALU has `2^68` possible inputs — no directed or
randomized testbench gets meaningful coverage of that, but a SAT/SMT solver checking a bitvector
property across all of them is a fast, tractable proof.

That combination — large state space, small well-structured logic — is the sweet spot. It stops
being the right tool once a module gains real sequential depth (pipelines, multi-cycle FSMs,
anything with meaningful cross-cycle state): a bounded proof only covers as many cycles as you
unroll, unbounded proofs need hand-derived invariants to close, and full-system behavior (does the
core run this program correctly) isn't something formal checks directly at all. That's what
`../simulation_verification/` is for — see that folder's README for the flip side of this
argument.

Rule of thumb: single modules with a large input space and simple, provable logic → formal, here.
Full-system, multi-cycle, or performance-oriented verification → simulation, there.

---

## What's Actually Involved

Two separate things, not alternatives to each other:

- **SVA (SystemVerilog Assertions)** — the language properties are written in (`assert`, `assume`,
  `cover`).
- **SymbiYosys (`sby`)** — the tool that elaborates RTL + those properties through Yosys and hands
  them to a solver engine.

Engine used here: **BMC (Bounded Model Checking)**, depth 1 — valid because the modules verified so
far are purely combinational (no registers, so there's no time axis to unroll). Depth 1 BMC on a
combinational module is equivalent to one exhaustive SAT call over every possible input.
Sequential modules would need real BMC depth or k-induction instead — not yet needed here.

---

## Toolchain Setup

Uses the free **OSS CAD Suite** (bundled Yosys + SymbiYosys + solvers) rather than installing each
piece separately.

```
uname -m   # arm64 = Apple Silicon, x86_64 = Intel

curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest \
  | grep "browser_download_url.*darwin-arm64" | cut -d '"' -f 4

curl -L -o oss-cad-suite.tgz "<paste URL printed above>"

xattr -d com.apple.quarantine oss-cad-suite.tgz   # harmless if this errors
tar xzf oss-cad-suite.tgz
source oss-cad-suite/environment

sby --version
```

Sourcing `environment` puts the suite's bundled tools at the front of `PATH` for that shell — alias
it (`alias sbyenv='source ~/oss-cad-suite/environment'`) rather than sourcing it globally, so it
doesn't silently shadow other toolchains in every new terminal.

**Known limitation:** the free OSS CAD Suite's Yosys build has weaker SystemVerilog support than a
commercial parser — no real `bind` statement, limited `inside {}`, and occasional elaboration bugs
on less common expression patterns (see the ALU case study). Workaround used throughout this
folder: keep assertions inline in the same module and same procedural block as the logic they
check, and prefer simple constructs over exotic-but-legal SVA syntax.

---

## Running a Check

Each verified module gets its own `.sby` config next to the RTL:

```
[options]
mode bmc
depth 1

[engines]
smtbmc boolector

[script]
read_verilog -sv alu.sv
prep -top alu

[files]
alu.sv
```

```
sby -f alu.sby
```

On failure, `sby` writes a counterexample under a generated `<top>/` directory — a VCD
(`engine_0/trace.vcd`) and a self-contained Verilog testbench (`engine_0/trace_tb.v`) reproducing
the exact failing inputs, which can be compiled directly against the RTL with Icarus to
cross-check the failure independently of the formal tool.

---

## Case Study: `core_formal/alu`

Full writeup in `core_formal/alu/README.md`. Short version: BMC flagged a failure on the SRA
assertion; the RTL and the assertion used the same expression, which made the failure suspicious.
Forcing the exact counterexample inputs through an independent Icarus testbench showed the RTL was
correct — the failure was a Yosys elaboration bug on `$signed(a) >>> variable_shift`, not a design
bug. Fixed by rewriting SRA with the `~((~a) >> shamt)` identity instead. Worth remembering: a
failing formal check isn't automatically a design bug, and the way to resolve a disagreement
between tools is a third, independent source of ground truth — not intuition about which tool to
trust more.

---