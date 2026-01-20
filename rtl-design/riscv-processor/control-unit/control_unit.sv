`timescale 1ns / 1ps

module control_unit (
    input logic[6:0] opcode,
    input logic[2:0] funct3,
    input logic[6:0] funct7,

    output logic RegWrite,
    output logic MemRead,
    output logic MemWrite,
    output logic BranchEq,
    output logic MemToReg,
    output logic ALUSrc,
    output logic ALUCont,
    output logic JMP
);

    // define some localparams for the RISC-V
    // architecture so I don't lose my mind

    localparam OP_R_TYPE = 7'b0110011;
    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL = 7'b1101111;
    localparam OP_JALR = 7'b1100111;

    localparam F3_ADD_SUB = 3'b000;
    localparam F3_AND = 3'b111;
    localparam F3_OR = 3'b110;
    localparam F3_XOR = 3'b100;
    localparam F3_BEQ = 3'b000;

    localparam F7_ADD = 7'b0000000;
    localparam F7_SUB = 7'b0100000;

    always_comb begin
    end


endmodule