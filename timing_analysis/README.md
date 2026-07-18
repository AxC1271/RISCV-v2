# Static Timing Analysis Setup

This is my setup for running static timing analysis on `core_riscv` against the SkyWater Sky130
(130nm) open PDK — OpenSTA for the actual timing analysis, Volare to grab the PDK's Liberty files.
Writing this down so I don't have to re-figure out the Docker/PDK setup every time I come back to
it. Real synthesis + timing runs against the full core happen once `core_riscv`'s RTL is done —
check `../verification/simulation_testbenches/core_simulation/README.md` for where that's at.

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

- `-v $(pwd):/data` — mounts wherever I'm running this from so netlists/SDC
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

To check it actually landed:

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

---

## Sky130nm ASIC Timing Report

First run at a 20 ns clock (50 MHz) reported WNS of **-53.89 ns** — an implied f_max of
~13 MHz, which would be absurd for a 5-stage pipeline in 130nm. Before writing that number
down, I believe it's worth reading what the path is actually made of, because it turns out the 
report is dominated by a single tool artifact, and finding it is more useful than the number itself.

```tcl
wns max -53.89
tns max -315960.06
Warning 168: sta.tcl line 10, unknown field nets.
Startpoint: _52015_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: dmem_wdata[29] (output port clocked by clk)
Path Group: clk
Path Type: max

     Cap     Slew    Delay     Time   Description
---------------------------------------------------------------------------
            0.000    0.000    0.000   clock clk (rise edge)
                     0.000    0.000   clock network delay (ideal)
            0.000    0.000    0.000 ^ _52015_/CLK (sky130_fd_sc_hd__dfxtp_1)
   0.177    1.630    1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
            1.630    0.000    1.402 ^ _33446_/A2 (sky130_fd_sc_hd__o21a_1)
   8.977   81.925   57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)
           81.925    0.000   59.123 ^ _41447_/S1 (sky130_fd_sc_hd__mux4_2)
   0.002    2.097    8.903   68.026 ^ _41447_/X (sky130_fd_sc_hd__mux4_2)
            2.097    0.000   68.026 ^ _41448_/B (sky130_fd_sc_hd__nand2_1)
   0.002    3.624    0.106   68.132 v _41448_/Y (sky130_fd_sc_hd__nand2_1)
            3.624    0.000   68.132 v _41449_/B (sky130_fd_sc_hd__nand2_1)
   0.002    0.717    0.662   68.794 ^ _41449_/Y (sky130_fd_sc_hd__nand2_1)
            0.717    0.000   68.794 ^ _41450_/B1 (sky130_fd_sc_hd__a21oi_1)
   0.002    6.189    0.070   68.864 v _41450_/Y (sky130_fd_sc_hd__a21oi_1)
            6.189    0.000   68.864 v _41457_/C1 (sky130_fd_sc_hd__a311oi_1)
   0.002    0.992    1.783   70.647 ^ _41457_/Y (sky130_fd_sc_hd__a311oi_1)
            0.992    0.000   70.647 ^ _41458_/B1 (sky130_fd_sc_hd__a311oi_1)
   0.002    1.764    0.080   70.727 v _41458_/Y (sky130_fd_sc_hd__a311oi_1)
            1.764    0.000   70.727 v _41596_/A3 (sky130_fd_sc_hd__o311ai_0)
   0.002    0.494    0.847   71.574 ^ _41596_/Y (sky130_fd_sc_hd__o311ai_0)
            0.494    0.000   71.574 ^ _41597_/B1 (sky130_fd_sc_hd__o31a_1)
   0.004    0.085    0.224   71.798 ^ _41597_/X (sky130_fd_sc_hd__o31a_1)
            0.085    0.000   71.798 ^ _41598_/B (sky130_fd_sc_hd__and2_0)
   0.000    0.054    0.096   71.894 ^ _41598_/X (sky130_fd_sc_hd__and2_0)
            0.054    0.000   71.894 ^ dmem_wdata[29] (out)
                             71.894   data arrival time

            0.000   20.000   20.000   clock clk (rise edge)
                     0.000   20.000   clock network delay (ideal)
                     0.000   20.000   clock reconvergence pessimism
                    -2.000   18.000   output external delay
                             18.000   data required time
---------------------------------------------------------------------------
                             18.000   data required time
                            -71.894   data arrival time
---------------------------------------------------------------------------
                            -53.894   slack (VIOLATED)


Warning 503: sta.tcl line 13, report_checks -group_count is deprecated. Use -group_path_count instead.
Startpoint: _52015_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: dmem_wdata[29] (output port clocked by clk)
Path Group: clk
Path Type: max

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 ^ _52015_/CLK (sky130_fd_sc_hd__dfxtp_1)
   1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
  57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)
   8.903   68.026 ^ _41447_/X (sky130_fd_sc_hd__mux4_2)
   0.106   68.132 v _41448_/Y (sky130_fd_sc_hd__nand2_1)
   0.662   68.794 ^ _41449_/Y (sky130_fd_sc_hd__nand2_1)
   0.070   68.864 v _41450_/Y (sky130_fd_sc_hd__a21oi_1)
   1.783   70.647 ^ _41457_/Y (sky130_fd_sc_hd__a311oi_1)
   0.080   70.727 v _41458_/Y (sky130_fd_sc_hd__a311oi_1)
   0.847   71.574 ^ _41596_/Y (sky130_fd_sc_hd__o311ai_0)
   0.224   71.798 ^ _41597_/X (sky130_fd_sc_hd__o31a_1)
   0.096   71.894 ^ _41598_/X (sky130_fd_sc_hd__and2_0)
   0.000   71.894 ^ dmem_wdata[29] (out)
           71.894   data arrival time

  20.000   20.000   clock clk (rise edge)
   0.000   20.000   clock network delay (ideal)
   0.000   20.000   clock reconvergence pessimism
  -2.000   18.000   output external delay
           18.000   data required time
-----------------------------------------------------------
           18.000   data required time
          -71.894   data arrival time
-----------------------------------------------------------
          -53.894   slack (VIOLATED)


Startpoint: _52015_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: _57391_ (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 ^ _52015_/CLK (sky130_fd_sc_hd__dfxtp_1)
   1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
  57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)
   8.902   68.025 ^ _37005_/X (sky130_fd_sc_hd__mux4_2)
   0.280   68.305 v _37015_/Y (sky130_fd_sc_hd__a221oi_1)
   2.001   70.305 ^ _37016_/Y (sky130_fd_sc_hd__a211oi_1)
   0.089   70.394 v _37120_/Y (sky130_fd_sc_hd__a311oi_1)
   0.862   71.257 v _37121_/X (sky130_fd_sc_hd__a311o_1)
   0.197   71.453 ^ _37147_/Y (sky130_fd_sc_hd__a31oi_1)
   0.119   71.573 v _41986_/Y (sky130_fd_sc_hd__mux2i_1)
   0.304   71.877 ^ _41987_/Y (sky130_fd_sc_hd__o21ai_0)
   0.104   71.981 v _41988_/Y (sky130_fd_sc_hd__a21oi_1)
   0.126   72.107 ^ _41990_/Y (sky130_fd_sc_hd__nor3_1)
   0.130   72.237 v _41991_/Y (sky130_fd_sc_hd__nor2_1)
   1.228   73.465 ^ _41992_/Y (sky130_fd_sc_hd__nand2_1)
   0.299   73.764 ^ _42123_/X (sky130_fd_sc_hd__o221a_1)
   0.000   73.764 ^ _57391_/D (sky130_fd_sc_hd__dfxtp_1)
           73.764   data arrival time

  20.000   20.000   clock clk (rise edge)
   0.000   20.000   clock network delay (ideal)
   0.000   20.000   clock reconvergence pessimism
           20.000 ^ _57391_/CLK (sky130_fd_sc_hd__dfxtp_1)
  -0.087   19.913   library setup time
           19.913   data required time
-----------------------------------------------------------
           19.913   data required time
          -73.764   data arrival time
-----------------------------------------------------------
          -53.850   slack (VIOLATED)


Startpoint: _52015_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: _57392_ (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 ^ _52015_/CLK (sky130_fd_sc_hd__dfxtp_1)
   1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
  57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)
   8.902   68.025 ^ _37005_/X (sky130_fd_sc_hd__mux4_2)
   0.280   68.305 v _37015_/Y (sky130_fd_sc_hd__a221oi_1)
   2.001   70.305 ^ _37016_/Y (sky130_fd_sc_hd__a211oi_1)
   0.089   70.394 v _37120_/Y (sky130_fd_sc_hd__a311oi_1)
   0.862   71.257 v _37121_/X (sky130_fd_sc_hd__a311o_1)
   0.197   71.453 ^ _37147_/Y (sky130_fd_sc_hd__a31oi_1)
   0.119   71.573 v _41986_/Y (sky130_fd_sc_hd__mux2i_1)
   0.304   71.877 ^ _41987_/Y (sky130_fd_sc_hd__o21ai_0)
   0.104   71.981 v _41988_/Y (sky130_fd_sc_hd__a21oi_1)
   0.126   72.107 ^ _41990_/Y (sky130_fd_sc_hd__nor3_1)
   0.130   72.237 v _41991_/Y (sky130_fd_sc_hd__nor2_1)
   1.228   73.465 ^ _41992_/Y (sky130_fd_sc_hd__nand2_1)
   0.299   73.764 ^ _42125_/X (sky130_fd_sc_hd__o221a_1)
   0.000   73.764 ^ _57392_/D (sky130_fd_sc_hd__dfxtp_1)
           73.764   data arrival time

  20.000   20.000   clock clk (rise edge)
   0.000   20.000   clock network delay (ideal)
   0.000   20.000   clock reconvergence pessimism
           20.000 ^ _57392_/CLK (sky130_fd_sc_hd__dfxtp_1)
  -0.087   19.913   library setup time
           19.913   data required time
-----------------------------------------------------------
           19.913   data required time
          -73.764   data arrival time
-----------------------------------------------------------
          -53.850   slack (VIOLATED)


Startpoint: _52015_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: _57395_ (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 ^ _52015_/CLK (sky130_fd_sc_hd__dfxtp_1)
   1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
  57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)
   8.902   68.025 ^ _37005_/X (sky130_fd_sc_hd__mux4_2)
   0.280   68.305 v _37015_/Y (sky130_fd_sc_hd__a221oi_1)
   2.001   70.305 ^ _37016_/Y (sky130_fd_sc_hd__a211oi_1)
   0.089   70.394 v _37120_/Y (sky130_fd_sc_hd__a311oi_1)
   0.862   71.257 v _37121_/X (sky130_fd_sc_hd__a311o_1)
   0.197   71.453 ^ _37147_/Y (sky130_fd_sc_hd__a31oi_1)
   0.119   71.573 v _41986_/Y (sky130_fd_sc_hd__mux2i_1)
   0.304   71.877 ^ _41987_/Y (sky130_fd_sc_hd__o21ai_0)
   0.104   71.981 v _41988_/Y (sky130_fd_sc_hd__a21oi_1)
   0.126   72.107 ^ _41990_/Y (sky130_fd_sc_hd__nor3_1)
   0.130   72.237 v _41991_/Y (sky130_fd_sc_hd__nor2_1)
   1.228   73.465 ^ _41992_/Y (sky130_fd_sc_hd__nand2_1)
   0.299   73.764 ^ _42133_/X (sky130_fd_sc_hd__o221a_1)
   0.000   73.764 ^ _57395_/D (sky130_fd_sc_hd__dfxtp_1)
           73.764   data arrival time

  20.000   20.000   clock clk (rise edge)
   0.000   20.000   clock network delay (ideal)
   0.000   20.000   clock reconvergence pessimism
           20.000 ^ _57395_/CLK (sky130_fd_sc_hd__dfxtp_1)
  -0.087   19.913   library setup time
           19.913   data required time
-----------------------------------------------------------
           19.913   data required time
          -73.764   data arrival time
-----------------------------------------------------------
          -53.850   slack (VIOLATED)


Startpoint: _52015_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: _57406_ (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: max

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 ^ _52015_/CLK (sky130_fd_sc_hd__dfxtp_1)
   1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
  57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)
   8.902   68.025 ^ _37005_/X (sky130_fd_sc_hd__mux4_2)
   0.280   68.305 v _37015_/Y (sky130_fd_sc_hd__a221oi_1)
   2.001   70.305 ^ _37016_/Y (sky130_fd_sc_hd__a211oi_1)
   0.089   70.394 v _37120_/Y (sky130_fd_sc_hd__a311oi_1)
   0.862   71.257 v _37121_/X (sky130_fd_sc_hd__a311o_1)
   0.197   71.453 ^ _37147_/Y (sky130_fd_sc_hd__a31oi_1)
   0.119   71.573 v _41986_/Y (sky130_fd_sc_hd__mux2i_1)
   0.304   71.877 ^ _41987_/Y (sky130_fd_sc_hd__o21ai_0)
   0.104   71.981 v _41988_/Y (sky130_fd_sc_hd__a21oi_1)
   0.126   72.107 ^ _41990_/Y (sky130_fd_sc_hd__nor3_1)
   0.130   72.237 v _41991_/Y (sky130_fd_sc_hd__nor2_1)
   1.228   73.465 ^ _41992_/Y (sky130_fd_sc_hd__nand2_1)
   0.284   73.749 ^ _41993_/X (sky130_fd_sc_hd__o221a_1)
   0.000   73.749 ^ _57406_/D (sky130_fd_sc_hd__dfxtp_1)
           73.749   data arrival time

  20.000   20.000   clock clk (rise edge)
   0.000   20.000   clock network delay (ideal)
   0.000   20.000   clock reconvergence pessimism
           20.000 ^ _57406_/CLK (sky130_fd_sc_hd__dfxtp_1)
  -0.087   19.913   library setup time
           19.913   data required time
-----------------------------------------------------------
           19.913   data required time
          -73.749   data arrival time
-----------------------------------------------------------
          -53.836   slack (VIOLATED)


Startpoint: _52066_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: _52066_ (rising edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: min

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 ^ _52066_/CLK (sky130_fd_sc_hd__dfxtp_1)
   0.291    0.291 ^ _52066_/Q (sky130_fd_sc_hd__dfxtp_1)
   0.097    0.389 ^ _34010_/X (sky130_fd_sc_hd__a21o_1)
   0.000    0.389 ^ _52066_/D (sky130_fd_sc_hd__dfxtp_1)
            0.389   data arrival time

   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000   clock reconvergence pessimism
            0.000 ^ _52066_/CLK (sky130_fd_sc_hd__dfxtp_1)
  -0.034   -0.034   library hold time
           -0.034   data required time
-----------------------------------------------------------
           -0.034   data required time
           -0.389   data arrival time
-----------------------------------------------------------
            0.423   slack (MET)
```

