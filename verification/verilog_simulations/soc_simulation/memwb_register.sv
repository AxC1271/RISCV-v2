`timescale 1ns / 1ps

module memwb_register (
    input  logic clk,
    input  logic rst_n,
    input  logic stall,
    input  logic [31:0] mem_alu_result,
    input  logic [31:0] mem_rdata,      // load data, already extended in MEM
    input  logic [4:0]  mem_rd,
    input  logic        mem_regwrite,
    input  logic        mem_memtoreg,
    input  logic        mem_ebreak,

    output logic [31:0] wb_alu_result,
    output logic [31:0] wb_rdata,
    output logic [4:0]  wb_rd,
    output logic        wb_regwrite,
    output logic        wb_memtoreg,
    output logic        wb_ebreak
);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wb_alu_result <= 32'h0;
            wb_rdata      <= 32'h0;
            wb_rd         <= 5'h0;
            wb_regwrite   <= 1'b0;
            wb_memtoreg   <= 1'b0;
            wb_ebreak     <= 1'b0;
        end else if (stall) begin
            // hold
        end else begin
            wb_alu_result <= mem_alu_result;
            wb_rdata      <= mem_rdata;
            wb_rd         <= mem_rd;
            wb_regwrite   <= mem_regwrite;
            wb_memtoreg   <= mem_memtoreg;
            wb_ebreak     <= mem_ebreak;
        end
    end
endmodule