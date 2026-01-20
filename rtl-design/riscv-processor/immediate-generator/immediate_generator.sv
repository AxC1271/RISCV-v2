`timescale 1ns / 1ps

module immediate_generator (
    input logic[31:0] instruction,
    output logic[31:0] immediate
);
    logic[6:0] instr_i;

    always_comb begin
        instr_i <= instruction[6:0];

        case (instr_i)
            // R-type instructions don't have immediates so they're skipped
            7'b0010011: begin // I-type instruction
                immediate <= instruction[31:20];
            end
            7'b010011: begin // S-type instruction
                immediate <= {instruction[31:25], instruction[11:7]};
            end
            7'b1100011: begin // B-type instruction
                immediate <= {instruction[31], instruction[7], instruction[30:25], instruction[11:8]};
            end
            7'b0110111, 7'b0010111: begin // U-type instruction
                immediate <= {instruction[31:12]};
            end
            7'b1101111: begin // J-type instruction
                immediate <= {instruction[31], instruction[19:12], instruction[20], instruction[30:21]};
            end
            default: begin
                immediate <= 0; // default value
            end
        endcase
    end
endmodule