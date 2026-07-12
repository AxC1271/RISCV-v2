# Static Timing Analysis Setup

This is my setup for running static timing analysis on the AXI-Lite side of things against the
SkyWater Sky130 (130nm) open PDK — OpenSTA for the actual timing analysis, Volare to grab the
PDK's Liberty files. Same setup as `sta_cpu`, just pointed at a different target once there's
something real to synthesize. Writing this down so I don't have to re-figure out the Docker/PDK
setup every time I come back to it.

Right now I've only got the AXI-Lite master wrapper built — no slave wrappers, no arbitration, no
full interconnect yet. So there's nothing worth synthesizing or timing yet; this is just the
toolchain setup ready to go once there's an actual netlist to point it at. Check
`../verification/simulation_testbenches/axi_simulation/README.md` for where the RTL side actually
stands.

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

- `-v $(pwd):/data` — mounts wherever I'm running this from (should be `sta_axi/`) so netlists/SDC
  files are visible from inside
- `-v ~/.volare/volare:/pdk` — mounts the PDK so the Liberty files show up at `/pdk/...` without
  copying them anywhere

This drops into OpenSTA's Tcl prompt (`%`). To get out: `exit`, not `quit`. Also `clear` doesn't
work here — that's a shell thing, this is Tcl.

---

## Getting the Sky130 PDK (Volare)

Same PDK as `sta_cpu` — already downloaded once, don't need to redo this per-folder, just noting
it here too since this README should stand on its own.

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

---

## Loading the Liberty file

Inside the container, at the `%` prompt:

```
% read_liberty /pdk/sky130/versions/<version>/sky130B/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

Prints `1` back if it worked. That's just the library loaded though — still need an actual
synthesized netlist and an SDC file before there's anything real to check timing on, and right now
there isn't one yet.

---

## What's left

Two separate milestones here, not run yet either way — just tracking where the actual timing work
picks up.

**Once the AXI-Lite master wrapper is done and stable on its own:**
- Could technically synth + time just the master wrapper in isolation, same as the plan below.
  Probably not worth it though — same reasoning as skipping standalone STA on the ALU: a wrapper
  by itself, disconnected from anything it's arbitrating against, isn't going to show a meaningful
  critical path. Might do it anyway just to get a first data point once it's done, but not
  treating it as the real number.

**Once slave wrappers + arbitration exist and there's an actual interconnect:**
1. Synthesize the whole interconnect through Yosys, mapped to Sky130:
   ```tcl
   read_verilog -sv axi_interconnect.sv   # + all submodules
   synth -top axi_interconnect
   dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
   abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib
   write_verilog axi_interconnect_synth.v
   ```
2. Run OpenSTA against that netlist:
   ```
   % read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
   % read_verilog axi_interconnect_synth.v
   % link_design axi_interconnect
   % read_sdc constraints.sdc
   % report_checks
   % report_tns
   % report_wns
   ```

This second one is the actual real timing number — critical path through arbitration logic across
multiple masters/slaves is where AXI-Lite interconnects usually get timing-limited, not in a single
wrapper by itself.