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
    logic imem_req;
    logic [31:0] imem_rdata;
    logic imem_ready;

    // d-cache signals with mem
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic dmem_rd_en;
    logic dmem_wr_en;
    logic [2:0] dmem_size;
    logic [31:0] dmem_rdata;
    logic dmem_ready;

    logic [31:0] debug_pc;
    logic [31:0] debug_instr;
    logic [31:0] debug_reg_data;
    logic debug_halted;

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

    // instruction memory here
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] imem_rdata_r;
    logic        imem_ready_r;

    initial begin
        for (int i = 0; i < IMEM_WORDS; i++)
            imem[i] = 32'h00000013; // NOP (ADDI x0, x0, 0)
        // load test programs later
        // check /testbenching for more information
    end

    always_ff @(posedge clk) begin
        if (imem_req) begin
            imem_ready_r <= 1'b1;
            imem_rdata_r <= imem[imem_addr[31:2]];
        end else begin
            imem_ready_r <= 1'b0;  
        end
    end

    assign imem_ready = imem_ready_r;
    assign imem_rdata = imem_rdata_r;

    // data memory here
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

    // testing infrastructure
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

    // starting stimulus here
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

        // each instruction can cost: 5 pipeline stages + up to 2 cache
        // miss refill cycles (4 words x 1 cycle each = 4) + write-back
        // (4 cycles) + done (1) + potential stall cycles.
        // 20 instructions * ~20 cycles worst case = 400 cycles.
        // 600 gives comfortable headroom

        $display("\n[TB] CPU running...");
        repeat (600) @(posedge clk);

        // write specific checks here

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

    // debugging trace (comment out)
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