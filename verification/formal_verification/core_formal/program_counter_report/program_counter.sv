`timescale 1ns / 1ps

module program_counter (
    input logic clk,
    input logic rst_n,
    input logic[31:0] pc_in,
    output logic[31:0] pc_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 32'h0000_0000;
        end else begin
            pc_out <= pc_in;
        end
    end
endmodule