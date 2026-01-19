`timescale 1ns / 1ps

module uart_rx # (
    parameter BAUD_RATE = 115200,
    parameter DATA_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    input logic rx,
    output logic[DATA_WIDTH-1:0] rx_data
);

endmodule;