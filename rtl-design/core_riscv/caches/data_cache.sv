`timescale 1ns / 1ps

// this will be a 1kB cache
module data_cache (
    input logic clk,
    input logic rst_n,
    
    // CPU interface
    input logic[31:0] cpu_addr,
    input logic       cpu_read,     // CPU wants to read
    input logic       cpu_write,    // CPU wants to write
    input logic[31:0] cpu_wdata,    // data to write
    output logic[31:0] cpu_rdata,
    output logic      cpu_ready,
    
    // memory interface
    output logic[31:0] mem_addr,
    output logic       mem_read,    // read signal
    output logic       mem_write,   // separate write signal
    output logic[31:0] mem_wdata,   // data to write to memory
    input logic[31:0]  mem_rdata,
    input logic        mem_ready
);

    logic[21:0] tag_ram [0:63];
    logic       valid_ram [0:63];
    logic[31:0] cache_ram [0:63][0:3];

    // unique to data cache lines, we'll
    // need to track when a cache line gets evicted
    logic       dirty_ram [0:63]; 

endmodule