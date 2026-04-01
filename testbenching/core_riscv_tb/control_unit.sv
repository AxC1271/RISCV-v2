`timescale 1ns / 1ps

module control_unit (
    input logic[6:0] opcode,
    input logic[2:0] funct3,
    input logic[6:0] funct7,

    output logic reg_write,
    output logic mem_read,
    output logic mem_write,
    output logic branch,
    output logic mem_to_reg,
    output logic alu_src,
    output logic[3:0] alu_op,
    output logic jump
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
        reg_write <= 1'b0;
        mem_read <= 1'b0;
        mem_write <= 1'b0;
        branch <= 1'b0;
        mem_to_reg <= 1'b0;
        alu_src <= 1'b0;
        alu_op <= 1'b0;
        jump <= 1'b0;
    end

    always_comb begin
        case (opcode)
            OP_R_TYPE: begin
                reg_write <= 1'b1;
                mem_read <= 1'b0;
                mem_write <= 1'b0;
                branch <= 1'b0;
                mem_to_reg <= 1'b0;
                alu_src <= 1'b0;
                jump <= 1'b0;
                case (funct3)
                    F3_ADD_SUB: begin
                        case (funct7) 
                            F7_ADD: alu_op <= 3'b000; // ADD
                            F7_SUB: alu_op <= 3'b001; // SUB
                        endcase
                    end
                    F3_AND:   alu_op <= 3'b010; // AND
                    F3_OR:    alu_op <= 3'b011;  // OR
                    F3_XOR:   alu_op <= 3'b100; // XOR
                    default:  alu_op <= 3'b000; // just make add default
                endcase
            end
            OP_I_ARITH: begin
                reg_write <= 1'b1;
                mem_read <= 1'b0;
                mem_write <= 1'b0;
                branch <= 1'b0;
                mem_to_reg <= 1'b0;
                alu_src <= 1'b1;
                alu_op <= 3'b000;
                jump <= 1'b0;
            end
            OP_LOAD: begin
                reg_write <= 1'b1;
                mem_read <= 1'b1;
                mem_write <= 1'b0;
                branch <= 1'b0;
                mem_to_reg <= 1'b1;
                alu_src <= 1'b1;
                alu_op <= 3'b000;
                jump <= 1'b0;
            end
            OP_STORE: begin
                reg_write <= 1'b0;
                mem_read <= 1'b0;
                mem_write <= 1'b1;
                branch <= 1'b0;
                mem_to_reg <= 1'b0;
                alu_src <= 1'b1;
                alu_op <= 3'b000;
                jump <= 1'b0;
            end
            OP_BRANCH: begin
                reg_write <= 1'b0;
                mem_read <= 1'b0;
                mem_write <= 1'b0;
                branch <= 1'b1;
                mem_to_reg <= 1'b0;
                alu_src <= 1'b0;
                alu_op <= 3'b001;
                jump <= 1'b0;
            end
            OP_JAL: begin
                reg_write <= 1'b1;
                mem_read <= 1'b0;
                mem_write <= 1'b0;
                branch <= 1'b0;
                mem_to_reg <= 1'b0;
                alu_src <= 1'b1;
                jump <= 1'b1;
            end
            OP_JALR: begin
                reg_write <= 1'b1;
                mem_read <= 1'b0;
                mem_write <= 1'b0;
                branch <= 1'b0;
                mem_to_reg <= 1'b0;
                alu_src <= 1'b1;
                jump <= 1'b1;
            end
        endcase
    end
endmodule