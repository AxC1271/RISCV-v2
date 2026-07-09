`timescale 1ns / 1ps

module axi_i2c # (
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    // signals for the axi interface

    // write address
    input logic [ADDR_WIDTH-1:0] s0_awaddr,
    input logic s0_awvalid,
    output logic s0_awready,

    // write data
    input logic [DATA_WIDTH-1:0] m_axi_wdata,
    input logic [3:0] m_axi_wstrb,
    input logic m_axi_wvalid,
    output logic m_axi_wready,

    // write response
    output logic [1:0] m_axi_bresp,
    output logic m_axi_bvalid,
    input logic m_axi_bready,

    // read address
    input logic [ADDR_WIDTH-1:0] m_axi_araddr,
    input logic m_axi_arvalid,
    output logic m_axi_arready,

    // read data
    output logic [DATA_WIDTH-1:0] m_axi_rdata,
    output logic [1:0] m_axi_rresp,
    output logic m_axi_rvalid,
    input logic m_axi_rready,

    // I2C pins
    
);

    typedef enum logic[1:0] {
        IDLE,
        WRITE_RESP,
        READ_RESP
    } axi_state_t;

endmodule