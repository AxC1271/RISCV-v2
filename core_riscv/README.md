# RISC-V Core

## Purpose

This is a single-core RISC-V core which performs pure computations, with:
* Program Counter
* Register File
* Immediate Generator
* Control Unit
* Arithmetic Logic Unit
* Data/Instruction Memory
* Data/Instruction Caches
* Hazard/Forwarding Unit
* Branch Unit
* Pipeline Registers

The overall scope of this project is to implement a single-core processor that can interact with peripherals and be programmed using a serial Python transmitter. For the testbench of this core, we are verifying a couple of parameters:

* Whether or not instructions write back correctly due to the pipeline
* Checking for pipeline hazards (RAW hazards, load-use hazards)
* Checking penalties for misses (ALU data hazards, branch penalties)

We will run discrete testbenches that will specifically test for these edge cases. Compared to a single-cycle processor, it's essential that we check the handling of data hazards and measure average IPC across randomized loads to compare performance to my older project RISC-V v1. 


---

## RTL Code

Here's the structural RTL implementation of the RISC-V core:

```SystemVerilog
module core_riscv (
    input  logic clk,
    input  logic rst_n,
    
    // cpu control (from system)
    input  logic cpu_enable, // discern boot vs. normal operation
    
    output logic [31:0] imem_addr, // addr to fetch from
    output logic        imem_req, // req signal
    input  logic [31:0] imem_rdata, // instr data
    input  logic        imem_ready, // memory ready (cache miss handling)
    
    output logic [31:0] dmem_addr, // address for load/store
    output logic [31:0] dmem_wdata, // data to write (for stores)
    output logic        dmem_rd_en, // read enable (loads)
    output logic        dmem_wr_en, // write enable (stores)
    output logic [2:0]  dmem_size, // transfer size (byte, half, word)
    input  logic [31:0] dmem_rdata, // data read from memory
    input  logic        dmem_ready, // memory ready
    
    // debug interface
    output logic [31:0] debug_pc, // curr pc value
    output logic [31:0] debug_instr, // curr instruction
    output logic [31:0] debug_reg_data, // register file debug readout
    output logic debug_halted // cpu halted (for debugging)
);

    
    // program counter
    logic [31:0] pc_current, pc_next;
    logic        pc_stall;
    
    // pipeline register (if/id)
    logic [31:0] if_pc, id_pc, ex_pc, mem_pc, wb_pc;
    logic [31:0] if_instr, id_instr, ex_instr, mem_instr, wb_instr;

    // ex stage signals (from id/ex register)
    logic [31:0] ex_rs1_data, ex_rs2_data, ex_immediate;
    logic [4:0]  ex_rs1, ex_rs2, ex_rd;
    logic [3:0]  ex_alu_op;
    logic        ex_alu_src, ex_mem_read, ex_mem_write;
    logic        ex_reg_write, ex_mem_to_reg;

    // mem stage signals (from ex/mem register)
    logic [31:0] mem_alu_result, mem_rs2_data;
    logic [4:0]  mem_rd;
    logic        mem_zero_flag;
    logic        mem_mem_read, mem_mem_write;
    logic        mem_reg_write, mem_mem_to_reg;

    // wb stage signals (from mem/wb register)
    logic [31:0] wb_alu_result, wb_read_data;
    logic [4:0]  wb_rd;
    logic        wb_reg_write, wb_mem_to_reg;
    
    // register file signals
    logic [31:0] rf_rs1_data, rf_rs2_data;
    logic [31:0] rf_wr_data;
    logic [4:0]  rf_wr_addr;
    logic        rf_wr_en;
    
    // alu signals
    logic [31:0] alu_a, alu_b, alu_result;
    logic [3:0]  alu_op;
    logic        alu_zero;
    
    // control signals
    logic        reg_write, mem_read, mem_write;
    logic        mem_to_reg, alu_src;
    logic        branch, jump;
    
    // hazard detection signals
    logic        stall, flush;
    logic [1:0]  forward_a, forward_b;
    
    // branch signals
    logic        branch_taken;
    logic [31:0] branch_target;
    
    // immediate value
    logic [31:0] immediate;
    
    // i-cache interface
    logic [31:0] icache_cpu_addr;
    logic        icache_cpu_req;
    logic [31:0] icache_cpu_rdata;
    logic        icache_cpu_ready;

    // instantiate submodules here

    instr_cache icache (
        .clk(clk),
        .rst_n(rst_n),
        
        // cpu side (from if stage)
        .cpu_addr(icache_cpu_addr),
        .cpu_req(icache_cpu_req),
        .cpu_rdata(icache_cpu_rdata),
        .cpu_ready(icache_cpu_ready),
        
        // memory side (to external instruction memory)
        .mem_addr(imem_addr),
        .mem_req(imem_req),
        .mem_rdata(imem_rdata),
        .mem_ready(imem_ready)
    );
    
    logic [31:0] dcache_cpu_addr;
    logic [31:0] dcache_cpu_wdata;
    logic        dcache_cpu_rd_en;
    logic        dcache_cpu_wr_en;
    logic [31:0] dcache_cpu_rdata;
    logic        dcache_cpu_ready;
    
    data_cache dcache (
        .clk(clk),
        .rst_n(rst_n),
        
        // cpu side (from mem stage)
        .cpu_addr(dcache_cpu_addr),
        .cpu_wdata(dcache_cpu_wdata),
        .cpu_rd_en(dcache_cpu_rd_en),
        .cpu_wr_en(dcache_cpu_wr_en),
        .cpu_rdata(dcache_cpu_rdata),
        .cpu_ready(dcache_cpu_ready),
        
        // memory side (to external data memory)
        .mem_addr(dmem_addr),
        .mem_wdata(dmem_wdata),
        .mem_rd_en(dmem_rd_en),
        .mem_wr_en(dmem_wr_en),
        .mem_rdata(dmem_rdata),
        .mem_ready(dmem_ready)
    );
    
    program_counter pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_in(pc_next),
        .pc_out(pc_current)
    );
    
    // program counter control logic
    always_comb begin
        if (!cpu_enable) begin
            pc_next = 32'h0;  // hold at 0 when disabled
        end else if (branch_taken) begin
            pc_next = branch_target;
        end else if (pc_stall) begin
            pc_next = pc_current;  // stall for cache miss or hazard
        end else begin
            pc_next = pc_current + 4;
        end
    end
    
    // instruction fetch
    assign icache_cpu_addr = pc_current;
    assign icache_cpu_req = cpu_enable && !pc_stall;
    assign if_instr = icache_cpu_rdata;
    assign if_pc = pc_current;
    
    // stall on cache miss
    assign pc_stall = !icache_cpu_ready || !dcache_cpu_ready || stall;
    
    ifid_register ifid (
        .clk(clk),
        .rst_n(rst_n),
        .stall(pc_stall),
        .flush(flush),
        .if_pc(if_pc),
        .if_instruction(if_instr),
        .id_pc(id_pc),
        .id_instruction(id_instr)
    );
    
    register_file rf (
        .clk(clk),
        .rd_addr1(id_instr[19:15]),  
        .rd_addr2(id_instr[24:20]), 
        .wr_addr(rf_wr_addr),
        .wr_data(rf_wr_data),
        .wr_en(rf_wr_en),
        .rd_data1(rf_rs1_data),
        .rd_data2(rf_rs2_data)
    );
    
    control_unit cu (
        .opcode(id_instr[6:0]),
        .funct3(id_instr[14:12]),
        .funct7(id_instr[31:25]),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .branch(branch),
        .jump(jump)
    );
    
    immediate_gen imm_gen (
        .instruction(id_instr),
        .immediate(immediate)
    );
    
    hazard_unit hazard (
        .id_rs1(id_instr[19:15]),
        .id_rs2(id_instr[24:20]),
        .ex_rd(ex_rd),
        .ex_mem_read(ex_mem_read),
        .stall(stall),
        .flush_id_ex(flush)
    );
    
    branch_unit branch_unit (
        .rs1_data(rf_rs1_data),
        .rs2_data(rf_rs2_data),
        .pc(id_pc),
        .immediate(immediate),
        .branch(branch),
        .jump(jump),
        .funct3(id_instr[14:12]),
        .branch_taken(branch_taken),
        .branch_target(branch_target)
    );
    
    idex_register idex (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),

        .id_pc(id_pc),
        .id_rs1_data(rf_rs1_data),
        .id_rs2_data(rf_rs2_data),
        .id_immediate(immediate),
        .id_rs1(id_instr[19:15]),
        .id_rs2(id_instr[24:20]),
        .id_rd(id_instr[11:7]),

        .id_alu_op(alu_op),
        .id_alu_src(alu_src),
        .id_mem_read(mem_read),
        .id_mem_write(mem_write),
        .id_reg_write(reg_write),
        .id_mem_to_reg(mem_to_reg),

        .ex_pc(ex_pc),
        .ex_rs1_data(ex_rs1_data),
        .ex_rs2_data(ex_rs2_data),
        .ex_immediate(ex_immediate),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .ex_rd(ex_rd),

        .ex_alu_op(ex_alu_op),
        .ex_alu_src(ex_alu_src),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_reg_write(ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg)
    );
    
    forward_unit fwd (
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .mem_rd(mem_rd),
        .mem_reg_write(mem_reg_write),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // rs2 forwarding
    logic [31:0] ex_rs2_forwarded;
    always_comb begin
        case (forward_b)
            2'b00:   ex_rs2_forwarded = ex_rs2_data;
            2'b01:   ex_rs2_forwarded = rf_wr_data;
            2'b10:   ex_rs2_forwarded = mem_alu_result;
            default: ex_rs2_forwarded = ex_rs2_data;
        endcase
    end

    // alu input a
    always_comb begin
        case (forward_a)
            2'b00:   alu_a = ex_rs1_data;
            2'b01:   alu_a = rf_wr_data;
            2'b10:   alu_a = mem_alu_result;
            default: alu_a = ex_rs1_data;
        endcase
    end

    // alu input b
    assign alu_b = ex_alu_src ? ex_immediate : ex_rs2_forwarded;
    assign alu_op = ex_alu_op;
    
    arith_logic_unit alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero_flag(alu_zero)
    );
    
    exmem_register exmem (
        .clk(clk),
        .rst_n(rst_n),
        
        .ex_alu_result(alu_result),
        .ex_rs2_data(ex_rs2_forwarded),
        .ex_rd(ex_rd),
        .ex_zero_flag(alu_zero),

        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_reg_write(ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg),

        .mem_alu_result(mem_alu_result),
        .mem_rs2_data(mem_rs2_data),
        .mem_rd(mem_rd),
        .mem_zero_flag(mem_zero_flag),

        .mem_mem_read(mem_mem_read),
        .mem_mem_write(mem_mem_write),
        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg)
    );
    
    // d-cache interface (during mem stage)
    assign dcache_cpu_addr = mem_alu_result;
    assign dcache_cpu_wdata = mem_rs2_data;
    assign dcache_cpu_rd_en = mem_mem_read;
    assign dcache_cpu_wr_en = mem_mem_write;
    assign dmem_size = 3'b010; 
    
    memwb_register memwb (
        .clk(clk),
        .rst_n(rst_n),
        
        .mem_alu_result(mem_alu_result),
        .mem_read_data(dcache_cpu_rdata),
        .mem_rd(mem_rd),

        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),

        .wb_alu_result(wb_alu_result),
        .wb_read_data(wb_read_data),
        .wb_rd(wb_rd),

        .wb_reg_write(wb_reg_write),
        .wb_mem_to_reg(wb_mem_to_reg)
    );
    
    // writeback logic
    assign rf_wr_data = wb_mem_to_reg ? dcache_cpu_rdata : wb_alu_result;
    assign rf_wr_addr = wb_rd;
    assign rf_wr_en = wb_reg_write && cpu_enable;
    
    // assign the rest of the debug interface
    assign debug_pc = pc_current;
    assign debug_instr = id_instr;
    assign debug_reg_data = rf_rs1_data;
    assign debug_halted = !cpu_enable;

endmodule
```

