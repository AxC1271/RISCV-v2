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

    // this instr_memory will come preloaded with a Fibonacci sequence code
    // the hexadecimals were derived from the RISCV-CPU Git repository
    initial begin
        mem[0] <= 32'h00000093; // addi x1, x0, 0
        mem[1] <= 32'h00100113; // addi x2, x0, 1
        mem[2] <= 32'h00000213; // addi x4, x0, 0
        mem[3] <= 32'h00B00293; // addi x5, x0, 11
        mem[4] <= 32'h00520763; // beq x4, x5, 7
        mem[5] <= 32'h002081B3; // add x3, x1, x2
        mem[6] <= 32'h00010093; // addi x1, x2, 0
        mem[7] <= 32'h00018113; // addi x2, x3, 0
        mem[8] <= 32'h0001807F; // prnt x3
        mem[9] <= 32'h00120213; // addi x4, x4, 1
        mem[10] <= 32'hFE000AE3; // beq x0, x0, -6
        mem[11] <= 32'h0001807F; // prnt x3
        mem[12] <= 32'hFE000FE3; // beq x0, x0, -1
    end

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