`timescale 1ns / 1ps

module core_riscv_tb();
    localparam CLK_PERIOD  = 10;
    localparam IMEM_WORDS  = 1024;   // 4 kB instruction ROM
    localparam DMEM_WORDS  = 16384;  // 64 kB data memory

    logic clk;
    logic rst_n;
    logic cpu_enable;

    // I-cache <-> imem
    logic [31:0] imem_addr;
    logic imem_req;
    logic [31:0] imem_rdata;
    logic imem_ready;

    // D-cache <-> dmem
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic dmem_rd_en;
    logic dmem_wr_en;
    logic [2:0] dmem_size;
    logic [31:0] dmem_rdata;
    logic dmem_ready;

    // debugging purposes
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic [31:0] debug_reg_data;
    logic        debug_halted;

    core_riscv dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_enable(cpu_enable),

        .imem_addr(imem_addr),
        .imem_req(imem_req),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),

        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rd_en(dmem_rd_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_size(dmem_size),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),

        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_reg_data(debug_reg_data),
        .debug_halted(debug_halted)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    logic [31:0] imem [0:IMEM_WORDS-1];

    initial begin
        // zero-fill
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // NOP

        imem['h00 >> 2] = 32'h01000093; // ADDI x1, x0, 16
        imem['h04 >> 2] = 32'h02A00113; // ADDI x2, x0, 42
        imem['h08 >> 2] = 32'h06400193; // ADDI x3, x0, 100
        imem['h0C >> 2] = 32'hFFF00213; // ADDI x4, x0, -1
        imem['h10 >> 2] = 32'h0020A023; // SW x2, 0(x1)
        imem['h14 >> 2] = 32'h0030A223; // SW x3, 4(x1)
        imem['h18 >> 2] = 32'h0040A423; // SW x4, 8(x1)
        imem['h1C >> 2] = 32'h0000A283; // LW x5, 0(x1)
        imem['h20 >> 2] = 32'h0040A303; // LW x6, 4(x1)
        imem['h24 >> 2] = 32'h006283B3; // ADD x7, x5, x6
        imem['h28 >> 2] = 32'h40530433; // SUB x8, x6, x5
        imem['h2C >> 2] = 32'h0062F4B3; // AND x9, x5, x6
        imem['h30 >> 2] = 32'h0062E533; // OR x10, x5, x6
        imem['h34 >> 2] = 32'h00510463; // BEQ x2, x5, +8
        imem['h38 >> 2] = 32'h12300593; // skipped
        imem['h3C >> 2] = 32'h60000593; // target
        // NOPs from 0x44 onward (already filled)
    end

    // combinational instruction memory - no latency
    assign imem_ready = imem_req;
    assign imem_rdata = imem_req ? imem[imem_addr[31:2]] : 32'h0000_0013;

    // predefined data memory - combinational reads, registered writes
    logic [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        for (int i = 0; i < DMEM_WORDS; i++)
            dmem[i] = 32'h0;
    end

    assign dmem_ready = dmem_rd_en || dmem_wr_en;
    assign dmem_rdata = dmem_rd_en ? dmem[dmem_addr[31:2]] : 32'b0;

    always_ff @(posedge clk) begin
        if (dmem_wr_en)
            dmem[dmem_addr[31:2]] <= dmem_wdata;
    end

    // automatic helper functions
    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.rf.mem[n];
    endfunction

    // checking for pass/fail rate
    int pass_count;
    int fail_count;

    task automatic check_reg (
        input int unsigned reg_num,
        input logic [31:0] expected,
        input string label
    );
        logic [31:0] got;
        got = read_reg(reg_num);
        if (got === expected) begin
            $display("  PASS  %-20s  x%-20d = 0x%08h", label, reg_num, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-20s  x%-2d expected=0x%08h  got=0x%08h",
                     label, reg_num, expected, got);
            fail_count++;
        end
    endtask

    task automatic check_dmem (
        input logic [31:0] byte_addr,
        input logic [31:0] expected,
        input string label
    );
        logic [31:0] got;
        got = dmem[byte_addr[31:2]];
        if (got === expected) begin
            $display("  PASS  %-20s  dmem[0x%08h] = 0x%08h", label, byte_addr, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-20s  dmem[0x%08h] expected=0x%08h  got=0x%08h",
                     label, byte_addr, expected, got);
            fail_count++;
        end
    endtask

    initial begin
        // init
        rst_n = 1'b0;
        cpu_enable = 1'b0;
        pass_count = 0;
        fail_count = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // Release CPU
        cpu_enable = 1'b1;

        // run 3000ns to let all instructions complete
        // worst case: each instruction may suffer a D-cache miss
        // (7 cycles) plus pipeline stages (5) plus branch penalty (2)
        // 20 instructions * 15 cycles/instr = 300 cycles is generous
        $display("\n[TB] CPU running...");
        repeat (300) @(posedge clk);

        $display("\n========== REGISTER FILE CHECKS ==========");
        check_reg(1,  32'h00000010, "ADDI x1=16");
        check_reg(2,  32'd42,        "ADDI x2=42");
        check_reg(3,  32'd100,       "ADDI x3=100");
        check_reg(4,  32'hFFFFFFFF, "ADDI x4=-1");
        check_reg(5,  32'd42,        "LW x5=42");
        check_reg(6,  32'd100,       "LW x6=100");
        check_reg(7,  32'd142,       "ADD x7=142");
        check_reg(8,  32'd58,        "SUB x8=58");
        check_reg(9,  32'd32,        "AND x9=32");
        check_reg(10, 32'd110,       "OR  x10=110");
        check_reg(11, 32'h00000600, "BEQ taken x11=0x600");

        $display("\n========== SUMMARY ==========");
        $display("PASS: %0d   FAIL: %0d   TOTAL: %0d",
                 pass_count, fail_count, pass_count + fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED -- check pipeline/forwarding/cache");

        $finish;
    end

    // timeout watchdog ends at 5000ns
    initial begin
        #50000;
        $display("[TIMEOUT] Simulation exceeded 50us -- possible hang");
        $fatal;
    end
endmodule