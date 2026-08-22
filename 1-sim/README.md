# Simulation Infrastructure & IPC Analysis

This folder contains the testbenching and validation infrastructure for the RV32I 5-stage pipelined processor before synthesis/FPGA bring-up. It's used for rapid iteration on pipeline behavior, hazard detection, forwarding logic, and performance characterization across diverse workloads — all without relying on Vivado or synthesizing to hardware.

---

## Testbenches & Workloads

Three purpose-built benchmarks stress different pipeline aspects:

### Fibonacci — Branch-Heavy

Tests branch prediction penalty and loop misprediction recovery.

```
Loop body: add, addi, addi, addi, bne
Every iteration has a taken branch → 2-cycle penalty (no prediction)
Result: IPC ≈ 0.64 (branch overhead dominates)
```

### Matrix 3×3 Multiply — ALU-Heavy

Tests data forwarding and tight data dependencies.

```
Sequence of dependent adds: add x2, x1, x2 → add x2, x2, x3 → ...
Forwarding hides most latency
Result: IPC ≈ 0.75 (minimal stalls)
```

### Bubble Sort — Memory-Bound

Tests load-to-use stalls, store-to-load latency, and mixed control flow.

```
Loads followed by branches on loaded data
Store-to-load forwarding adds 1-2 cycles
Result: IPC ≈ 0.76 (memory hazards moderate impact)
```

## Performance Metrics

All testbenches include IPC instrumentation:

```systemverilog
longint cycle_count, retire_count;

always_ff @(posedge clk) begin
    if (cpu_enable && !debug_halted) begin
        cycle_count <= cycle_count + 1;
        if (dut.wb_valid && !dut.memwb_stall)
            retire_count <= retire_count + 1;
    end
end

$display("IPC = %0d / %0d = %0.4f", retire_count, cycle_count, 
         real'(retire_count) / real'(cycle_count));
```

The output at the end of every simulation will show something like:

```
cycles=14 retired=9 IPC=0.6429
```

This lets you compare performance across:
- Different hazard detection strategies
- With/without forwarding
- Different memory latencies (`+lat=1`, `+lat=2`, etc.)
- Pipeline stage configurations (in future: superscalar variants)

## Compile Source Code

To compile a Verilog testbench using Icarus Verilog:

**Single file:**
```bash
iverilog -g2012 -o fib_sim tb_fib.sv
```

**Multiple files (recommended):**
```bash
iverilog -g2012 -I ../0-rtl -o fib_sim tb_fib.sv ../0-rtl/core_riscv.sv ../0-rtl/alu.sv ...
```

**Or use a file list (what I used):**
```bash
# Create files.txt listing all sources
cat > files.txt << 'EOF'
tb_fib.sv
../0-rtl/core_riscv.sv
../0-rtl/alu.sv
../0-rtl/control_unit.sv
... (all RTL files)
EOF

iverilog -g2012 -o fib_sim -c files.txt
```

This generates a `.vvp` compiled file (the Icarus Verilog binary format).

---

## Run Simulation

Execute the compiled testbench:

```bash
vvp fib_sim
vvp matrix_sim
vvp bubblesort_sim
```