---

## Test Assembly Programs

The first assembly program we will use will include a bunch of instructions that should trigger RAW hazards. We want to see if the writeback uses the correct value and that the CPU doesn't stall for the pipeline because of the forwarding logic.

```s
# RAW hazard / forwarding test
# Each instruction reads a register written by the immediately preceding instruction.
# With correct EX->EX and MEM->EX forwarding, zero stalls should occur.

_start:
    addi  x1, x0, 10      # x1 = 10
    addi  x2, x1, 5       # x2 = x1 + 5 = 15    (EX->EX forward on x1)
    add   x3, x1, x2      # x3 = x1 + x2 = 25   (EX->EX on x2, MEM->EX on x1)
    slli  x4, x3, 2       # x4 = x3 << 2 = 100  (EX->EX forward on x3)
    sub   x5, x4, x1      # x5 = x4 - x1 = 90   (EX->EX on x4, MEM->EX on x1)
    xor   x6, x5, x2      # x6 = x5 ^ x2 = 85   (EX->EX on x5, MEM->EX on x2)
    or    x7, x6, x3      # x7 = x6 | x3 = 93   (EX->EX on x6, MEM->EX on x3)
    and   x8, x7, x4      # x8 = x7 & x4 = 64   (EX->EX on x7, MEM->EX on x4)

```

