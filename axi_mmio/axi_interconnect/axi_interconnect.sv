`timescale 1ns / 1ps

// one master device
// risc-v core acts as master
// three slave devices
// supports uart, i2c, spi
module axi_interconnect (
    input logic aclk,
    input logic aresetn,
    input logic[N:0] slave_addr,

);

// we would need a decoder 
// we are using mmio to route
// specific devices in our module

endmodule