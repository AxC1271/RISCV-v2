`timescale 1ns / 1ps

module data_memory (
    input logic clk,
    input logic rst_n,
    input logic[31:0] mem_addr,
    input logic[31:0] wr_data,

    // control unit flags
    input logic MemWrite,
    input logic MemRead,
    output logic[31:0] rd_data
);

    logic[31:0] mem [0:255];

    // set default values to zero
    initial begin
        for (int i = 0; i < 256; i++) begin
            mem[i] <= 32'h0;
        end
    end

    // handle writes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 256; i++) begin
                mem[i] <= 32'h0;
            end
        end else begin
            if (MemWrite) begin
                memory[mem_addr] <= wr_data;
            end
        end
    end

    // handle reads
    always_ff @(posedge clk) begin
        if (MemRead) begin
            rd_data <= mem[mem_addr];
        end else begin
            rd_data <= 32'b0;
        end
    end

endmodule