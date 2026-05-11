`timescale 1ns / 1ps

module ifid_register (
    input logic clk,
    input logic rst_n,
    input logic stall, // from hazard unit
    input logic flush, // from branch unit
    input logic [31:0] if_pc,
    input logic [31:0] if_instruction,
    output logic [31:0] id_pc,
    output logic [31:0] id_instruction
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc          <= 32'h0;
            id_instruction <= 32'h00000013;
            
        // flush wins over stall
        end else if (flush) begin
            id_pc          <= 32'h0;
            id_instruction <= 32'h00000013;
        end else if (stall) begin
            id_pc          <= id_pc;
            id_instruction <= id_instruction;
        end else begin
            id_pc          <= if_pc;
            id_instruction <= if_instruction;
        end
    end
endmodule