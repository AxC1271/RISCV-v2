`timescale 1ns / 1ps

module async_fifo # (
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 64,
) (
    // write interface
    input logic clk_w,
    input logic rst_n_w,
    input logic wr_en,
    input logic[DATA_WIDTH-1:0] wr_data,

    // read interface
    input logic clk_r,
    input logic rst_n_r,
    input logic rd_en,
    output logic[DATA_WIDTH-1:0] rd_data,

    // status flags
    output logic empty,
    output logic full
);
    // our dual port mem block
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [6:0] rd_ptr_bin, wr_ptr_bin := 0;
    logic [6:0] rd_ptr_gray, rd_ptr_gray1, rd_ptr_gray2;
    logic [6:0] wr_ptr_gray, wr_ptr_gray1, wr_ptr_gray2;

    // assign gray code values and flags
    always_comb @(*) begin
        // gray code converters
        rd_ptr_gray <= rd_ptr_bin ^ (rd_ptr_bin >> 1);
        wr_ptr_gray <= wr_ptr_bin ^ (wr_ptr_bin >> 1);

        // assert almost empty and full statuses
        empty <= (rd_ptr_gray == wr_ptr_gray2);
        full <= (wr_ptr_gray == {~rd_ptr_gray2[6:5], rd_ptr_gray2[4:0]}); 
    end

    // synchronize the read gray codes to the write domain
    always_ff @(posedge clk_w or negedge rst_n_w) begin
        if (!rst_n_w) begin
            rd_ptr_gray1 <= 0;
            rd_ptr_gray2 <= 0;
        end else begin
            rd_ptr_gray1 <= rd_ptr_gray;
            rd_ptr_gray2 <= rd_ptr_gray1;
        end
    end

    // synchronize the write gray codes to the read domain
    always_ff @(posedge clk_r or negedge rst_n_r) begin
        if (!rst_n_r) begin
            wr_ptr_gray1 <= 0;
            wr_ptr_gray2 <= 0;
        end else begin
            wr_ptr_gray1 <= wr_ptr_gray;
            wr_ptr_gray2 <= wr_ptr_gray1;
        end
    end

    // handle write interface
    always_ff @(posedge clk_w) begin
        if (wr_en && !full) begin
            mem[wr_ptr_bin] <= wr_data;
        end
    end
    // handle write pointer increment
    always_ff @(posedge clk_w or negedge rst_n_w) begin
        if (!rst_n_w) begin
            wr_ptr_bin <= 0;
        end else if (wr_en && !full) begin
            wr_ptr_bin <= wr_ptr_bin + 1;
        end
    end

    // handle read interface
    always_ff @(posedge clk_r) begin
        if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr_bin];
        end
    end
    // handle read pointer increment
    always_ff @(posedge clk_r or negedge rst_n_r) begin
        if (!rst_n_r) begin
            rd_ptr_bin <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr_bin <= rd_ptr_bin + 1;
        end
    end
endmodule