The next assembly program checks for load-use hazards. We expect to see the pipeline stall for exactly one cycle (the data of a load instruction isn't available until the end of mem, forcing the next instruction to stall because you'll have to wait until the load data is actually available).

```s
# Load-use hazard test
# The instruction immediately after each lw uses the loaded register.
# Hazard unit should stall the pipeline for exactly 1 cycle per load-use pair.

# Setup: store values into memory first (assume memory pre-initialized, or use these stores)
    addi  x1, x0, 100     # base address = 100
    addi  x2, x0, 42      # value to store
    sw    x2, 0(x1)        # mem[100] = 42
    addi  x3, x0, 99
    sw    x3, 4(x1)        # mem[104] = 99

    lw    x4, 0(x1)        # x4 = mem[100] = 42  <-- load
    add   x5, x4, x0       # x5 = x4 (LOAD-USE: stall 1 cycle)

    lw    x6, 4(x1)        # x6 = mem[104] = 99  <-- load
    sub   x7, x6, x4       # x7 = 99 - 42 = 57   (LOAD-USE: stall 1 cycle)
```

The third assembly program will check for branch penalties. We want to see the pipeline flush the IF/ID and ID/EX registers, which will stall the pipeline for 2 clock cycles.

```s
# Branch penalty test
# BEQ is taken (x1 == x1), causing a 2-cycle flush.
# Verify that the instructions at PC+4 and PC+8 are squashed (become NOPs in waveform).

    addi  x1, x0, 5       # x1 = 5
    addi  x2, x0, 5       # x2 = 5
    beq   x1, x2, target  # branch taken -> flush IF/ID, ID/EX
    addi  x3, x0, 99      # SQUASHED (should appear as NOP in waveform)
    addi  x4, x0, 88      # SQUASHED
target:
    addi  x5, x0, 1       # x5 = 1  (first instruction after branch resolves)
    addi  x6, x0, 2       # x6 = 2
```

