`timescale 1ns / 1ps

module instr_memory # (
    parameter DEPTH = 1024,
    parameter PRELOAD_PROGRAM = 1
) (
    input logic clk,
    input logic rst_n,

    // bootloader write port
    input logic wr_en,
    input logic [31:0] wr_data,
    input logic [9:0]  wr_addr,

    // cpu / icache read port
    input logic [31:0] rd_addr,
    input logic rd_en,
    output logic [31:0] rd_data,
    output logic rd_ready
);

    logic [31:0] mem [0:DEPTH-1];

    generate
        if (PRELOAD_PROGRAM) begin : gen_preload
            initial begin
                mem[0]  = 32'h00000093;
                mem[1]  = 32'h00100113;
                mem[2]  = 32'h00000213;
                mem[3]  = 32'h00B00293;
                mem[4]  = 32'h00520763;
                mem[5]  = 32'h002081B3;
                mem[6]  = 32'h00010093;
                mem[7]  = 32'h00018113;
                mem[8]  = 32'h00120213;
                mem[9]  = 32'hFE000AE3;
                mem[10] = 32'h0001807F;
                mem[11] = 32'hFE000FE3;

                for (int i = 12; i < DEPTH; i++) begin
                    mem[i] = 32'h00000013; // nop instructions
                end
            end
        end else begin : gen_no_preload
            initial begin
                for (int i = 0; i < DEPTH; i++) begin
                    mem[i] = 32'h00000013;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end

        if (rd_en) begin
            rd_data <= mem[rd_addr[11:2]];
        end
    end

    // 1-cycle synchronous memory response
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ready <= 1'b0;
        end else begin
            rd_ready <= rd_en;
        end
    end

endmodule