`timescale 1ns / 1ps

// this will be a 1kB cache
module data_cache # (
    parameter DEPTH = 256
)(
    input logic clk,
    input logic rst_n,
    
    // CPU side, RISC-V Core
    input logic[31:0] cpu_addr, 
    input logic cpu_req, 
    output logic[31:0] cpu_rdata,
    output logic cpu_ready,

    // Memory side, data_memory
    output logic[31:0] mem_addr, 
    output logic mem_req,
    input logic[31:0] mem_rdata,
    input logic mem_ready
);

    logic[21:0] tag_ram [0:63];
    logic valid_ram [0:63];
    logic[31:0] cache_ram [0:63][0:3];

endmodule