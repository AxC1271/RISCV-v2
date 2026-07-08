`timescale 1ns / 1ps

module branch_unit_tb();
    // dut signals
    reg  [31:0] rs1_data, rs2_data;
    reg         branch;
    reg  [2:0]  funct3;
    reg  [31:0] pc, imm;
    wire        branch_taken;
    wire [31:0] branch_target;

    // bookkeeping purposes
    integer pass_count, fail_count;

    // instantiate dut here
    branch_unit dut (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch(branch),
        .funct3(funct3),
        .pc(pc),
        .imm(imm),
        .branch_taken(branch_taken),
        .branch_target(branch_target)
    );

    task check;
        input integer    test_id;
        input            exp_taken;
        input [31:0]     exp_target;
        input [127:0]    desc;
        begin
            #1;
            if (branch_taken !== exp_taken || branch_target !== exp_target) begin
                $display("FAIL [%0d] %s | taken=%b(exp %b)  target=0x%08h(exp 0x%08h)",
                    test_id, desc,
                    branch_taken, exp_taken,
                    branch_target, exp_target);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%0d] %s", test_id, desc);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task apply;
        input [31:0] rs1_i, rs2_i, pc_i, imm_i;
        input        branch_i;
        input [2:0]  funct3_i;
        begin
            rs1_data = rs1_i;
            rs2_data = rs2_i;
            pc       = pc_i;
            imm      = imm_i;
            branch   = branch_i;
            funct3   = funct3_i;
        end
    endtask

    // convenience: pc=0x100, imm=0x10 for most tests
    localparam PC  = 32'h0000_0100;
    localparam IMM = 32'h0000_0010;
    localparam TGT = PC + IMM;       // 0x110 — expected target when branch taken

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ================================================================
        // GROUP 1 — branch=0, nothing should fire regardless of condition
        // ================================================================

        apply(32'd5, 32'd5, PC, IMM, 0, 3'b000);   // BEQ would be true but branch=0
        check(1, 0, TGT, "no_branch_beq  ");

        apply(32'd1, 32'd2, PC, IMM, 0, 3'b001);   // BNE would be true
        check(2, 0, TGT, "no_branch_bne  ");

        apply(32'd1, 32'd2, PC, IMM, 0, 3'b100);   // BLT would be true
        check(3, 0, TGT, "no_branch_blt  ");

        // ================================================================
        // GROUP 2 — BEQ (funct3 = 3'b000)
        // ================================================================

        apply(32'd7,  32'd7,  PC, IMM, 1, 3'b000);
        check(4, 1, TGT, "beq_taken      ");   // rs1 == rs2

        apply(32'd7,  32'd8,  PC, IMM, 1, 3'b000);
        check(5, 0, TGT, "beq_not_taken  ");   // rs1 != rs2

        apply(32'd0,  32'd0,  PC, IMM, 1, 3'b000);
        check(6, 1, TGT, "beq_zero_zero  ");   // both x0

        apply(32'hFFFF_FFFF, 32'hFFFF_FFFF, PC, IMM, 1, 3'b000);
        check(7, 1, TGT, "beq_max_max    ");   // max unsigned

        // ================================================================
        // GROUP 3 — BNE (funct3 = 3'b001)
        // ================================================================

        apply(32'd3,  32'd4,  PC, IMM, 1, 3'b001);
        check(8, 1, TGT, "bne_taken      ");

        apply(32'd3,  32'd3,  PC, IMM, 1, 3'b001);
        check(9, 0, TGT, "bne_not_taken  ");

        // ================================================================
        // GROUP 4 — BLT signed (funct3 = 3'b100)
        // ================================================================

        apply(32'd1,  32'd2,  PC, IMM, 1, 3'b100);
        check(10, 1, TGT, "blt_pos_taken  ");   // 1 < 2

        apply(32'd2,  32'd1,  PC, IMM, 1, 3'b100);
        check(11, 0, TGT, "blt_pos_ntaken ");   // 2 >= 1

        apply(32'd5,  32'd5,  PC, IMM, 1, 3'b100);
        check(12, 0, TGT, "blt_equal      ");   // equal → not taken

        // signed: -1 < 1
        apply(32'hFFFF_FFFF, 32'd1, PC, IMM, 1, 3'b100);
        check(13, 1, TGT, "blt_neg_lt_pos ");

        // signed: 1 < -1 should be false
        apply(32'd1, 32'hFFFF_FFFF, PC, IMM, 1, 3'b100);
        check(14, 0, TGT, "blt_pos_gt_neg ");

        // ================================================================
        // GROUP 5 — BGE signed (funct3 = 3'b101)
        // ================================================================

        apply(32'd5,  32'd3,  PC, IMM, 1, 3'b101);
        check(15, 1, TGT, "bge_gt_taken   ");   // 5 >= 3

        apply(32'd3,  32'd3,  PC, IMM, 1, 3'b101);
        check(16, 1, TGT, "bge_eq_taken   ");   // equal counts

        apply(32'd2,  32'd5,  PC, IMM, 1, 3'b101);
        check(17, 0, TGT, "bge_lt_ntaken  ");   // 2 < 5

        // signed: -1 >= 1 should be false
        apply(32'hFFFF_FFFF, 32'd1, PC, IMM, 1, 3'b101);
        check(18, 0, TGT, "bge_neg_lt_pos ");

        // signed: 1 >= -1 should be true
        apply(32'd1, 32'hFFFF_FFFF, PC, IMM, 1, 3'b101);
        check(19, 1, TGT, "bge_pos_ge_neg ");

        // ================================================================
        // GROUP 6 — BLTU unsigned (funct3 = 3'b110)
        // ================================================================

        apply(32'd1,  32'd2,  PC, IMM, 1, 3'b110);
        check(20, 1, TGT, "bltu_taken     ");

        apply(32'd2,  32'd1,  PC, IMM, 1, 3'b110);
        check(21, 0, TGT, "bltu_not_taken ");

        apply(32'd5,  32'd5,  PC, IMM, 1, 3'b110);
        check(22, 0, TGT, "bltu_equal     ");

        // unsigned: 0xFFFFFFFF > 1, so BLTU not taken
        apply(32'hFFFF_FFFF, 32'd1, PC, IMM, 1, 3'b110);
        check(23, 0, TGT, "bltu_big_gt_1  ");

        // unsigned: 1 < 0xFFFFFFFF, so BLTU taken
        apply(32'd1, 32'hFFFF_FFFF, PC, IMM, 1, 3'b110);
        check(24, 1, TGT, "bltu_1_lt_big  ");

        // ================================================================
        // GROUP 7 — BGEU unsigned (funct3 = 3'b111)
        // ================================================================

        apply(32'd5,  32'd3,  PC, IMM, 1, 3'b111);
        check(25, 1, TGT, "bgeu_taken     ");

        apply(32'd3,  32'd3,  PC, IMM, 1, 3'b111);
        check(26, 1, TGT, "bgeu_eq_taken  ");

        apply(32'd2,  32'd5,  PC, IMM, 1, 3'b111);
        check(27, 0, TGT, "bgeu_not_taken ");

        // unsigned: 0xFFFFFFFF >= 1 → taken
        apply(32'hFFFF_FFFF, 32'd1, PC, IMM, 1, 3'b111);
        check(28, 1, TGT, "bgeu_big_ge_1  ");

        // ================================================================
        // GROUP 8 — branch_target arithmetic
        // ================================================================

        // negative offset (imm as 2's complement): PC=0x200, imm=-4 → target=0x1FC
        apply(32'd1, 32'd1, 32'h0000_0200, 32'hFFFF_FFFC, 1, 3'b000);
        check(29, 1, 32'h0000_01FC, "target_neg_off ");

        // forward jump: PC=0x400, imm=0x40 → target=0x440
        apply(32'd0, 32'd0, 32'h0000_0400, 32'h0000_0040, 1, 3'b000);
        check(30, 1, 32'h0000_0440, "target_fwd     ");

        // target wrap: PC=0xFFFFFFFC, imm=8 → target=0x4 (32-bit wrap)
        apply(32'd0, 32'd0, 32'hFFFF_FFFC, 32'h0000_0008, 1, 3'b000);
        check(31, 1, 32'h0000_0004, "target_wrap    ");

        // ================================================================
        // GROUP 9 — default/invalid funct3
        // ================================================================

        apply(32'd1, 32'd1, PC, IMM, 1, 3'b010);   // undefined encoding
        check(32, 0, TGT, "invalid_funct3 ");

        apply(32'd1, 32'd1, PC, IMM, 1, 3'b011);
        check(33, 0, TGT, "invalid_funct3b");

        // ================================================================
        // Summary
        // ================================================================
        #5;
        $display("\n========================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");
        $finish;
    end

endmodule