`timescale 1ns / 1ps

module instr_memory #(
    parameter DEPTH = 1024,
    parameter PRELOAD_PROGRAM = 1  // 0 disables preload
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // write interface from bootloader
    input  logic        wr_en,
    input  logic [31:0] wr_data,
    input  logic [9:0]  wr_addr,   
    
    // read interface during normal execution
    input  logic [31:0] pc_in,
    output logic [31:0] instr
);

    logic [31:0] mem [0:DEPTH-1];
    
    // preload Fibonacci program (optional, controlled by parameter)
    generate
        if (PRELOAD_PROGRAM) begin : gen_preload
            initial begin
                mem[0]  = 32'h00000093; // addi x1, x0, 0
                mem[1]  = 32'h00100113; // addi x2, x0, 1
                mem[2]  = 32'h00000213; // addi x4, x0, 0
                mem[3]  = 32'h00B00293; // addi x5, x0, 11
                mem[4]  = 32'h00520763; // beq x4, x5, 7
                mem[5]  = 32'h002081B3; // add x3, x1, x2
                mem[6]  = 32'h00010093; // addi x1, x2, 0
                mem[7]  = 32'h00018113; // addi x2, x3, 0
                mem[8]  = 32'h0001807F; // prnt x3
                mem[9]  = 32'h00120213; // addi x4, x4, 1
                mem[10] = 32'hFE000AE3; // beq x0, x0, -6
                mem[11] = 32'h0001807F; // prnt x3
                mem[12] = 32'hFE000FE3; // beq x0, x0, -1
                
                for (int i = 13; i < DEPTH; i++) begin
                    mem[i] = 32'h00000013;  // NOP
                end
            end
        end else begin : gen_no_preload
            initial begin
                for (int i = 0; i < DEPTH; i++) begin
                    mem[i] = 32'h00000013;  // NOP
                end
            end
        end
    endgenerate
    
    // write from bootloader
    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;  // use address from bootloader
        end
    end
    
    // read during normal execution
    always_ff @(posedge clk) begin
        instr <= mem[pc_in[11:2]];  
    end

endmodule