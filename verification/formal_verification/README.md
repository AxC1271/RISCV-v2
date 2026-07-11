# Formal Verification

This folder documents the formal verification flow used across this repo's RTL, why it's used
where it's used, and a worked case study (the ALU) showing the flow catching a real discrepancy
end-to-end — including telling apart a genuine RTL bug from a tooling artifact.

## Why formal verification, and not just more testbenches

A 32-bit ALU with a 4-bit opcode has on the order of `2^68` possible input combinations.
Directed and randomized simulation testbenches can only ever sample a vanishing fraction of
that space. A missed edge case — signed comparison at `INT_MIN`/`INT_MAX`, a shift amount right
at the width boundary, an opcode encoding nobody thought to hit — can pass thousands of simulated
cycles and still be wrong.

Formal verification doesn't sample the input space; it proves a property holds (or finds a
counterexample) across *all* of it. For a module like this ALU — large input space, but
combinational and structurally simple (an adder, a shifter, a couple of comparators) — that's not
just theoretically nicer, it's actually tractable. A SAT/SMT solver handles bitvector arithmetic
and comparisons over a combinational block extremely well. That combination — large state space,
small well-structured logic — is the sweet spot where formal earns its cost.

It gets harder to justify as modules gain real sequential depth (FSMs, pipelines), where a bounded
proof only covers as many cycles as you bound it to, and unbounded correctness needs induction or
invariants instead of plain BMC. Combinational and shallow-sequential blocks are where this repo
leans on formal; deeper sequential logic gets a mix of formal properties and directed simulation.

## What formal verification actually is

Two things are involved, and they're not alternatives to each other:

- **SVA (SystemVerilog Assertions)** — the language you write properties in: `assert`, `assume`,
  `cover`. This is just syntax for stating a claim about the design.
- **SymbiYosys (`sby`)** — the tool that reads your RTL plus those SVA properties, elaborates them
  through Yosys, and hands them to a solver-based engine to actually check them.

The engine matters:

- **BMC (Bounded Model Checking)** — unrolls the design for *N* cycles and asks a SAT/SMT solver
  "does any reachable state within N cycles violate this assertion?" For a purely combinational
  module, N=1 is sufficient — there's no time axis, so BMC at depth 1 is functionally a single
  SAT call checking the assertions against every input combination at once.
- **k-induction / PDR** — needed once a proof has to hold for unbounded time, not just N cycles.
  Not used in the case study below, since the ALU has no state.

## When to reach for formal vs. a simulation testbench

| Use formal when... | Use simulation when... |
|---|---|
| The module is combinational or shallow-sequential | The module has deep sequential/temporal behavior best expressed as scenarios |
| The input space is large enough that directed vectors can't cover it | You're validating system-level integration, timing, or interaction with real peripherals |
| You want a completeness guarantee, not a sample | You need to observe waveforms/behavior over realistic traffic patterns |
| The property is a clean invariant ("res always equals X when opcode is Y") | The property is about performance, throughput, or emergent behavior across many cycles |

In practice this repo uses both: formal properties for the tight, provable claims about a module's
logic, and simulation testbenches for the surrounding integration and multi-cycle behavior formal
alone doesn't cleanly cover.

## Toolchain setup (macOS, this repo's setup)

This repo uses the free **OSS CAD Suite** — a prebuilt bundle of Yosys, SymbiYosys, and solvers
(Boolector, z3, Yices2), rather than trying to install each piece separately.

```bash
# check chip architecture
uname -m   # arm64 = Apple Silicon, x86_64 = Intel

# grab the latest darwin-arm64 (or darwin-x64) release URL
curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest \
  | grep "browser_download_url.*darwin-arm64" | cut -d '"' -f 4

# download using the URL printed above
curl -L -o oss-cad-suite.tgz "<paste URL here>"

xattr -d com.apple.quarantine oss-cad-suite.tgz   # harmless if this errors "no such xattr"
tar xzf oss-cad-suite.tgz
source oss-cad-suite/environment

sby --version   # should print something like "SBY v0.67"
```

