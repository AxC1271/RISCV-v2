`timescale 1ns / 1ps

module memwb_register (
    input  logic        clk,
    input  logic        rst_n,
    
    // data inputs
    input  logic [31:0] mem_alu_result,
    input  logic [31:0] mem_read_data,
    input  logic [4:0]  mem_rd,
    
    // control inputs
    input  logic        mem_reg_write,
    input  logic        mem_mem_to_reg,
    
    // data outputs
    output logic [31:0] wb_alu_result,
    output logic [31:0] wb_read_data,
    output logic [4:0]  wb_rd,
    
    // control outputs
    output logic        wb_reg_write,
    output logic        wb_mem_to_reg
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_alu_result <= 32'h0;
            wb_read_data <= 32'h0;
            wb_rd <= 5'h0;
            
            wb_reg_write <= 1'b0;
            wb_mem_to_reg <= 1'b0;
        end else begin
            wb_alu_result <= mem_alu_result;
            wb_read_data <= mem_read_data;
            wb_rd <= mem_rd;
            
            wb_reg_write <= mem_reg_write;
            wb_mem_to_reg <= mem_mem_to_reg;
        end
    end
endmodule