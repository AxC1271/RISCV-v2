`timescale 1ns / 1ps

// this is just the RISC-V core,
// not the entire integrated system
module riscv_processor (
    input logic clk,
    input logic rst_n,
    input logic rx,
);

// instantiate necessary signals here

    // program counter
    logic [31:0] pc_in, pc_out;

    // instruction memory
    logic [31:0] curr_instr;

    // control unit
    logic RegWrite,
    logic MemRead,
    logic MemWrite,
    logic BranchEq,
    logic MemToReg,
    logic ALUSrc,
    logic ALUCont,
    logic JMP

    // pipelining registers

// instantiate modules here
    program_counter pc (
        .clk(clk),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    instr_memory im (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(),
        .wr_instr(),

        // pass in pc pointer
        .pc_in(pc_out),
        .instr(curr_instr)
    );

    register_file rf (
        .clk(clk),
        .rst_n(rst_n),

        // derived from instr_memory
        .rd_addr1(curr_instr[19:15]),
        .rd_addr2(curr_instr[24:20]),

        .wr_addr(curr_instr[11:7]),
        .wr_data(),
        .wr_en(),

        .rd_data1(),
        .rd_data2(),

    );

    control_unit cu (
        .opcode(curr_instr[6:0]),
        .funct3(curr_instr[14:12]),
        .funct6(curr_instr[31:25]),
        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .BranchEq(BranchEq),
        .MemToReg(MemToReg),
        .ALUSrc(ALUSrc),
        .ALUCont(ALUCont),
        .JMP(JMP)
    );

    arith_logic_unit alu (
        .a(),
        .b(),
        .opcode(),
        .res(),
        .zero_flag()
    );

// instantiate processes here

    always_ff @ (posedge clk or negedge rst_n) begin
    end

endmodule