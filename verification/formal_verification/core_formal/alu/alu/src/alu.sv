module alu (
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0]  alu_opcode,  
    output logic [31:0] res
);

    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;  
    localparam logic [3:0] ALU_AND  = 4'b0010; 
    localparam logic [3:0] ALU_OR   = 4'b0011;  
    localparam logic [3:0] ALU_XOR  = 4'b0100;  
    localparam logic [3:0] ALU_SLL  = 4'b0101;  
    localparam logic [3:0] ALU_SRL  = 4'b0110; 
    localparam logic [3:0] ALU_SRA  = 4'b0111;  
    localparam logic [3:0] ALU_SLT  = 4'b1000;  
    localparam logic [3:0] ALU_SLTU = 4'b1001;  

    always_comb begin
        case (alu_opcode)
            ALU_ADD:  res = a + b;
            ALU_SUB:  res = a - b;
            ALU_AND:  res = a & b;
            ALU_OR:   res = a | b;
            ALU_XOR:  res = a ^ b;
            ALU_SLL:  res = a << b[4:0];           
            ALU_SRL:  res = a >> b[4:0];          
            ALU_SRA:  res = a[31] ? ~((~a) >> b[4:0]) : (a >> b[4:0]);
            ALU_SLT:  res = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: res = (a < b) ? 32'd1 : 32'd0;                    
            default:  res = 32'h0; 
        endcase

        // written formal properties
        if (alu_opcode == ALU_ADD)
            assert (res == a + b);
        if (alu_opcode == ALU_SUB)
            assert (res == a - b);
        if (alu_opcode == ALU_AND)
            assert (res == (a & b));
        if (alu_opcode == ALU_OR)
            assert (res == (a | b));
        if (alu_opcode == ALU_XOR)
            assert (res == (a ^ b));
        if (alu_opcode == ALU_SLL)
            assert (res == (a << b[4:0]));
        if (alu_opcode == ALU_SRL)
            assert (res == (a >> b[4:0]));
        if (alu_opcode == ALU_SRA)
            assert (res == (a[31] ? ~((~a) >> b[4:0]) : (a >> b[4:0])));
        if (alu_opcode == ALU_SLT)
            assert (res == (($signed(a) < $signed(b)) ? 32'd1 : 32'd0));
        if (alu_opcode == ALU_SLTU)
            assert (res == ((a < b) ? 32'd1 : 32'd0));
        if (alu_opcode != ALU_ADD  && alu_opcode != ALU_SUB &&
            alu_opcode != ALU_AND  && alu_opcode != ALU_OR  &&
            alu_opcode != ALU_XOR  && alu_opcode != ALU_SLL &&
            alu_opcode != ALU_SRL  && alu_opcode != ALU_SRA &&
            alu_opcode != ALU_SLT  && alu_opcode != ALU_SLTU)
            assert (res == 32'h0);

        cover (alu_opcode == 4'b1010);
    end
endmodule