The critical path starts at an EX/MEM address flop and ends at the MEM/WB boundary — the
D-cache read path, which is where I expected the critical path to land. But the per-cell
breakdown shows one gate contributing 57.7 ns of the 71.9 ns total:

    0.177    1.630    1.402    1.402 ^ _52015_/Q (sky130_fd_sc_hd__dfxtp_1)
    8.977   81.925   57.721   59.123 ^ _33446_/X (sky130_fd_sc_hd__o21a_1)   <-- this

That's 8.977 pF of load capacitance and an 82 ns output slew on one `o21a_1`. Pulling the
cell out of the netlist explains it:

    sky130_fd_sc_hd__o21a_1 _33446_ (
        .A1(_02934_),
        .A2(dmem_wr_en),      // high exactly during the D-cache WRITEBACK state
        .B1(_13660_),
        .X(_13661_)
    );

    $ grep -c "_13661_" core_riscv_synth.v
    1949

`dmem_wr_en` is asserted precisely while the D-cache FSM is in WRITEBACK — so `_13661_` is
the cache's read-index select (`state == WRITEBACK ? writeback_addr : hit_addr`), fanning
out to **1,949 pins**: every read mux of the byte-plane data arrays. One minimum-strength
gate is being asked to charge two thousand gate inputs by itself, which explains the 82 ns slew.

---

## Basys3 FPGA Timing Report

<div align="center">
  <img src="../images/core-pipeline.png" />
</div>

---