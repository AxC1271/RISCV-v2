`timescale 1ns / 1ps

module control_unit (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,

    output logic RegWrite,
    output logic MemRead,
    output logic MemWrite,
    output logic BranchEq,
    output logic MemToReg,
    output logic ALUSrc,
    output logic [3:0] ALUCont,
    output logic JMP
);

    // copy binary values so I don't lose my mind
    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_ARITH = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_JALR    = 7'b1100111;

    localparam F3_ADD_SUB = 3'b000;
    localparam F3_AND     = 3'b111;
    localparam F3_OR      = 3'b110;
    localparam F3_XOR     = 3'b100;
    localparam F3_BEQ     = 3'b000;

    localparam F7_ADD     = 7'b0000000;
    localparam F7_SUB     = 7'b0100000;

    localparam logic [3:0] ALU_ADD = 4'b0000;
    localparam logic [3:0] ALU_SUB = 4'b1000;
    localparam logic [3:0] ALU_AND = 4'b0111;
    localparam logic [3:0] ALU_OR  = 4'b0110;
    localparam logic [3:0] ALU_XOR = 4'b0100;

    always_comb begin
        // defaults
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        BranchEq = 1'b0;
        MemToReg = 1'b0;
        ALUSrc   = 1'b0;
        ALUCont  = ALU_ADD;
        JMP      = 1'b0;

        case (opcode)
            OP_R_TYPE: begin
                RegWrite = 1'b1;

                case (funct3)
                    F3_ADD_SUB: begin
                        case (funct7)
                            F7_ADD: ALUCont = ALU_ADD;
                            F7_SUB: ALUCont = ALU_SUB;
                            default: ALUCont = ALU_ADD;
                        endcase
                    end
                    F3_AND: ALUCont = ALU_AND;
                    F3_OR:  ALUCont = ALU_OR;
                    F3_XOR: ALUCont = ALU_XOR;
                    default: ALUCont = ALU_ADD;
                endcase
            end

            OP_I_ARITH: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUCont  = ALU_ADD; 
            end

            OP_LOAD: begin
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                MemToReg = 1'b1;
                ALUSrc   = 1'b1;
                ALUCont  = ALU_ADD;
            end

            OP_STORE: begin
                MemWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUCont  = ALU_ADD;
            end

            OP_BRANCH: begin
                if (funct3 == F3_BEQ) begin
                    BranchEq = 1'b1;
                    ALUCont  = ALU_SUB;
                end
            end

            OP_JAL: begin
                RegWrite = 1'b1;
                JMP      = 1'b1;
            end

            OP_JALR: begin
                RegWrite = 1'b1;
                JMP      = 1'b1;
                ALUSrc   = 1'b1;
            end

            default: begin
                // keep defaults
            end
        endcase
    end

endmodule