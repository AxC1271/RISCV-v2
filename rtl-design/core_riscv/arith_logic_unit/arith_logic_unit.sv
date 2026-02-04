`timescale 1ns / 1ps

module arith_logic_unit (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,  
    output logic [31:0] result,
    output logic        zero_flag
);

    // ALU operation encoding (standard RISC-V)
    localparam logic [3:0] ALU_ADD  = 4'b0000;  // ADD
    localparam logic [3:0] ALU_SUB  = 4'b1000;  // SUB 
    localparam logic [3:0] ALU_AND  = 4'b0111;  // AND
    localparam logic [3:0] ALU_OR   = 4'b0110;  // OR
    localparam logic [3:0] ALU_XOR  = 4'b0100;  // XOR
    localparam logic [3:0] ALU_SLL  = 4'b0001;  // Shift Left Logical
    localparam logic [3:0] ALU_SRL  = 4'b0101;  // Shift Right Logical
    localparam logic [3:0] ALU_SRA  = 4'b1101;  // Shift Right Arithmetic 
    localparam logic [3:0] ALU_SLT  = 4'b0010;  // Set Less Than (signed)
    localparam logic [3:0] ALU_SLTU = 4'b0011;  // Set Less Than Unsigned

    // assign zero flag 
    assign zero_flag = (result == 32'h0);

    // define the switch case for the alu
    always_comb begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];           
            ALU_SRL:  result = a >> b[4:0];          
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;                    
            default:  result = 32'h0;  // invalid operation
        endcase
    end

endmodule