Note: sourcing `environment` puts the suite's bundled tools (including its own Python and git) at
the front of `PATH` for that shell. Either source it manually per-session, or alias it
(`alias sbyenv='source ~/oss-cad-suite/environment'`) rather than sourcing it in every new shell,
to avoid it silently shadowing other toolchains.

**A real limitation to know going in:** the free OSS CAD Suite's Yosys build uses Yosys's own
SystemVerilog frontend, which has materially weaker SV support than a commercial parser — no real
`bind` statement, limited `inside {}` support, and (as the case study below shows) occasional
elaboration bugs on less common expression patterns. The practical workaround used throughout this
repo: keep assertions inline in the same module and the same procedural block as the logic they're
checking, rather than in separate bind files or separate `always` blocks, and prefer simple,
widely-supported constructs over exotic-but-legal SVA syntax.

## Running a check

Each verified module gets its own `.sby` config alongside the RTL:

```ini
[options]
mode bmc
depth 1              # 1 is valid only because this module is combinational

[engines]
smtbmc boolector

[script]
read_verilog -sv alu.sv
prep -top alu

[files]
alu.sv
```

```bash
sby -f alu.sby
```

On failure, `sby` writes a counterexample trace (`<top>/engine_0/trace.vcd`, plus a self-contained
`trace_tb.v` Verilog testbench reproducing the exact failing inputs) under a generated `<top>/`
directory — open the VCD in GTKWave/Surfer, or compile the dumped testbench directly against your
RTL with Icarus to see the failing case concretely.

## Case study: `core_formal/alu`

This is the ALU's actual verification history, kept here because the process is more instructive
than the final green checkmark.

**Setup.** `alu.sv` computes a 32-bit result from one of 10 opcodes (ADD, SUB, AND, OR, XOR, SLL,
SRL, SRA, SLT, SLTU). Formal properties are immediate assertions (`assert (...)`) living in the
*same* `always_comb` block as the logic, directly after the `case` statement — one assertion per
opcode, checking `res` equals the expected expression for that opcode, plus a default-case
assertion and a `cover` confirming the default branch is actually reachable and not vacuously true.

**BMC failure.** `sby -f alu.sby` returned `FAIL` on the SRA assertion, with a concrete
counterexample: `a = 0xfb7db6d0`, `b = 0xff8038c9` (shift amount `b[4:0] = 9`), `alu_opcode = SRA`.
Hand-computing the expected result independently gave `0xfffdbedb` — an entirely unremarkable
arithmetic shift, no overflow, no boundary condition.

**Diagnosis.** The assertion (`res == $signed(a) >>> b[4:0]`) was textually identical to the RTL
computing `res` for that branch, which made the failure suspicious on its face — a tautology
shouldn't be provably false. Rather than trust either tool's verdict blindly, the same exact
counterexample inputs were forced through the RTL in a standalone Icarus testbench. Icarus reported
`res = 0xfffdbedb` — matching the hand-computed expected value exactly. **The RTL was correct.**
The failure was an artifact of how Yosys's formal frontend elaborates an arithmetic right shift
(`>>>`) by a *variable* (non-constant) amount combined with a `$signed()` cast — a known weak spot
in Yosys's shift-handling for some builds, not a defect in the design.

**Fix.** Rather than continuing to fight that idiom, the SRA computation was rewritten using only
logical shift and bitwise complement, via the standard two's-complement identity for arithmetic
right shift of a negative number:

```systemverilog
ALU_SRA: res = a[31] ? ~((~a) >> b[4:0]) : (a >> b[4:0]);
```

Re-verified correct against Icarus first, then re-run through `sby` — clean `PASS` across all
assertions, with the `cover` property confirming reachability.

**The actual lesson.** A failing formal check is not automatically a design bug, and a passing
simulation is not automatically proof the formal tool was wrong — the two disagreed here, and the
way to resolve that disagreement was a third, independent source of ground truth (a minimal,
targeted Icarus testbench reproducing the exact counterexample), not intuition about which tool to
trust more. That same `$signed(x) >>> variable_shift` pattern shows up anywhere an arithmetic right
shift by a dynamic amount is needed — worth watching for the same class of issue in any future
shifter, including the RISC-V core's.