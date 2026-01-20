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

    initial begin
        RegWrite <= 1'b0;
        MemRead <= 1'b0;
        MemWrite <= 1'b0;
        BranchEq <= 1'b0;
        MemToReg <= 1'b0;
        ALUSrc <= 1'b0;
        ALUCont <= 1'b0;
        JMP <= 1'b0;
    end

    always_comb begin
        case (opcode)
            OP_R_TYPE: begin
                RegWrite <= 1'b1;
                MemRead <= 1'b0;
                MemWrite <= 1'b0;
                BranchEq <= 1'b0;
                MemToReg <= 1'b0;
                ALUSrc <= 1'b0;
                JMP <= 1'b0;
                case (funct3)
                    F3_ADD_SUB: begin
                        case (funct7) 
                            F7_ADD: ALUCont <= 3'b000; // ADD
                            F7_SUB: ALUCont <= 3'b001; // SUB
                        endcase
                    end
                    F3_AND: ALUCont <= 3'b010; // AND
                    F3_OR: ALUCont <= 3'b011;  // OR
                    F3_XOR: ALUCont <= 3'b100; // XOR
                    default: ALUCont <= 3'b000; // just make add default
                endcase
            end
            OP_I_ARITH: begin
                RegWrite <= 1'b1;
                MemRead <= 1'b0;
                MemWrite <= 1'b0;
                BranchEq <= 1'b0;
                MemToReg <= 1'b0;
                ALUSrc <= 1'b1;
                ALUCont <= 3'b000;
                JMP <= 1'b0;
            end
            OP_LOAD: begin
                RegWrite <= 1'b1;
                MemRead <= 1'b1;
                MemWrite <= 1'b0;
                BranchEq <= 1'b0;
                MemToReg <= 1'b1;
                ALUSrc <= 1'b1;
                ALUCont <= 3'b000;
                JMP <= 1'b0;
            end
            OP_STORE: begin
                RegWrite <= 1'b0;
                MemRead <= 1'b0;
                MemWrite <= 1'b1;
                BranchEq <= 1'b0;
                MemToReg <= 1'b0;
                ALUSrc <= 1'b1;
                ALUCont <= 3'b000;
                JMP <= 1'b0;
            end
            OP_BRANCH: begin
                RegWrite <= 1'b0;
                MemRead <= 1'b0;
                MemWrite <= 1'b0;
                BranchEq <= 1'b1;
                MemToReg <= 1'b0;
                ALUSrc <= 1'b0;
                ALUCont <= 3'b001;
                JMP <= 1'b0;
            end
            OP_JAL: begin
                RegWrite <= 1'b1;
                MemRead <= 1'b0;
                MemWrite <= 1'b0;
                BranchEq <= 1'b0;
                MemToReg <= 1'b0;
                ALUSrc <= 1'b1;
                JMP <= 1'b1;
            end
            OP_JALR: begin
                RegWrite <= 1'b1;
                MemRead <= 1'b0;
                MemWrite <= 1'b0;
                BranchEq <= 1'b0;
                MemToReg <= 1'b0;
                ALUSrc <= 1'b1;
                JMP <= 1'b1;
            end
        endcase
    end


endmodule