The last assembly program will run a random set of instructions (not necessarily random, but should simulate the expected workload of a functional program) and we will measure the IPC using two counters; the amount of instructions and the amount of clock cycles. Ideally, we should see a 5x throughput (due to `t_comb `being considerably lower) compared to a single-core processor.

```s
# Mixed workload for IPC measurement
# Includes ALU ops, loads/stores, branches, and a small loop.
# Count cycles vs retired instructions for IPC.

    addi  x1, x0, 0       # loop counter i = 0
    addi  x2, x0, 8       # loop bound = 8
    addi  x3, x0, 200     # base address for array

loop:
    slli  x4, x1, 2       # x4 = i * 4 (byte offset)
    add   x5, x3, x4      # x5 = base + offset
    lw    x6, 0(x5)        # x6 = array[i]
    addi  x6, x6, 1       # x6++
    sw    x6, 0(x5)        # array[i] = x6
    addi  x1, x1, 1       # i++
    blt   x1, x2, loop    # if i < 8, loop
    
    # post-loop: compute sum of first two elements
    lw    x7, 0(x3)        # x7 = array[0]
    lw    x8, 4(x3)        # x8 = array[1]
    add   x9, x7, x8       # x9 = array[0] + array[1]
```

### Static Timing Analysis

We will run synthesis/implementation later to determine the maximum clock frequency that we could hypothetically run the processor at. Recall that:

