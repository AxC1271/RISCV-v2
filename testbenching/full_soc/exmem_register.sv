`timescale 1ns / 1ps

module exmem_register (
    input logic clk,
    input logic rst_n,
    input logic stall,
    input logic [31:0] ex_alu_result,
    input logic [31:0] ex_rs2_data,
    input logic [4:0] ex_rd,
    input logic ex_zero_flag,
    input logic ex_mem_read,
    input logic ex_mem_write,
    input logic ex_reg_write,
    input logic ex_mem_to_reg,
    output logic [31:0] mem_alu_result,
    output logic [31:0] mem_rs2_data,
    output logic [4:0] mem_rd,
    output logic mem_zero_flag,
    output logic mem_mem_read,
    output logic mem_mem_write,
    output logic mem_reg_write,
    output logic mem_mem_to_reg
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_alu_result <= 32'h0;
            mem_rs2_data <= 32'h0;
            mem_rd <= 5'h0;
            mem_zero_flag <= 1'b0;
            mem_mem_read <= 1'b0;
            mem_mem_write <= 1'b0;
            mem_reg_write <= 1'b0;
            mem_mem_to_reg <= 1'b0;
        end else if (!stall) begin
            mem_alu_result <= ex_alu_result;
            mem_rs2_data <= ex_rs2_data;
            mem_rd <= ex_rd;
            mem_zero_flag <= ex_zero_flag;
            mem_mem_read <= ex_mem_read;
            mem_mem_write <= ex_mem_write;
            mem_reg_write <= ex_reg_write;
            mem_mem_to_reg <= ex_mem_to_reg;
        end
    end
endmodule