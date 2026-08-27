`timescale 1ns / 1ps

module tb_matrix_cached();
    localparam CLK_PERIOD  = 10;
    localparam IMEM_WORDS  = 1024;
    localparam DMEM_WORDS  = 16384;
    localparam BASE        = 32'h0000_0000;

    logic clk, rst_n, cpu_enable;
    logic [31:0] imem_addr, imem_rdata;
    logic        imem_req, imem_ready;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic        dmem_rd_en, dmem_wr_en, dmem_ready;
    logic [31:0] debug_pc, debug_instr, debug_reg_data;
    logic        debug_halted;

    core_riscv_cached #(.RESET_VECTOR(BASE)) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .cpu_enable     (cpu_enable),
        .imem_addr      (imem_addr),
        .imem_req       (imem_req),
        .imem_rdata     (imem_rdata),
        .imem_ready     (imem_ready),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_rd_en     (dmem_rd_en),
        .dmem_wr_en     (dmem_wr_en),
        .dmem_rdata     (dmem_rdata),
        .dmem_ready     (dmem_ready),
        .debug_pc       (debug_pc),
        .debug_instr    (debug_instr),
        .debug_reg_data (debug_reg_data),
        .debug_halted   (debug_halted)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Instruction backing memory
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] imem_index;
    assign imem_index = (imem_addr - BASE) >> 2;

    int MEM_LATENCY;
    initial begin
        if (!$value$plusargs("lat=%d", MEM_LATENCY)) MEM_LATENCY = 1;
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // NOP

        imem['h000 >> 2] = 32'h00100093; // addi x1, x0, 1      # A[0][0] = 1
        imem['h004 >> 2] = 32'h00200113; // addi x2, x0, 2      # A[0][1] = 2
        imem['h008 >> 2] = 32'h00300193; // addi x3, x0, 3      # A[0][2] = 3
        imem['h00C >> 2] = 32'h00900213; // addi x4, x0, 9      # B[0][0] = 9
        imem['h010 >> 2] = 32'h00600293; // addi x5, x0, 6      # B[1][0] = 6
        imem['h014 >> 2] = 32'h00300313; // addi x6, x0, 3      # B[2][0] = 3
        
        imem['h018 >> 2] = 32'h00208133; // add x2, x1, x2      # x2 = 1+2 = 3
        imem['h01C >> 2] = 32'h00318133; // add x2, x2, x3      # x2 = 3+3 = 6
        imem['h020 >> 2] = 32'h00428133; // add x2, x2, x4      # x2 = 6+9 = 15
        imem['h024 >> 2] = 32'h00528133; // add x2, x2, x5      # x2 = 15+6 = 21
        imem['h028 >> 2] = 32'h00628133; // add x2, x2, x6      # x2 = 21+3 = 24
        
        imem['h02C >> 2] = 32'h00208233; // add x4, x1, x2      # x4 = 1+24 = 25
        imem['h030 >> 2] = 32'h00318233; // add x4, x2, x3      # x4 = 24+3 = 27
        imem['h034 >> 2] = 32'h00428233; // add x4, x2, x4      # x4 = 24+27 = 51
        
        imem['h038 >> 2] = 32'h00100073; // ebreak
    end

    assign imem_rdata = (imem_index < IMEM_WORDS) ? imem[imem_index[$clog2(IMEM_WORDS)-1:0]] : 32'h00000013;

    int imem_cnt;
    assign imem_ready = imem_req && (imem_cnt == MEM_LATENCY-1);
    always_ff @(posedge clk) begin
        if (!rst_n)          imem_cnt <= 0;
        else if (!imem_req)  imem_cnt <= 0;
        else if (imem_ready) imem_cnt <= 0;
        else                 imem_cnt <= imem_cnt + 1;
    end

    // Data backing memory
    logic [31:0] dmem [0:DMEM_WORDS-1];
    initial for (int i = 0; i < DMEM_WORDS; i++) dmem[i] = 32'h0;

    logic [31:0] dmem_idx;
    assign dmem_idx   = dmem_addr[$clog2(DMEM_WORDS)+1:2];
    assign dmem_rdata = dmem[dmem_idx];

    int dmem_cnt;
    assign dmem_ready = (dmem_rd_en || dmem_wr_en) && (dmem_cnt == MEM_LATENCY-1);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dmem_cnt <= 0;
        end else if (!(dmem_rd_en || dmem_wr_en)) begin
            dmem_cnt <= 0;
        end else if (dmem_ready) begin
            dmem_cnt <= 0;
        end else begin
            dmem_cnt <= dmem_cnt + 1;
        end

        if (dmem_wr_en && dmem_ready) begin
            dmem[dmem_idx] <= dmem_wdata;
        end
    end

    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.rf.mem[n];
    endfunction

    int pass_count = 0, fail_count = 0;
    task automatic check_reg (
        input int unsigned reg_num,
        input logic [31:0] expected,
        input string       label
    );
        logic [31:0] got;
        got = read_reg(reg_num);
        if (got === expected) begin
            $display("  PASS  %-22s x%-2d                   = 0x%08h (%0d)", label, reg_num, got, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-22s x%-2d  expected=0x%08h  got=0x%08h", label, reg_num, expected, got);
            fail_count++;
        end
    endtask

    longint cycle_count, retire_count;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_count  <= 0;
            retire_count <= 0;
        end else begin
            if (cpu_enable && !debug_halted) begin
                cycle_count <= cycle_count + 1;
                if (dut.wb_valid && !dut.memwb_stall)
                    retire_count <= retire_count + 1;
            end
        end
    end

    initial begin
        rst_n = 1'b0;
        cpu_enable = 1'b0;
        #1;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        cpu_enable = 1'b1;

        $display("\n[TB-MATRIX] Cached Matrix Benchmark starting...");
        fork
            begin
                wait (debug_halted);
                $display("[TB-MATRIX] EBREAK retired at T=%0t", $time);
            end
            begin
                repeat (60000) @(posedge clk);
            end
        join_any
        disable fork;
        repeat (4) @(posedge clk);

        check_reg(1, 32'd1,  "A[0][0] x1");
        check_reg(2, 32'd24, "Acc sum x2");
        check_reg(3, 32'd3,  "A[0][2] x3");
        check_reg(4, 32'd51, "Final result x4");

        $display("\n========== IPC (Matrix Multiply) ==========");
        $display("cycles=%0d  retired=%0d  IPC=%0.4f",
                 cycle_count, retire_count,
                 real'(retire_count) / real'(cycle_count));
        
        $display("\n========== SUMMARY ==========");
        $display("PASS: %0d   FAIL: %0d   TOTAL: %0d", pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED\n");
        else $display("SOME TESTS FAILED\n");
        $finish;
    end

    initial begin
        #5000000;
        $display("[TIMEOUT] Simulation exceeded 5ms");
        $fatal;
    end

endmodule