Setup Condition:
$$
t_{clk} + t_{skew} \geq T_{cq} + T_{comb} + T_{setup}
$$

Hold Condition:
$$
t_{cq} + t_{comb} \geq t_{hold} + t_{skew}
$$

For FPGA tools like Xilinx (which I'll be using to synthesize), the hold condition is usually resolved by buffers being automatically inserted along the datapath if it's too fast. For our purposes, I would like to stress test this processor design by seeing the fastest clock frequency that our processor can handle before we start seeing negative setup slack. 

## Simulation + Waveform

First Workload: RAW Hazards

```
    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // nop (addi x0, x0, 0)
            imem['h000 >> 2] = 32'h00A00093; // addi x1, x0, 10      # x1 = 10
            imem['h004 >> 2] = 32'h00508113; // addi x2, x1, 5       # x2 = 15  (EX->EX on x1)
            imem['h008 >> 2] = 32'h002081B3; // add  x3, x1, x2      # x3 = 25  (EX->EX x2, MEM->EX x1)
            imem['h00C >> 2] = 32'h00219213; // slli x4, x3, 2       # x4 = 100 (EX->EX on x3)
            imem['h010 >> 2] = 32'h401202B3; // sub  x5, x4, x1      # x5 = 90  (EX->EX x4, MEM->EX x1)
            imem['h014 >> 2] = 32'h0022C333; // xor  x6, x5, x2      # x6 = 85  (EX->EX x5, MEM->EX x2)
            imem['h018 >> 2] = 32'h003363B3; // or   x7, x6, x3      # x7 = 93  (EX->EX x6, MEM->EX x3)
            imem['h01C >> 2] = 32'h0043F433; // and  x8, x7, x4      # x8 = 64  (EX->EX x7, MEM->EX x4)
    end
```

Second Workload: Load-Use Hazards

```
    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // nop (addi x0, x0, 0)
            imem['h000 >> 2] = 32'h06400093; // addi x1, x0, 100    # base address = 100
            imem['h004 >> 2] = 32'h02A00113; // addi x2, x0, 42     # value = 42
            imem['h008 >> 2] = 32'h0020A023; // sw   x2, 0(x1)      # mem[100] = 42
            imem['h00C >> 2] = 32'h06300193; // addi x3, x0, 99     # value = 99
            imem['h010 >> 2] = 32'h0030A223; // sw   x3, 4(x1)      # mem[104] = 99
            imem['h014 >> 2] = 32'h0000A203; // lw   x4, 0(x1)      # x4 = 42  <load>
            imem['h018 >> 2] = 32'h000202B3; // add  x5, x4, x0     # x5 = x4  LOAD-USE stall
            imem['h01C >> 2] = 32'h0040A303; // lw   x6, 4(x1)      # x6 = 99  <load>
            imem['h020 >> 2] = 32'h404303B3; // sub  x7, x6, x4     # x7 = 57  LOAD-USE stall
    end
```

Third Workload: Branch Penalties

```
    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // nop (addi x0, x0, 0)
            imem['h000 >> 2] = 32'h00500093; // addi x1, x0, 5      # x1 = 5
            imem['h004 >> 2] = 32'h00500113; // addi x2, x0, 5      # x2 = 5
            imem['h008 >> 2] = 32'h00208663; // beq  x1, x2, +12    # taken -> flush IF/ID, ID/EX
            imem['h00C >> 2] = 32'h06300193; // addi x3, x0, 99     # SQUASHED
            imem['h010 >> 2] = 32'h05800213; // addi x4, x0, 88     # SQUASHED
            imem['h014 >> 2] = 32'h00100293; // addi x5, x0, 1      # x5 = 1  (branch target)
            imem['h018 >> 2] = 32'h00200313; // addi x6, x0, 2      # x6 = 2
    end
```

---

## Timing Report


---

## References

---