`timescale 1ns / 1ps

module uart_rx # (
    parameter BAUD_RATE = 115200,
    parameter DATA_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,

    // read serially from COM
    input logic rx,
    // write to asynchronous FIFO
    output logic[DATA_WIDTH-1:0] rx_data,
    output logic wr
);

    logic [DATA_WIDTH-1:0] rx_data_reg;
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } rx_state;

    rx_state curr;
    logic baud_clk;
    logic baud_clk_x16;

    // define some local parameters 
    localparam int clk_max = (100_000_000) / (BAUD_RATE * 2);
    localparam int clk_max_x16 = clk_max >> 5;
    localparam int clk_count_x16 = 0;
    localparam int clk_count = 0;
    localparam int start_count = 0;
    localparam int data_count = 0;

    initial begin
        baud_clk <= 0;
        baud_clk_x16 <= 0;
        curr <= IDLE;
    end

    // create some clock divider module here
    // this clock signal will be used for our 
    // reads with the external transmitter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_clk <= 1'b0;
            clk_count <= 0;
        end else begin
            if (clk_count == clk_max) begin
                baud_clk <= ~baud_clk;
                clk_count <= 0;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    // we will create a separate clock divider
    // to verify that rx gets held low on an 
    // actual acknowledge signal instead of 
    // jitters/glitch signals so we have clk_count_x16
    always_ff @(posedge clk) begin
        if (clk_count_x16 == clk_max_x16) begin
            baud_clk_x16 <= ~baud_clk_x16;
        end else begin
            clk_count_x16 <= clk_count_x16 + 1;
        end
    end

    // handle state machine transition here
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_reg <= 8'b00000000;
            curr <= IDLE;
        end else begin
            case (curr)
                IDLE: begin
                    // check if the rx line gets 
                    // de-asserted, else stay IDLE
                    if (!rx) begin
                        curr <= START;
                    end
                end
                START: begin
                    // we will use the 16x generated clock signal
                    // we sample 16 times and check that the rx
                    // signal has been held low for at least half
                    // of the baud clock cycle, or 8 iterations
                    if (start_count == 8) begin
                        curr <= DATA;
                    end else (posedge baud_clk_x16) begin
                    end
                end
                DATA: begin
                    if (posedge baud_clk) begin
                        if (data_count == 8) begin
                            curr <= STOP;
                        end else begin
                            rx_data_reg[data_count] = rx;
                            data_count = data_count + 1;
                        end
                    end
                end
                STOP: begin
                    rx_data <= rx_data_reg;
                    curr <= IDLE;
                end
            endcase
        end
    end


endmodule;