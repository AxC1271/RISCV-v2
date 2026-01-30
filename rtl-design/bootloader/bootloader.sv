`timescale 1ns / 1ps

module bootloader # (
    parameter DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,
    input logic rx, // serial pin
    output logic [DATA_WIDTH-1:0] word
);

endmodule