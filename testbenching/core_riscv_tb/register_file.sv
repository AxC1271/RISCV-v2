`timescale 1ns / 1ps

module register_file (
    input  logic clk,
    input  logic rst_n,

    // read ports
    input  logic[4:0]  rd_addr1,
    input  logic[4:0]  rd_addr2,
    output logic[31:0] rd_data1,
    output logic[31:0] rd_data2,

    // write port
    input  logic[4:0]  wr_addr,
    input  logic[31:0] wr_data,
    input  logic       reg_write,
);

    logic[31:0] registers [0:31];

    assign rd_data1 = registers[rd_addr1];
    assign rd_data2 = registers[rd_addr2];

    // write process should be clocked
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 32'h0;
            end
        end else begin
            if (wr_en && wr_addr != 5'b00000) begin
                registers[wr_addr] <= wr_data;
            end
        end
    end
endmodule