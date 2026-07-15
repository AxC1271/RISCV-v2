`timescale 1ns / 1ps

module core_riscv_tb();
    localparam CLK_PERIOD  = 10;
    localparam IMEM_WORDS  = 1024;   // 4 kB instruction ROM
    localparam DMEM_WORDS  = 16384;  // 64 kB data memory
    localparam BASE        = 32'h0001_0000; // reset vector / .text base

    logic clk;
    logic rst_n;
    logic cpu_enable;

    logic [31:0] imem_addr;
    logic        imem_req;
    logic [31:0] imem_rdata;
    logic        imem_ready;

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic [31:0] debug_reg_data;
    logic        debug_halted;

    core_riscv #(.RESET_VECTOR(BASE)) dut (
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

    // instruction memory
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic        imem_ready_r;
    logic [31:0] imem_index;
    assign imem_index = (imem_addr - BASE) >> 2;

    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // NOP

        imem['h000 >> 2] = 32'h06400093; // addi  x1, x0, 100   # x1  = 100 (base ptr)
        imem['h004 >> 2] = 32'h02A00113; // addi  x2, x0, 42    # x2  = 42
        imem['h008 >> 2] = 32'h002081B3; // add   x3, x1, x2    # x3  = 142  EX->EX fwd
        imem['h00C >> 2] = 32'h0020A023; // sw    x2, 0(x1)     # mem[100] = 42
        imem['h010 >> 2] = 32'h0000A203; // lw    x4, 0(x1)     # x4  = 42
        imem['h014 >> 2] = 32'h004202B3; // add   x5, x4, x4    # x5  = 84   load-use stall
        imem['h018 >> 2] = 32'h12345337; // lui   x6, 0x12345   # x6  = 0x12345000
        imem['h01C >> 2] = 32'h00000397; // auipc x7, 0         # x7  = BASE+0x1C
        imem['h020 >> 2] = 32'h00C0046F; // jal   x8, +12       # x8  = BASE+0x24, jump to 0x2C
        imem['h024 >> 2] = 32'h06300493; // addi  x9, x0, 99    # SQUASHED
        imem['h028 >> 2] = 32'h06200513; // addi  x10, x0, 98   # SQUASHED
        imem['h02C >> 2] = 32'h00100593; // addi  x11, x0, 1    # x11 = 1
        imem['h030 >> 2] = 32'h00000617; // auipc x12, 0        # x12 = BASE+0x30
        imem['h034 >> 2] = 32'h040606E7; // jalr  x13, x12, 0x40 # x13 = BASE+0x38, jump to BASE+0x70
        imem['h038 >> 2] = 32'h06100713; // addi  x14, x0, 97   # SQUASHED
        imem['h03C >> 2] = 32'h06000793; // addi  x15, x0, 96   # SQUASHED
        imem['h070 >> 2] = 32'h00500713; // addi  x14, x0, 5    # x14 = 5
        imem['h074 >> 2] = 32'h00E70663; // beq   x14, x14, +12 # taken, jump to 0x80
        imem['h078 >> 2] = 32'h05F00793; // addi  x15, x0, 95   # SQUASHED
        imem['h07C >> 2] = 32'h05E00813; // addi  x16, x0, 94   # SQUASHED
        imem['h080 >> 2] = 32'h00E71463; // bne   x14, x14, +8  # not taken
        imem['h084 >> 2] = 32'h00700813; // addi  x16, x0, 7    # x16 = 7
        imem['h088 >> 2] = 32'hFFF00893; // addi  x17, x0, -1   # x17 = 0xFFFFFFFF
        imem['h08C >> 2] = 32'h01108223; // sb    x17, 4(x1)    # mem[104].b0 = FF
        imem['h090 >> 2] = 32'h00E082A3; // sb    x14, 5(x1)    # mem[104].b1 = 05 -> 0x000005FF
        imem['h094 >> 2] = 32'h0040C903; // lbu   x18, 4(x1)    # x18 = 0x000000FF
        imem['h098 >> 2] = 32'h00408983; // lb    x19, 4(x1)    # x19 = 0xFFFFFFFF
        imem['h09C >> 2] = 32'h00409A03; // lh    x20, 4(x1)    # x20 = 0x000005FF
        imem['h0A0 >> 2] = 32'h01109323; // sh    x17, 6(x1)    # mem[104] = 0xFFFF05FF
        imem['h0A4 >> 2] = 32'h0040AA83; // lw    x21, 4(x1)    # x21 = 0xFFFF05FF
        imem['h0A8 >> 2] = 32'h0060DB03; // lhu   x22, 6(x1)    # x22 = 0x0000FFFF
        imem['h0AC >> 2] = 32'h4048DB93; // srai  x23, x17, 4   # x23 = 0xFFFFFFFF
        imem['h0B0 >> 2] = 32'h01103C33; // sltu  x24, x0, x17  # x24 = 1
        imem['h0B4 >> 2] = 32'h0008ACB3; // slt   x25, x17, x0  # x25 = 1
        imem['h0B8 >> 2] = 32'h00100073; // ebreak              # halt
    end

    assign imem_rdata = (imem_index < IMEM_WORDS) ? imem[imem_index[$clog2(IMEM_WORDS)-1:0]]
                                                  : 32'h00000013;

    always_ff @(posedge clk)
        imem_ready_r <= imem_req;

    assign imem_ready = imem_ready_r;

    // data memory
    logic [31:0] dmem [0:DMEM_WORDS-1];
    logic        dmem_ready_r;

    initial begin
        for (int i = 0; i < DMEM_WORDS; i++)
            dmem[i] = 32'h0;
    end

    assign dmem_rdata = dmem[dmem_addr[$clog2(DMEM_WORDS)+1:2]];

    always_ff @(posedge clk) begin
        dmem_ready_r <= dmem_rd_en || dmem_wr_en;
        if (dmem_wr_en)
            dmem[dmem_addr[$clog2(DMEM_WORDS)+1:2]] <= dmem_wdata;
    end

    assign dmem_ready = dmem_ready_r;

    // function checks
    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.rf.mem[n];
    endfunction

    int pass_count;
    int fail_count;

    task automatic check_reg (
        input int unsigned reg_num,
        input logic [31:0] expected,
        input string       label
    );
        logic [31:0] got;
        got = read_reg(reg_num);
        if (got === expected) begin
            $display("  PASS  %-22s x%-2d                   = 0x%08h", label, reg_num, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-22s x%-2d  expected=0x%08h  got=0x%08h", label, reg_num, expected, got);
            fail_count++;
        end
    endtask

    task automatic check_dcache (
        input logic [31:0] byte_addr,
        input logic [31:0] expected,
        input string       label
    );
        logic [20:0] t;
        logic [6:0]  s;
        logic [1:0]  w;
        logic [31:0] got;
        logic        found;

        t = byte_addr[31:11];
        s = byte_addr[10:4];
        w = byte_addr[3:2];
        found = 1'b0;

        if (dut.dcache.valid_array[s][0] && dut.dcache.tag_array[s][0] == t) begin
            got   = dut.dcache.data_array[s][0][w];
            found = 1'b1;
        end else if (dut.dcache.valid_array[s][1] && dut.dcache.tag_array[s][1] == t) begin
            got   = dut.dcache.data_array[s][1][w];
            found = 1'b1;
        end

        if (!found) begin
            $display("  FAIL  %-22s dcache[0x%08h] not found in cache", label, byte_addr);
            fail_count++;
        end else if (got === expected) begin
            $display("  PASS  %-22s dcache[0x%08h] = 0x%08h", label, byte_addr, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-22s dcache[0x%08h]  expected=0x%08h  got=0x%08h",
                     label, byte_addr, expected, got);
            fail_count++;
        end
    endtask

    // main stimulation sequence
    initial begin
        rst_n      = 1'b0;
        cpu_enable = 1'b0;
        pass_count = 0;
        fail_count = 0;

        #1;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        cpu_enable = 1'b1;

        $display("\n[TB] CPU running...");
        fork
            begin : wait_halt
                wait (debug_halted);
                $display("[TB] EBREAK retired, core halted at T=%0t", $time);
            end
            begin : hard_cap
                repeat (2000) @(posedge clk);
            end
        join_any
        disable fork;
        repeat (4) @(posedge clk);

        if (!debug_halted)
            $display("[TB] WARNING: core never halted -- checking state anyway");

        // arithmetic + forwarding + load-use
        check_reg( 1, 32'd100,        "addi x1=100");
        check_reg( 2, 32'd42,         "addi x2=42");
        check_reg( 3, 32'd142,        "add fwd x3=142");
        check_reg( 4, 32'd42,         "lw x4=42");
        check_reg( 5, 32'd84,         "load-use x5=84");

        // U-type
        check_reg( 6, 32'h12345000,   "lui x6");
        check_reg( 7, BASE + 32'h1C,  "auipc x7");

        // JAL
        check_reg( 8, BASE + 32'h24,  "jal link x8");
        check_reg( 9, 32'd0,          "x9 squashed");
        check_reg(10, 32'd0,          "x10 squashed");
        check_reg(11, 32'd1,          "post-jal x11=1");

        // JALR
        check_reg(12, BASE + 32'h30,  "auipc x12");
        check_reg(13, BASE + 32'h38,  "jalr link x13");
        check_reg(14, 32'd5,          "jalr target x14=5");
        check_reg(15, 32'd0,          "x15 squashed");

        // branches
        check_reg(16, 32'd7,          "bne not-taken x16=7");

        // sub-word memory
        check_reg(17, 32'hFFFFFFFF,   "addi x17=-1");
        check_reg(18, 32'h000000FF,   "lbu x18");
        check_reg(19, 32'hFFFFFFFF,   "lb x19");
        check_reg(20, 32'h000005FF,   "lh x20");
        check_reg(21, 32'hFFFF05FF,   "lw x21");
        check_reg(22, 32'h0000FFFF,   "lhu x22");

        // shifts / compares
        check_reg(23, 32'hFFFFFFFF,   "srai x23");
        check_reg(24, 32'd1,          "sltu x24");
        check_reg(25, 32'd1,          "slt x25");

        // memory state
        check_dcache(32'h00000064, 32'd42,        "sw -> mem[100]");
        check_dcache(32'h00000068, 32'hFFFF05FF,  "sb/sh -> mem[104]");

        $display("\n========== SUMMARY ==========");
        $display("PASS: %0d   FAIL: %0d   TOTAL: %0d", pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED -- check pipeline/forwarding/memory");
        $finish;
    end

    // timeout watchdog
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation exceeded 100us -- possible hang");
        $fatal;
    end

    // pipeline monitor (run with +verbose to enable)
    initial begin
        if ($test$plusargs("verbose")) begin
            @(posedge rst_n);
            forever begin
                @(posedge clk);
                $display("[T=%0t] | IF: PC=%08h rdy=%b | ID: %08h | EX: rd=x%0d mrd=%b mwr=%b | MEM: rd=x%0d mrd=%b mwr=%b rw=%b | WB: rd=x%0d rw=%b | lu=%b flush_idex=%b mem_stall=%b fetch_stall=%b dc_rdy=%b redir=%b",
                    $time,
                    dut.pc_current, dut.icache_ready,
                    dut.id_instr,
                    dut.ex_rd, dut.ex_memread, dut.ex_memwrite,
                    dut.mem_rd, dut.mem_memread, dut.mem_memwrite, dut.mem_regwrite,
                    dut.wb_rd, dut.wb_regwrite,
                    dut.load_use_stall, dut.idex_flush, dut.mem_stall,
                    dut.fetch_stall, dut.dcache_ready, dut.redirect
                );
            end
        end
    end

endmodule