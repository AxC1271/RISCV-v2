`timescale 1ns / 1ps

module core_riscv_tb();
    localparam CLK_PERIOD  = 10;
    localparam IMEM_WORDS  = 1024;   // 4 kB instruction ROM
    localparam DMEM_WORDS  = 16384;  // 64 kB data memory

    logic clk;
    logic rst_n;
    logic cpu_enable;

    // i-cache signals with mem
    logic [31:0] imem_addr;
    logic        imem_req;
    logic [31:0] imem_rdata;
    logic        imem_ready;

    // d-cache signals with mem
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [2:0]  dmem_size;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic [31:0] debug_reg_data;
    logic        debug_halted;

    // instantiate design under test
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
    logic        imem_ready_r;

    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // NOP (addi x0, x0, 0)

        // refer to riscv_asm.py for encoding details

        // 1. handle regular r-type and i-type instructions here
        // imem['h000 >> 2] = 32'h00A00093; // addi x1, x0, 10      # x1 = 10
        // imem['h004 >> 2] = 32'h00508113; // addi x2, x1, 5       # x2 = 15   EX->EX x1
        // imem['h008 >> 2] = 32'h002081B3; // add  x3, x1, x2      # x3 = 25   EX->EX x2, MEM->EX x1
        // imem['h00C >> 2] = 32'h00219213; // slli x4, x3, 2       # x4 = 100  EX->EX x3
        // imem['h010 >> 2] = 32'h401202B3; // sub  x5, x4, x1      # x5 = 90   EX->EX x4, MEM->EX x1
        // imem['h014 >> 2] = 32'h0022C333; // xor  x6, x5, x2      # x6 = 85   EX->EX x5, MEM->EX x2
        // imem['h018 >> 2] = 32'h003363B3; // or   x7, x6, x3      # x7 = 93   EX->EX x6, MEM->EX x3
        // imem['h01C >> 2] = 32'h0043F433; // and  x8, x7, x4      # x8 = 68   EX->EX x7, MEM->EX x4  (93&100=68)

        // 2. test for load-use hazards and pipeline stalls in the risc-v processor
        imem['h000 >> 2] = 32'h06400093; // addi x1, x0, 100    # base = 100
        imem['h004 >> 2] = 32'h02A00113; // addi x2, x0, 42     # val = 42
        imem['h008 >> 2] = 32'h0020A023; // sw   x2, 0(x1)      # mem[100] = 42
        imem['h00C >> 2] = 32'h06300193; // addi x3, x0, 99     # val = 99
        imem['h010 >> 2] = 32'h0030A223; // sw   x3, 4(x1)      # mem[104] = 99
        imem['h014 >> 2] = 32'h0000A203; // lw   x4, 0(x1)      # x4 = 42   <load>
        imem['h018 >> 2] = 32'h000202B3; // add  x5, x4, x0     # x5 = x4   LOAD-USE stall
        imem['h01C >> 2] = 32'h0040A303; // lw   x6, 4(x1)      # x6 = 99   <load>
        imem['h020 >> 2] = 32'h404303B3; // sub  x7, x6, x4     # x7 = 57 

        // 3. test for branch penalties in this workload
        // imem['h000 >> 2] = 32'h00500093; // addi x1, x0, 5      # x1 = 5
        // imem['h004 >> 2] = 32'h00500113; // addi x2, x0, 5      # x2 = 5
        // imem['h008 >> 2] = 32'h00208663; // beq  x1, x2, +12    # taken -> flush 2 instrs
        // imem['h00C >> 2] = 32'h06300193; // addi x3, x0, 99     # SQUASHED
        // imem['h010 >> 2] = 32'h05800213; // addi x4, x0, 88     # SQUASHED
        // imem['h014 >> 2] = 32'h00100293; // addi x5, x0, 1      # x5 = 1  (branch target)
        // imem['h018 >> 2] = 32'h00200313; // addi x6, x0, 2      # x6 = 2

        // 4. randomized distributed workload for risc-v processor
        // imem['h000 >> 2] = 32'h00000093; // addi x1, x0, 0      # i = 0
        // imem['h004 >> 2] = 32'h00800113; // addi x2, x0, 8      # bound = 8
        // imem['h008 >> 2] = 32'h0C800193; // addi x3, x0, 200    # base addr = 200
        // imem['h00C >> 2] = 32'h00209213; // slli x4, x1, 2      # x4 = i*4
        // imem['h010 >> 2] = 32'h004182B3; // add  x5, x3, x4     # x5 = base+offset
        // imem['h014 >> 2] = 32'h0002A303; // lw   x6, 0(x5)      # x6 = array[i]
        // imem['h018 >> 2] = 32'h00130313; // addi x6, x6, 1      # x6++
        // imem['h01C >> 2] = 32'h0062A023; // sw   x6, 0(x5)      # array[i] = x6
        // imem['h020 >> 2] = 32'h00108093; // addi x1, x1, 1      # i++
        // imem['h024 >> 2] = 32'hFE20C4E3; // blt  x1, x2, -24    # if i<8, loop
        // imem['h028 >> 2] = 32'h0001A383; // lw   x7, 0(x3)      # x7 = array[0] = 1
        // imem['h02C >> 2] = 32'h0041A403; // lw   x8, 4(x3)      # x8 = array[1] = 1
        // imem['h030 >> 2] = 32'h008384B3; // add  x9, x7, x8     # x9 = 2
    end

    // combinational read — data valid same cycle as req
    assign imem_rdata = imem_req ? imem[imem_addr[31:2]] : 32'h00000013;

    // Ready pulses one cycle after req (registered handshake)
    always_ff @(posedge clk) begin
        if (imem_req)
            imem_ready_r <= 1'b1;
        else
            imem_ready_r <= 1'b0;
    end

    assign imem_ready = imem_ready_r;

    logic [31:0] dmem [0:DMEM_WORDS-1];
    logic [31:0] dmem_rdata_r;
    logic        dmem_ready_r;

    initial begin
        for (int i = 0; i < DMEM_WORDS; i++)
            dmem[i] = 32'h0;
    end

    always_ff @(posedge clk) begin
        dmem_ready_r <= dmem_rd_en || dmem_wr_en;
        if (dmem_rd_en)
            dmem_rdata_r <= dmem[dmem_addr[31:2]];
        if (dmem_wr_en)
            dmem[dmem_addr[31:2]] <= dmem_wdata;
    end

    assign dmem_ready = dmem_ready_r;
    assign dmem_rdata = dmem_rdata_r;

    function automatic [31:0] read_reg(input int unsigned n);
        read_reg = dut.rf.mem[n];
    endfunction

    int pass_count;
    int fail_count;

    task automatic check_reg (
        input int unsigned  reg_num,
        input logic [31:0]  expected,
        input string        label
    );
        logic [31:0] got;
        got = read_reg(reg_num);
        if (got === expected) begin
            $display("  PASS  %-20s  x%-2d                   = 0x%08h",
                     label, reg_num, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-20s  x%-2d  expected=0x%08h  got=0x%08h",
                     label, reg_num, expected, got);
            fail_count++;
        end
    endtask

    task automatic check_dmem (
        input logic [31:0]  byte_addr,
        input logic [31:0]  expected,
        input string        label
    );
        logic [31:0] got;
        got = dmem[byte_addr[31:2]];
        if (got === expected) begin
            $display("  PASS  %-20s  dmem[0x%08h] = 0x%08h",
                     label, byte_addr, got);
            pass_count++;
        end else begin
            $display("  FAIL  %-20s  dmem[0x%08h]  expected=0x%08h  got=0x%08h",
                     label, byte_addr, expected, got);
            fail_count++;
        end
    endtask

    // stimulus
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
        repeat (600) @(posedge clk);

        // 1. testbench check for data forwarding
        // check_reg( 1, 32'd10   , "addi x1=10");
        // check_reg( 2, 32'd15   , "addi x2=15");
        // check_reg( 3, 32'd25   , "add x3=25");
        // check_reg( 4, 32'd100  , "slli x4=100");
        // check_reg( 5, 32'd90   , "sub x5=90");
        // check_reg( 6, 32'd85   , "xor x6=85");
        // check_reg( 7, 32'd93   , "or x7=93");
        // check_reg( 8, 32'd68   , "and x8=68");

        // 2. testbench check for the load use hazard
        check_reg( 4, 32'd42   , "lw x4=42");
        check_reg( 5, 32'd42   , "add x5=42");
        check_reg( 6, 32'd99   , "lw x6=99");
        check_reg( 7, 32'd57   , "sub x7=57");
        check_dmem(32'h00000064, 32'd42,  "sw x2->mem[100]");
        check_dmem(32'h00000068, 32'd99,  "sw x3->mem[104]");

        // 3. testbench check for branch penalties/squash
        // check_reg( 1, 32'd5    , "addi x1=5");
        // check_reg( 2, 32'd5    , "addi x2=5");
        // check_reg( 3, 32'd0    , "x3 squashed=0");
        // check_reg( 4, 32'd0    , "x4 squashed=0");
        // check_reg( 5, 32'd1    , "addi x5=1");
        // check_reg( 6, 32'd2    , "addi x6=2");

        // 4. testbench check for randomized distributed workload on risc-v processor
        // check_reg( 7, 32'd1    , "lw x7=1");
        // check_reg( 8, 32'd1    , "lw x8=1");
        // check_reg( 9, 32'd2    , "add x9=2");
        // check_dmem(32'h000000C8, 32'd1, "array[0]=1");
        // check_dmem(32'h000000CC, 32'd1, "array[1]=1");
        // check_dmem(32'h000000D0, 32'd1, "array[2]=1");
        // check_dmem(32'h000000D4, 32'd1, "array[3]=1");
        // check_dmem(32'h000000D8, 32'd1, "array[4]=1");
        // check_dmem(32'h000000DC, 32'd1, "array[5]=1");
        // check_dmem(32'h000000E0, 32'd1, "array[6]=1");
        // check_dmem(32'h000000E4, 32'd1, "array[7]=1");

        $display("\n========== SUMMARY ==========");
        $display("PASS: %0d   FAIL: %0d   TOTAL: %0d",
                 pass_count, fail_count, pass_count + fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED -- check pipeline/forwarding/cache");

        $finish;
    end

    // timeout watchdog
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation exceeded 100us -- possible hang");
        $fatal;
    end


    initial begin
        @(posedge rst_n);
        forever begin
            @(posedge clk);
            $display("[T=%0t] PC=%08h INSTR=%08h icache_state=%0d icache_ready=%b hit=%b addr_idx=%02h addr_off=%01h hit_data=%08h",
                     $time, debug_pc, debug_instr,
                     dut.icache.state, dut.icache.cpu_ready,
                     dut.icache.hit, dut.icache.addr_index, dut.icache.addr_offset,
                     dut.icache.hit_data_r);
        end
    end

endmodule