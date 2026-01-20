`timescale 1ns / 1ps

module register_file (
    input logic clk,
    input logic rst_n,
    input logic[4:0] rd_addr1,
    input logic[4:0] rd_addr2,

    input logic[4:0] wr_addr,
    input logic[31:0] wr_data,
    input logic wr_en,

    output logic[31:0] rd_data1,
    output logic[31:0] rd_data2
);

    logic[31:0] mem [0:31];
    localparam int ZERO_REG = 0;

    // make reads combinational
    assign rd_data1 = mem[rd_addr1];
    assign rd_data2 = mem[rd_addr2];

    // write process should be clocked
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

        end else begin
            if (wr_en && wr_addr != ZERO_REG) begin
                mem[wr_addr] <= wr_data;
            end
        end
    end
endmodule