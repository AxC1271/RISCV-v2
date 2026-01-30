`timescale 1ns / 1ps

module arith_logic_unit (
    input logic[31:0] a,
    input logic[31:0] b,
    input logic[2:0] opcode,
    output logic[31:0] res,
    output logic zero_flag
);

    assign zero_flag = (res == 0);

    // switch case for ALU opcode
    always_comb begin
        case (opcode)
            3'b000: res =  a + b; // ADD
            3'b001: res = a - b; // SUB
            3'b010: res = a & b; // AND
            3'b011: res = a | b; // OR
            3'b100: res = a ^ b; // XOR
            3'b101: res = a << b[4:0]; // SLL
            3'b110: res = a >> b[4:0]; // SRL
            default: res = (a < b) ? 1 : 0; // SLT
        endcase
    end

endmodule