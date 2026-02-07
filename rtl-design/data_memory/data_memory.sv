`timescale 1ns / 1ps

module data_memory # (
    parameter DEPTH = 256  // 256 words = 1KB
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // address and data
    input  logic [31:0] mem_addr,  
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    
    // control signals
    input  logic        MemWrite,
    input  logic        MemRead
);

    // memory array (word-addressed)
    logic [31:0] mem [0:DEPTH-1];
    
    logic [7:0] word_addr;  
    assign word_addr = mem_addr[9:2];  // bits [9:2] = word index
    
    // initialize memory to zero
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = 32'h0; 
        end
    end
    
    // write operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= 32'h0;
            end
        end else if (MemWrite) begin
            mem[word_addr] <= wr_data;  
        end
    end
    
    // read operation
    always_ff @(posedge clk) begin
        if (MemRead) begin
            rd_data <= mem[word_addr];
        end else begin
            rd_data <= 32'h0; 
        end
    end

endmodule