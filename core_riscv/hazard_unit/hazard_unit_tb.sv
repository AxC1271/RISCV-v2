`timescale 1ns / 1ps

module hazard_unit_tb();

    // dut signalsd
    logic [4:0] id_rs1, id_rs2, ex_rd;
    logic ex_mem_read, mem_stall;
    logic stall, flush_id_ex;

    integer pass_count, fail_count;

    // instantiate the unit under test
    hazard_unit dut (
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .ex_rd       (ex_rd),
        .ex_mem_read (ex_mem_read),
        .mem_stall   (mem_stall),
        .stall       (stall),
        .flush_id_ex (flush_id_ex)
    );

    // write a task checker 
    task check;
        input [63:0] test_id;
        input        exp_stall, exp_flush;
        input [79:0] desc;  // 10-char ASCII label
        begin
            #1; // let combinational logic settle
            if (stall !== exp_stall || flush_id_ex !== exp_flush) begin
                $display("FAIL [%0d] %s | stall=%b(exp %b)  flush=%b(exp %b)  rs1=%0d rs2=%0d rd=%0d mem_read=%b mem_stall=%b",
                    test_id, desc,
                    stall, exp_stall,
                    flush_id_ex, exp_flush,
                    id_rs1, id_rs2, ex_rd, ex_mem_read, mem_stall);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%0d] %s", test_id, desc);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // helper to apply stimulus
    task apply;
        input [4:0] rs1_i, rs2_i, rd_i;
        input       mem_read_i, mem_stall_i;
        begin
            id_rs1       = rs1_i;
            id_rs2       = rs2_i;
            ex_rd        = rd_i;
            ex_mem_read  = mem_read_i;
            mem_stall    = mem_stall_i;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ================================================================
        // GROUP 1 — No hazard (no stall expected)
        // ================================================================

        // 1. No load, rs1/rs2 don't match rd
        apply(5'd1, 5'd2, 5'd5, 0, 0);
        check(1, 0, 0, "no_hazard1");

        // 2. rs1 matches rd but ex_mem_read=0 (not a load)
        apply(5'd3, 5'd4, 5'd3, 0, 0);
        check(2, 0, 0, "no_ld_rs1 ");

        // 3. rs2 matches rd but ex_mem_read=0
        apply(5'd4, 5'd3, 5'd3, 0, 0);
        check(3, 0, 0, "no_ld_rs2 ");

        // 4. Load but rd=x0 (writes to x0 are meaningless)
        apply(5'd0, 5'd0, 5'd0, 1, 0);
        check(4, 0, 0, "rd_zero   ");

        // 5. Load, rd=x0, rs1=x0 — x0 is not a true dependency
        apply(5'd0, 5'd1, 5'd0, 1, 0);
        check(5, 0, 0, "rs1_zero  ");

        // 6. No overlap whatsoever
        apply(5'd10, 5'd11, 5'd12, 1, 0);
        check(6, 0, 0, "all_diff  ");

        // ================================================================
        // GROUP 2 — Load-use hazard (stall + flush expected)
        // ================================================================

        // 7. Load, rs1 == ex_rd
        apply(5'd5, 5'd6, 5'd5, 1, 0);
        check(7, 1, 1, "ld_rs1    ");

        // 8. Load, rs2 == ex_rd
        apply(5'd6, 5'd5, 5'd5, 1, 0);
        check(8, 1, 1, "ld_rs2    ");

        // 9. Load, both rs1 and rs2 == ex_rd
        apply(5'd7, 5'd7, 5'd7, 1, 0);
        check(9, 1, 1, "ld_both   ");

        // 10. Load hazard on rs1, rs2 irrelevant
        apply(5'd8, 5'd31, 5'd8, 1, 0);
        check(10, 1, 1, "ld_rs1_x31");

        // 11. Load hazard on rs2, rs1 irrelevant
        apply(5'd31, 5'd9, 5'd9, 1, 0);
        check(11, 1, 1, "ld_rs2_x31");

        // 12. Load hazard, max register index
        apply(5'd31, 5'd30, 5'd31, 1, 0);
        check(12, 1, 1, "ld_maxreg ");

        // ================================================================
        // GROUP 3 — mem_stall asserted (stall expected, flush may vary)
        // ================================================================

        // 13. Pure memory stall, no load-use hazard
        apply(5'd1, 5'd2, 5'd5, 0, 1);
        check(13, 1, 0, "mem_stall ");    // stall=1, flush depends on your impl

        // 14. mem_stall + load-use hazard simultaneously
        apply(5'd5, 5'd6, 5'd5, 1, 1);
        check(14, 1, 1, "ms_ld_both");

        // 15. mem_stall, rd=x0 (no useful write), no load hazard
        apply(5'd1, 5'd2, 5'd0, 0, 1);
        check(15, 1, 0, "ms_rd_zero");

        // ================================================================
        // GROUP 4 — Edge cases
        // ================================================================

        // 16. All signals de-asserted after active — should clear cleanly
        apply(5'd5, 5'd5, 5'd5, 1, 1);   // set high first
        #2;
        apply(5'd1, 5'd2, 5'd3, 0, 0);
        check(16, 0, 0, "clear_test");

        // 17. Rapid toggle: assert then de-assert mem_stall
        apply(5'd1, 5'd2, 5'd1, 0, 1);
        #2;
        apply(5'd1, 5'd2, 5'd1, 0, 0);
        check(17, 0, 0, "ms_deasser");

        // 18. Load hazard clears when ex_rd changes away
        apply(5'd5, 5'd6, 5'd5, 1, 0);
        #2;
        apply(5'd5, 5'd6, 5'd9, 1, 0);   // rd no longer matches
        check(18, 0, 0, "ld_clr_rd ");

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