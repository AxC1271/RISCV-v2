`timescale 1ns / 1ps

module immediate_generator (
    input logic [31:0] instruction,
    output logic [31:0] immediate
);

    logic [6:0] opcode;

    always_comb begin
        opcode = instruction[6:0];

        case (opcode)

            // I-type: ADDI, LW, JALR, etc.
            7'b0010011, // OP-IMM
            7'b0000011, // LOAD
            7'b1100111: // JALR
                immediate = {{20{instruction[31]}}, instruction[31:20]};

            // S-type: SW
            7'b0100011:
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            // B-type: BEQ, BNE, etc.
            7'b1100011:
                immediate = {{19{instruction[31]}},
                             instruction[31],
                             instruction[7],
                             instruction[30:25],
                             instruction[11:8],
                             1'b0};

            // U-type: LUI, AUIPC
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                immediate = {instruction[31:12], 12'b0};

            // J-type: JAL
            7'b1101111:
                immediate = {{11{instruction[31]}},
                             instruction[31],
                             instruction[19:12],
                             instruction[20],
                             instruction[30:21],
                             1'b0};

            default:
                immediate = 32'b0;
        endcase
    end

endmodule