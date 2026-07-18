# Static Timing Analysis Setup

This is my setup for running static timing analysis on `core_riscv` against the SkyWater Sky130
(130nm) open PDK — OpenSTA for the actual timing analysis, Volare to grab the PDK's Liberty files.
Writing this down so I don't have to re-figure out the Docker/PDK setup every time I come back to
it. Real synthesis + timing runs against the full core happen once `core_riscv`'s RTL is done —
check `../verification/simulation_testbenches/core_simulation/README.md` for where that's at.

---

## Why Sky130 and not just Vivado's STA

Vivado's timing report tells you if you'll meet timing on the specific FPGA you're targeting —
important for actually getting a bitstream, but it's tied to Xilinx's routing model, not a real
fab process. OpenSTA + Sky130 answers a different question: how would this actually time on a real
130nm ASIC process. Feels like the more natural fit for me too, given the HackerFab tapeout
background. Doing both, not one instead of the other.

---

## Getting OpenSTA running (Docker)

There's no Homebrew formula for it, and building from source on Mac means fighting Xcode's
Tcl/Flex/Bison versions, so Docker was just easier.

Heads up: `openroad/opensta` doesn't have an arm64 build, so on Apple Silicon it needs to be forced
onto amd64 emulation or it just fails with `no matching manifest for linux/arm64/v8`. Also, Docker
Desktop actually needs to be running, not just installed — `open -a Docker` if it's not.

```bash
docker pull openroad/opensta
docker run --platform linux/amd64 -it \
  -v $(pwd):/data \
  -v ~/.volare/volare:/pdk \
  openroad/opensta
```

- `-v $(pwd):/data` — mounts wherever I'm running this from (should be `sta_cpu/`) so netlists/SDC
  files are visible from inside
- `-v ~/.volare/volare:/pdk` — mounts the PDK so the Liberty files show up at `/pdk/...` without
  copying them anywhere

This drops into OpenSTA's Tcl prompt (`%`). To get out: `exit`, not `quit`. Also `clear` doesn't
work here — that's a shell thing, this is Tcl.

---

## Getting the Sky130 PDK (Volare)

Didn't want to build `open_pdks` from source — that's a multi-hour build for stuff I don't even
need. Volare just grabs prebuilt PDK releases.

```bash
pip install volare --break-system-packages
volare enable --pdk sky130 $(volare ls-remote --pdk sky130 | head -1)
```

Downloads to `~/.volare/volare/sky130/versions/<version>/` — yes, `volare` shows up twice in that
path, easy to miss. There are two PDK variants in there, `sky130A` (old) and `sky130B` (current) —
going with `sky130B` since that's the default everywhere else in the OpenLane/Volare world.

Check it actually landed:

```bash
find ~/.volare -name "sky130_fd_sc_hd__tt_025C_1v80.lib"
```

`sky130_fd_sc_hd` is the high-density standard cell library. `tt_025C_1v80` is the typical corner
(25°C, 1.8V) — fine for a first pass. If I want worst-case setup / best-case hold later, the
`ss_`/`ff_` corner `.lib` files are sitting right next to this one.

One gotcha I ran into: `pip` at `/opt/homebrew/bin/pip` is a broken symlink pointing at a Homebrew
Python that got removed at some point (`brew reinstall python@3.11` should fix it). Still worked
for me because I was inside the OSS CAD Suite environment, which has its own `pip` that isn't
broken — just don't want to be confused by it failing in a plain terminal later.

---

## Loading the Liberty file

Inside the container, at the `%` prompt:

```
% read_liberty /pdk/sky130/versions/<version>/sky130B/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

Prints `1` back if it worked. That's just the library loaded though — still need an actual
synthesized netlist and an SDC file before there's anything real to check timing on.

---

## What's left once `core_riscv` is actually ready

Haven't run this part yet, just writing down the plan so I know where I left off.

1. Synthesize the whole core through Yosys, mapped to Sky130:
   ```tcl
   read_verilog -sv core_riscv.sv   # + all submodules
   synth -top core_riscv
   dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
   abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
   write_verilog core_riscv_synth.v
   ```
2. Run OpenSTA against that netlist:
   ```
   % read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
   % read_verilog core_riscv_synth.v
   % link_design core_riscv
   % read_sdc constraints.sdc
   % report_checks
   % report_tns
   % report_wns
   ```

Not bothering with STA on individual modules like the ALU or branch unit by themselves — without a
real clock context around them they only show raw propagation delay, not actual setup/hold slack.
What actually matters is whether a full pipeline stage fits inside the clock period once everything
is wired together, and that only means something once the real core exists.

---

## Basys3 FPGA Timing Report

<div align="center">
  <img src="../images/core-pipeline.png" />
</div>

---

## Sky130nm ASIC Timing Report