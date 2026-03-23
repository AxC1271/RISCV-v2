`timescale 1ns / 1ps

module program_counter (
    input logic clk,
    input logic[31:0] pc_in,
    output logic[31:0] pc_out
);

    always_ff @(posedge clk) begin
        pc_out <= pc_in;
    end

endmodule