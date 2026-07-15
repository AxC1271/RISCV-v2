module ifid_register (
    input  logic clk,
    input  logic rst_n,
    input  logic stall,
    input  logic flush,
    input  logic [31:0] if_pc,
    input  logic [31:0] if_instr,
    output logic [31:0] id_pc,
    output logic [31:0] id_instr
);
    always_ff @(posedge clk) begin
        if (!rst_n || flush) begin
            id_pc    <= 32'h0;
            id_instr <= 32'h00000013;
        end else if (stall) begin
            // hold
        end else begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
    end
endmodule