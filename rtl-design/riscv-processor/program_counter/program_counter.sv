`timescale 1ns / 1ps

module program_counter (
    input logic clk,
    input logic[31:0] pc_in,
    output logic[31:0] pc_out
);
    // unlike the previous design, rst
    // is removed from the program counter
    // the instruction reset will be handled
    // in the top module
    always_ff @(posedge clk) begin
        pc_out <= pc_in;
    end

endmodule