# RISC-V Core

## Purpose

This is a single-core RISC-V core which performs pure computations, with:
* Program Counter
* Register File
* 


---

## RTL Code

Here's the structural RTL implementation of the RISC-V core:

```SystemVerilog
module core_riscv (
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU control (from system)
    input  logic        cpu_enable, // enable CPU execution (stall during boot)
    
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

## Simulation + Waveform

---