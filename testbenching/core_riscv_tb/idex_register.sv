`timescale 1ns / 1ps

module idex_register (
    input logic clk,
    input logic rst_n,
    input logic flush,
    input logic stall,
    input logic [31:0] id_pc,
    input logic [31:0] id_rs1_data,
    input logic [31:0] id_rs2_data,
    input logic [31:0] id_immediate,
    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,
    input logic [4:0] id_rd,
    input logic [3:0] id_alu_op,
    input logic id_alu_src,
    input logic id_mem_read,
    input logic id_mem_write,
    input logic id_reg_write,
    input logic id_mem_to_reg,
    output logic [31:0] ex_pc,
    output logic [31:0] ex_rs1_data,
    output logic [31:0] ex_rs2_data,
    output logic [31:0] ex_immediate,
    output logic [4:0] ex_rs1,
    output logic [4:0] ex_rs2,
    output logic [4:0] ex_rd,
    output logic [3:0] ex_alu_op,
    output logic ex_alu_src,
    output logic ex_mem_read,
    output logic ex_mem_write,
    output logic ex_reg_write,
    output logic ex_mem_to_reg
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_pc <= 32'h0;
            ex_rs1_data <= 32'h0;
            ex_rs2_data <= 32'h0;
            ex_immediate <= 32'h0;
            ex_rs1 <= 5'h0;
            ex_rs2 <= 5'h0;
            ex_rd <= 5'h0;
            ex_alu_op <= 4'h0;
            ex_alu_src <= 1'b0;
            ex_mem_read <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_reg_write <= 1'b0;
            ex_mem_to_reg <= 1'b0;

        end else if (flush) begin
            // insert NOP bubble, only reachable when not stalling
            ex_pc <= 32'h0;
            ex_rs1_data <= 32'h0;
            ex_rs2_data <= 32'h0;
            ex_immediate  <= 32'h0;
            ex_rs1 <= 5'h0;
            ex_rs2 <= 5'h0;
            ex_rd <= 5'h0;
            ex_alu_op <= 4'h0;
            ex_alu_src <= 1'b0;
            ex_mem_read <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_reg_write <= 1'b0;
            ex_mem_to_reg <= 1'b0;

        end else if (stall) begin
            // hold since stall takes priority over flush

        end else begin
            // normal advance
            ex_pc <= id_pc;
            ex_rs1_data <= id_rs1_data;
            ex_rs2_data <= id_rs2_data;
            ex_immediate <= id_immediate;
            ex_rs1 <= id_rs1;
            ex_rs2 <= id_rs2;
            ex_rd <= id_rd;
            ex_alu_op <= id_alu_op;
            ex_alu_src <= id_alu_src;
            ex_mem_read <= id_mem_read;
            ex_mem_write <= id_mem_write;
            ex_reg_write <= id_reg_write;
            ex_mem_to_reg <= id_mem_to_reg;
        end
    end

endmodule