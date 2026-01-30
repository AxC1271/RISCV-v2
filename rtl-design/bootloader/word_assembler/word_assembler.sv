`timescale 1ns / 1ps

module word_assembler #(
    parameter WORD_WIDTH = 32,
    parameter BYTE_WIDTH = 8
) (
    input  logic clk,
    input  logic rst_n,
    
    // input: byte stream from FIFO
    input  logic [BYTE_WIDTH-1:0] byte_in,
    input  logic byte_valid,       // high when byte_in has valid data
    output logic byte_ready,       // high when ready to accept byte
    
    // output: word stream to instruction memory
    output logic [WORD_WIDTH-1:0] word_out,
    output logic word_valid,       // high when word_out is valid
    input  logic word_ready        // high when inst mem can accept word
);

    localparam BYTES_PER_WORD = WORD_WIDTH / BYTE_WIDTH;  // 4 bytes per word
    
    logic [WORD_WIDTH-1:0] word_buffer;
    logic [1:0] byte_count;  // 0-3 for 4 bytes
    
    assign byte_ready = word_ready || (byte_count != 0);  // can accept if not full word
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_buffer <= '0;
            byte_count <= '0;
            word_valid <= 1'b0;
            word_out <= '0;
        end else begin
            // default: deassert word_valid after it's been read
            if (word_valid && word_ready) begin
                word_valid <= 1'b0;
            end
            
            // accept new byte if available and we're ready
            if (byte_valid && byte_ready) begin
                // pack byte into word (little-endian: LSB first)
                case (byte_count)
                    2'd0: word_buffer[7:0]   <= byte_in;
                    2'd1: word_buffer[15:8]  <= byte_in;
                    2'd2: word_buffer[23:16] <= byte_in;
                    2'd3: word_buffer[31:24] <= byte_in;
                endcase
                
                byte_count <= byte_count + 1'b1;
                
                // if this completes a word, output it
                if (byte_count == 2'd3) begin
                    word_out <= {byte_in, word_buffer[23:0]};
                    word_valid <= 1'b1;
                    byte_count <= '0;
                end
            end
        end
    end

endmodule