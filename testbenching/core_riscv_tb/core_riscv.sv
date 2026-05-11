`timescale 1ns / 1ps

module core_riscv (
    input logic clk,
    input logic rst_n,
    input logic cpu_enable,

    output logic [31:0] imem_addr,
    output logic imem_req,
    input  logic [31:0] imem_rdata,
    input  logic imem_ready,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic dmem_rd_en,
    output logic dmem_wr_en,
    output logic [2:0]  dmem_size,
    input  logic [31:0] dmem_rdata,
    input  logic dmem_ready,

    output logic [31:0] debug_pc,
    output logic [31:0] debug_instr,
    output logic [31:0] debug_reg_data,
    output logic debug_halted
);

    logic [31:0] pc_current, pc_next;

    logic [31:0] id_pc, ex_pc;
    logic [31:0] id_instr;

    logic [31:0] ex_rs1_data, ex_rs2_data, ex_immediate;
    logic [4:0]  ex_rs1, ex_rs2, ex_rd;
    logic [3:0]  ex_alu_op;
    logic ex_alu_src, ex_mem_read, ex_mem_write;
    logic ex_reg_write, ex_mem_to_reg;

    logic [31:0] mem_alu_result, mem_rs2_data;
    logic [4:0] mem_rd;
    logic mem_zero_flag;
    logic mem_mem_read, mem_mem_write;
    logic mem_reg_write, mem_mem_to_reg;

    logic [31:0] wb_alu_result, wb_read_data;
    logic [4:0] wb_rd;
    logic wb_reg_write, wb_mem_to_reg;

    logic [31:0] rf_rs1_data, rf_rs2_data;
    logic [31:0] rf_wr_data;
    logic [4:0]  rf_wr_addr;
    logic        rf_wr_en;

    logic [31:0] alu_a, alu_b, alu_result;
    logic [3:0]  id_alu_op;
    logic        alu_zero;

    logic reg_write, mem_read, mem_write;
    logic mem_to_reg, alu_src;
    logic branch, jump;

    logic stall, flush;
    logic [1:0] forward_a, forward_b;

    logic branch_taken;
    logic [31:0] branch_target;
    logic [31:0] immediate;

    logic fetch_stall, mem_stall;

    assign fetch_stall = cpu_enable && !imem_ready;
    assign mem_stall   = (mem_mem_read || mem_mem_write) && !dmem_ready;

    assign imem_addr = pc_current;
    assign imem_req  = cpu_enable;

    program_counter pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_in(pc_next),
        .pc_out(pc_current)
    );

    always_comb begin
        if (!cpu_enable)
            pc_next = pc_current;
        else if (branch_taken)
            pc_next = branch_target;
        else if (fetch_stall || mem_stall || stall)
            pc_next = pc_current;
        else
            pc_next = pc_current + 32'd4;
    end

    ifid_register ifid (
        .clk(clk),
        .rst_n(rst_n),
        .stall(!imem_ready || stall || mem_stall),
        .flush(branch_taken),
        .if_pc(pc_current),
        .if_instruction(imem_rdata),
        .id_pc(id_pc),
        .id_instruction(id_instr)
    );

    register_file rf (
        .clk(clk),
        .rst_n(rst_n),
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
        .RegWrite(reg_write),
        .MemRead(mem_read),
        .MemWrite(mem_write),
        .BranchEq(branch),
        .MemToReg(mem_to_reg),
        .ALUSrc(alu_src),
        .ALUCont(id_alu_op),
        .JMP(jump)
    );

    immediate_generator imm_gen (
        .instruction(id_instr),
        .immediate(immediate)
    );

    hazard_unit hazard (
        .id_rs1(id_instr[19:15]),
        .id_rs2(id_instr[24:20]),
        .ex_rd(ex_rd),
        .ex_mem_read(ex_mem_read),
        .mem_stall(mem_stall),
        .stall(stall),
        .flush_id_ex(flush)
    );

    logic[31:0] branch_rs1, branch_rs2;

    always_comb begin
        if      (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == id_instr[19:15]))
            branch_rs1 = mem_alu_result;
        else if (wb_reg_write  && (wb_rd  != 5'b0) && (wb_rd  == id_instr[19:15]))
            branch_rs1 = rf_wr_data;
        else
            branch_rs1 = rf_rs1_data;
    end
    
    always_comb begin
        if      (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == id_instr[24:20]))
            branch_rs2 = mem_alu_result;
        else if (wb_reg_write  && (wb_rd  != 5'b0) && (wb_rd  == id_instr[24:20]))
            branch_rs2 = rf_wr_data;
        else
            branch_rs2 = rf_rs2_data;
    end

    logic branch_taken_raw;

    branch_unit branch_unit (
        .rs1_data(branch_rs1),
        .rs2_data(branch_rs2),
        .branch(branch),
        .funct3(id_instr[14:12]),
        .pc(id_pc),
        .imm(immediate),
        .branch_taken(branch_taken_raw),
        .branch_target(branch_target)
    );

    assign branch_taken = branch_taken_raw && !mem_stall && imem_ready;

    idex_register idex (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush || branch_taken),
        .stall(mem_stall),
        .id_pc(id_pc),
        .id_rs1_data(rf_rs1_data),
        .id_rs2_data(rf_rs2_data),
        .id_immediate(immediate),
        .id_rs1(id_instr[19:15]),
        .id_rs2(id_instr[24:20]),
        .id_rd(id_instr[11:7]),
        .id_alu_op(id_alu_op),
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

    logic [31:0] ex_rs2_forwarded;

    always_comb begin
        case (forward_b)
            2'b00:   ex_rs2_forwarded = ex_rs2_data;
            2'b01:   ex_rs2_forwarded = rf_wr_data;
            2'b10:   ex_rs2_forwarded = mem_alu_result;
            default: ex_rs2_forwarded = ex_rs2_data;
        endcase
    end

    always_comb begin
        case (forward_a)
            2'b00:   alu_a = ex_rs1_data;
            2'b01:   alu_a = rf_wr_data;
            2'b10:   alu_a = mem_alu_result;
            default: alu_a = ex_rs1_data;
        endcase
    end

    assign alu_b = ex_alu_src ? ex_immediate : ex_rs2_forwarded;

    arith_logic_unit alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(ex_alu_op),
        .result(alu_result),
        .zero_flag(alu_zero)
    );

    exmem_register exmem (
        .clk(clk),
        .rst_n(rst_n),
        .stall(mem_stall),
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

    logic dmem_ready_prev;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) dmem_ready_prev <= 1'b0;
        else        dmem_ready_prev <= dmem_ready;
    end

    assign dmem_addr  = mem_alu_result;
    assign dmem_wdata = mem_rs2_data;
    assign dmem_rd_en = mem_mem_read && !dmem_ready && !dmem_ready_prev;
    assign dmem_wr_en = mem_mem_write && !dmem_ready && !dmem_ready_prev;
    assign dmem_size  = 3'b010;   // word (32-bit)

    memwb_register memwb (
        .clk(clk),
        .rst_n(rst_n),
        .stall(mem_stall),
        .mem_alu_result(mem_alu_result),
        .mem_read_data(dmem_rdata),
        .mem_rd(mem_rd),
        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .wb_alu_result(wb_alu_result),
        .wb_read_data(wb_read_data),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .wb_mem_to_reg(wb_mem_to_reg)
    );

    assign rf_wr_data = wb_mem_to_reg ? wb_read_data : wb_alu_result;
    assign rf_wr_addr = wb_rd;
    assign rf_wr_en   = wb_reg_write && cpu_enable && !mem_stall;

    assign debug_pc       = pc_current;
    assign debug_instr    = id_instr;
    assign debug_reg_data = rf_rs1_data;
    assign debug_halted   = !cpu_enable;

endmodule