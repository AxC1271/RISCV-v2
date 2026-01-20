`timescale 1ns / 1ps

module instr_memory # (
    parameter DEPTH = 1024
) (
    input clk,
    input rst_n,

    // write interface from bootloader
    input wr_en,
    input wr_instr,

    // read interface during normal execution
    input logic[31:0] pc_in,
    output logic[31:0] instr
);
    // internal dual port memory for instructions
    logic[31:0] mem [0:DEPTH-1];
    // pointer to keep track of writes
    logic[9:0] instr_ptr := 0;

    // write from bootloader, handles reset here
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset both the internal pointer 
            // and the memory to be written
            instr_ptr = 0;
            for (int i = 0; i < 1024; i++) begin
                mem[i] <= 32'h0;
            end
        end else if (wr_en) begin
            mem[instr_ptr] <= wr_instr;
            instr_ptr <= instr_ptr + 1;
        end
    end

    // normal read operations
    // rst_n of pc will be handled 
    // externally in top module
    always_ff @(posedge clk) begin
        instr <= mem[pc_in];
    end

endmodule