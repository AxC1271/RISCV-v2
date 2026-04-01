`timescale 1ns / 1ps

module axislave_uart (
    input logic clk,
    input logic rst_n,
    // axi-lite slave port
    input logic [31:0] s_awaddr,
    input logic s_awvalid,
    output logic s_awready,
    input logic [31:0] s_wdata,
    input logic [3:0] s_wstrb,
    input logic s_wvalid,
    output logic s_wready,
    output logic [1:0] s_bresp,
    output logic s_bvalid,
    input logic s_bready,
    input logic [31:0] s_araddr,
    input logic s_arvalid,
    output logic s_arready,
    output logic [31:0] s_rdata,
    output logic [1:0] s_rresp,
    output logic s_rvalid,
    input logic s_rready,

    // uart physical pins
    output logic uart_tx,
    input logic uart_rx
);

endmodule