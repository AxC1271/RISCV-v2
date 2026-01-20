`timescale 1ns / 1ps

// this will be a 1kB cache
module instr_cache # (
    parameter DEPTH = 256
)(
    input logic clk,
    input logic rst_n,
    
    // CPU side, RISC-V Core
    input logic[31:0] cpu_addr, 
    input logic cpu_req, 
    output logic[31:0] cpu_rdata,
    output logic cpu_ready,

    // Memory side, instr_memory
    output logic[31:0] mem_addr, 
    output logic mem_req,
    input logic[31:0] mem_rdata,
    input logic mem_ready
);

    logic[21:0] tag_ram [0:63];
    logic valid_ram [0:63];
    logic[31:0] cache_ram [0:63][0:3];

    logic [21:0] addr_tag;
    logic [5:0]  addr_index;
    logic [1:0]  addr_offset;

    logic [21:0] stored_tag;
    logic stored_valid;
    logic hit;

    // derive the tags from the cpu_addr
    assign addr_tag    = cpu_addr[31:10];  
    assign addr_index  = cpu_addr[9:4];   
    assign addr_offset = cpu_addr[3:2];   
    
    // check hit logic, look what's in the cache
    // at that addr_index
    assign stored_tag = tag_ram[addr_index];
    assign stored_valid = valid_ram[addr_index];

    assign hit = (addr_tag == stored_tag) && stored_valid;

endmodule