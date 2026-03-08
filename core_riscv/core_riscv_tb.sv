`timescale 1ns / 1ps

// ============================================================
// core_riscv_tb
//
// Testbench for the 5-stage pipelined RISC-V core.
//
// Setup:
//   - Instruction memory is a simple combinational ROM preloaded
//     with a hand-assembled RISC-V program.
//   - Data memory is a combinational read / registered write model,
//     same pattern as the cache testbenches.
//   - The core's I-cache and D-cache are instantiated inside
//     core_riscv, so this TB only drives the external memory ports.
//
// Program (base address 0x0000_0000):
//
//   # Load immediate values via LUI + ADDI
//   0x00: lui   x1,  0x1          # x1  = 0x0000_1000
//   0x04: addi  x1,  x1,  0x010   # x1  = 0x0000_1010  (data base addr)
//   0x08: lui   x2,  0x0          # x2  = 0
//   0x0C: addi  x2,  x2,  42      # x2  = 42
//   0x10: addi  x3,  x0,  100     # x3  = 100
//   0x14: addi  x4,  x0,  -1      # x4  = 0xFFFF_FFFF
//
//   # Store to data memory
//   0x18: sw    x2,  0(x1)        # dmem[0x1010] = 42
//   0x1C: sw    x3,  4(x1)        # dmem[0x1014] = 100
//   0x20: sw    x4,  8(x1)        # dmem[0x1018] = 0xFFFF_FFFF
//
//   # Load back and compute
//   0x24: lw    x5,  0(x1)        # x5  = dmem[0x1010] = 42
//   0x28: lw    x6,  4(x1)        # x6  = dmem[0x1014] = 100
//   0x2C: add   x7,  x5,  x6      # x7  = 142
//   0x30: sub   x8,  x6,  x5      # x8  = 58
//   0x34: and   x9,  x5,  x6      # x9  = 42 & 100 = 32
//   0x38: or    x10, x5,  x6      # x10 = 42 | 100 = 110
//
//   # Branch test: BEQ taken (x2 == x5, both 42)
//   0x3C: beq   x2,  x5,  +8      # if x2==x5, jump to 0x44
//   0x40: addi  x11, x0,  0xBAD   # should be skipped
//   0x44: addi  x11, x0,  0x600   # x11 = 0x600 (branch landed here)
//
//   # Infinite NOP loop (keeps pipeline from running off end of memory)
//   0x48: addi  x0, x0, 0         # NOP
//   0x4C: addi  x0, x0, 0         # NOP
//   ...
//
// Expected register values after completion:
//   x1  = 0x0000_1010
//   x2  = 42
//   x3  = 100
//   x4  = 0xFFFF_FFFF
//   x5  = 42
//   x6  = 100
//   x7  = 142
//   x8  = 58
//   x9  = 32
//   x10 = 110
//   x11 = 0x600   (branch taken, bad path skipped)
//
// Expected data memory values:
//   dmem[0x1010] = 42
//   dmem[0x1014] = 100
//   dmem[0x1018] = 0xFFFF_FFFF
// ============================================================

module core_riscv_tb ();

    // -------------------------------------------------------
    // Parameters
    // -------------------------------------------------------
    localparam CLK_PERIOD  = 10;
    localparam IMEM_WORDS  = 1024;   // 4 kB instruction ROM
    localparam DMEM_WORDS  = 16384;  // 64 kB data memory

    // -------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        cpu_enable;

    // I-cache <-> imem
    logic [31:0] imem_addr;
    logic        imem_req;
    logic [31:0] imem_rdata;
    logic        imem_ready;

    // D-cache <-> dmem
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [2:0]  dmem_size;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    // Debug
    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic [31:0] debug_reg_data;
    logic        debug_halted;

    // -------------------------------------------------------
    // DUT
    // -------------------------------------------------------
    core_riscv dut (
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
        .dmem_size      (dmem_size),
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

    // -------------------------------------------------------
    // Instruction ROM — combinational, preloaded
    //
    // Encoding reference (RV32I):
    //   LUI   rd, imm20          : imm[31:12] | rd | 0110111
    //   ADDI  rd, rs1, imm12     : imm[11:0]  | rs1 | 000 | rd | 0010011
    //   SW    rs2, imm(rs1)      : imm[11:5]  | rs2 | rs1 | 010 | imm[4:0] | 0100011
    //   LW    rd,  imm(rs1)      : imm[11:0]  | rs1 | 010 | rd  | 0000011
    //   ADD   rd, rs1, rs2       : 0000000 | rs2 | rs1 | 000 | rd | 0110011
    //   SUB   rd, rs1, rs2       : 0100000 | rs2 | rs1 | 000 | rd | 0110011
    //   AND   rd, rs1, rs2       : 0000000 | rs2 | rs1 | 111 | rd | 0110011
    //   OR    rd, rs1, rs2       : 0000000 | rs2 | rs1 | 110 | rd | 0110011
    //   BEQ   rs1, rs2, imm13    : imm[12|10:5] | rs2 | rs1 | 000 | imm[4:1|11] | 1100011
    //   NOP = ADDI x0, x0, 0    : 32'h0000_0013
    // -------------------------------------------------------
    logic [31:0] imem [0:IMEM_WORDS-1];

    initial begin
        // zero-fill
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h0000_0013; // NOP

        // --- Build x1 = 0x0000_1010 ---
        // LUI x1, 1         -> 0x00001_0_37 -> imm=1, rd=1, op=0110111
        // imm[31:12]=1 => bits[31:12]=20'h00001, rd=5'b00001
        // 32'b 00000000000000000001_00001_0110111
        imem['h00 >> 2] = 32'h00001_0B7; // LUI x1, 1      => x1 = 0x1000

        // ADDI x1, x1, 16  (0x10)
        // imm=0x010=16, rs1=1, funct3=000, rd=1, op=0010011
        // 32'b 000000010000_00001_000_00001_0010011
        imem['h04 >> 2] = 32'h01008_093; // ADDI x1,x1,16  => x1 = 0x1010

        // --- x2 = 42 ---
        // ADDI x2, x0, 42
        // imm=42=0x02A, rs1=0, rd=2
        // 32'b 000000101010_00000_000_00010_0010011
        imem['h08 >> 2] = 32'h02A00_113; // ADDI x2,x0,42

        // --- x3 = 100 ---
        // ADDI x3, x0, 100 (0x64)
        imem['h0C >> 2] = 32'h06400_193; // ADDI x3,x0,100

        // --- x4 = -1 (0xFFFF_FFFF) ---
        // ADDI x4, x0, -1  (imm = 0xFFF sign-extended)
        imem['h10 >> 2] = 32'hFFF00_213; // ADDI x4,x0,-1

        // --- SW x2, 0(x1) -> dmem[0x1010] = 42 ---
        // SW: imm[11:5]=0, rs2=x2, rs1=x1, funct3=010, imm[4:0]=0, op=0100011
        // imm=0 -> imm[11:5]=0000000, imm[4:0]=00000
        // 32'b 0000000_00010_00001_010_00000_0100011
        imem['h14 >> 2] = 32'h0020A_023; // SW x2, 0(x1)

        // --- SW x3, 4(x1) -> dmem[0x1014] = 100 ---
        // imm=4 -> imm[11:5]=0000000, imm[4:0]=00100
        // 32'b 0000000_00011_00001_010_00100_0100011
        imem['h18 >> 2] = 32'h0030A_223; // SW x3, 4(x1)

        // --- SW x4, 8(x1) -> dmem[0x1018] = 0xFFFFFFFF ---
        // imm=8 -> imm[11:5]=0000000, imm[4:0]=01000
        // 32'b 0000000_00100_00001_010_01000_0100011
        imem['h1C >> 2] = 32'h0040A_423; // SW x4, 8(x1)

        // --- LW x5, 0(x1) -> x5 = 42 ---
        // imm=0, rs1=x1, funct3=010, rd=x5, op=0000011
        // 32'b 000000000000_00001_010_00101_0000011
        imem['h20 >> 2] = 32'h0000A_283; // LW x5, 0(x1)

        // --- LW x6, 4(x1) -> x6 = 100 ---
        imem['h24 >> 2] = 32'h0040A_303; // LW x6, 4(x1)

        // --- ADD x7, x5, x6 -> x7 = 142 ---
        // 0000000_00110_00101_000_00111_0110011
        imem['h28 >> 2] = 32'h0062_8_3B3; // ADD x7, x5, x6

        // --- SUB x8, x6, x5 -> x8 = 58 ---
        // 0100000_00101_00110_000_01000_0110011
        imem['h2C >> 2] = 32'h4053_0_433; // SUB x8, x6, x5

        // --- AND x9, x5, x6 -> x9 = 32 ---
        // 0000000_00110_00101_111_01001_0110011
        imem['h30 >> 2] = 32'h0062_F_4B3; // AND x9, x5, x6

        // --- OR x10, x5, x6 -> x10 = 110 ---
        // 0000000_00110_00101_110_01010_0110011
        imem['h34 >> 2] = 32'h0062_E_533; // OR x10, x5, x6

        // --- BEQ x2, x5, +8 (jump to 0x40 from 0x38) ---
        // BEQ: imm offset = +8 bytes from this instruction (0x38)
        // imm = 8 = 13'b0_000000_0100_0
        // encoding: imm[12|10:5] | rs2 | rs1 | 000 | imm[4:1|11] | 1100011
        // imm[12]=0, imm[10:5]=000000, rs2=x5(5'b00101), rs1=x2(5'b00010)
        // imm[4:1]=0100, imm[11]=0
        // 32'b 0_000000_00101_00010_000_0100_0_1100011
        // = 0000_0000_0101_0001_0000_0100_0110_0011
        imem['h38 >> 2] = 32'h00510_463; // BEQ x2, x5, +8

        // --- ADDI x11, x0, 0xBAD (should be skipped by branch) ---
        // This is at 0x3C; if branch taken, PC goes to 0x44
        imem['h3C >> 2] = 32'hBAD00_593; // ADDI x11,x0,0xBAD (skipped)

        // --- ADDI x11, x0, 0x600 (branch target) ---
        imem['h40 >> 2] = 32'h60000_593; // ADDI x11,x0,0x600 => x11=0x600

        // NOPs from 0x44 onward (already filled)
    end

    // Combinational instruction memory — no latency
    assign imem_ready = imem_req;
    assign imem_rdata = imem_req ? imem[imem_addr[31:2]] : 32'h0000_0013;

    // -------------------------------------------------------
    // Data memory — combinational reads, registered writes
    // -------------------------------------------------------
    logic [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        for (int i = 0; i < DMEM_WORDS; i++)
            dmem[i] = 32'h0;
    end

    assign dmem_ready  = dmem_rd_en || dmem_wr_en;
    assign dmem_rdata  = dmem_rd_en ? dmem[dmem_addr[31:2]] : 32'b0;

    always_ff @(posedge clk) begin
        if (dmem_wr_en)
            dmem[dmem_addr[31:2]] <= dmem_wdata;
    end

    // -------------------------------------------------------
    // Helpers: direct register file access for checking
    // Peek through hierarchy: dut.rf.regs[n]
    // -------------------------------------------------------
    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.rf.regs[n];
    endfunction

    // -------------------------------------------------------
    // Test infra
    // -------------------------------------------------------
    int pass_count;
    int fail_count;

    task automatic check_reg(
        input int unsigned  reg_num,
        input logic [31:0]  expected,
        input string        label
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

    task automatic check_dmem(
        input logic [31:0]  byte_addr,
        input logic [31:0]  expected,
        input string        label
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

    // -------------------------------------------------------
    // Stimulus + checking
    // -------------------------------------------------------
    initial begin
        // Init
        rst_n      = 1'b0;
        cpu_enable = 1'b0;
        pass_count = 0;
        fail_count = 0;

        // Reset for 5 cycles
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // Release CPU
        cpu_enable = 1'b1;

        // -------------------------------------------------------
        // Run long enough for all instructions to complete.
        //
        // Worst case: each instruction may suffer a D-cache miss
        // (7 cycles) plus pipeline stages (5) plus branch penalty (2).
        // 20 instructions * 15 cycles/instr = 300 cycles is generous.
        // -------------------------------------------------------
        $display("\n[TB] CPU running...");
        repeat (300) @(posedge clk);

        $display("\n========== REGISTER FILE CHECKS ==========");
        check_reg(1,  32'h0000_1010, "LUI+ADDI base");
        check_reg(2,  32'd42,        "ADDI x2=42");
        check_reg(3,  32'd100,       "ADDI x3=100");
        check_reg(4,  32'hFFFF_FFFF, "ADDI x4=-1");
        check_reg(5,  32'd42,        "LW x5=42");
        check_reg(6,  32'd100,       "LW x6=100");
        check_reg(7,  32'd142,       "ADD x7=142");
        check_reg(8,  32'd58,        "SUB x8=58");
        check_reg(9,  32'd32,        "AND x9=32");
        check_reg(10, 32'd110,       "OR  x10=110");
        check_reg(11, 32'h0000_0600, "BEQ taken x11=0x600");

        $display("\n========== DATA MEMORY CHECKS ==========");
        check_dmem(32'h0000_1010, 32'd42,        "SW x2");
        check_dmem(32'h0000_1014, 32'd100,       "SW x3");
        check_dmem(32'h0000_1018, 32'hFFFF_FFFF, "SW x4");

        $display("\n========== SUMMARY ==========");
        $display("PASS: %0d   FAIL: %0d   TOTAL: %0d",
                 pass_count, fail_count, pass_count + fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED -- check pipeline/forwarding/cache");

        $finish;
    end

    // -------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------
    initial begin
        #50000;
        $display("[TIMEOUT] Simulation exceeded 50us -- possible hang");
        $fatal;
    end

    // -------------------------------------------------------
    // Optional cycle-by-cycle trace (uncomment to enable)
    // -------------------------------------------------------
    // initial begin
    //     @(posedge rst_n);
    //     forever begin
    //         @(posedge clk);
    //         $display("[T=%0t] PC=%08h INSTR=%08h", $time, debug_pc, debug_instr);
    //     end
    // end

endmodule