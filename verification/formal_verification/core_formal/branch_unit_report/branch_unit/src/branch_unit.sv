`timescale 1ns / 1ps

module branch_unit (
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic branch,
    input logic [2:0] funct3,

    input logic [31:0] pc,
    input logic [31:0] imm,

    output logic branch_taken,
    output logic [31:0] branch_target
);

    logic condition_met;

    always_comb begin
        case (funct3)
            3'b000: condition_met = (rs1_data == rs2_data);                    // BEQ
            3'b001: condition_met = (rs1_data != rs2_data);                    // BNE
            3'b100: condition_met = ($signed(rs1_data) < $signed(rs2_data));   // BLT
            3'b101: condition_met = ($signed(rs1_data) >= $signed(rs2_data));  // BGE
            3'b110: condition_met = (rs1_data < rs2_data);                     // BLTU
            3'b111: condition_met = (rs1_data >= rs2_data);                    // BGEU
            default: condition_met = 1'b0;
        endcase
    end

    assign branch_taken = branch && condition_met;
    assign branch_target = pc + imm;

    // --- formal properties ---
    always_comb begin
        if (funct3 == 3'b000)
            assert (condition_met == ((rs1_data ^ rs2_data) == 32'b0));
        if (funct3 == 3'b001)
            assert (condition_met == (|(rs1_data ^ rs2_data)));

        // BLT / BGE / BLTU / BGEU: direct restatement — proves elaboration correctness,
        // not independent of a logic bug duplicated in both places. See note in README.
        if (funct3 == 3'b100)
            assert (condition_met == ($signed(rs1_data) < $signed(rs2_data)));
        if (funct3 == 3'b101)
            assert (condition_met == ($signed(rs1_data) >= $signed(rs2_data)));
        if (funct3 == 3'b110)
            assert (condition_met == (rs1_data < rs2_data));
        if (funct3 == 3'b111)
            assert (condition_met == (rs1_data >= rs2_data));

        // unused funct3 encodings (010, 011) must default to not-taken
        if (funct3 != 3'b000 && funct3 != 3'b001 && funct3 != 3'b100 &&
            funct3 != 3'b101 && funct3 != 3'b110 && funct3 != 3'b111)
            assert (condition_met == 1'b0);

        // branch_taken / branch_target structural checks
        assert (branch_taken == (branch && condition_met));
        assert (branch_target == (pc + imm));

        // safety property, independent of condition_met's value entirely:
        // branch deasserted must always suppress branch_taken, no matter what
        if (!branch)
            assert (branch_taken == 1'b0);

        // reachability — confirms both outcomes are actually possible, not vacuously proven
        cover (branch_taken == 1'b1);
        cover (branch_taken == 1'b0 && branch == 1'b1);
        cover (funct3 == 3'b010); // unused encoding is reachable
        cover ((pc + imm) < pc);  // branch_target wraparound is reachable
    end

endmodule