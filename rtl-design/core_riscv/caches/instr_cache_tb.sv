`timescale 1ns / 1ps

module instr_cache_tb();

    localparam CLK_PERIOD = 10;
    localparam MEM_WORDS  = 4096;

    logic clk;
    logic rst_n;

    logic [31:0] cpu_addr;
    logic cpu_req;
    logic [31:0] cpu_rdata;
    logic cpu_ready;

    logic [31:0] mem_addr;
    logic mem_req;
    logic [31:0] mem_rdata;
    logic mem_ready;

    instr_cache dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_req(cpu_req),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),
        .mem_addr(mem_addr),
        .mem_req(mem_req),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    logic [31:0] backing_mem [0:MEM_WORDS-1];

    initial begin
        for (int i = 0; i < MEM_WORDS; i++) begin
            backing_mem[i] = 32'h1000_0000 + i;
        end
    end

    assign mem_ready = mem_req;
    assign mem_rdata = mem_req ? backing_mem[mem_addr[31:2]] : 32'b0;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer total_accesses;
    integer total_hits;
    integer total_misses;

    function automatic [31:0] expected_instr(input [31:0] addr);
        expected_instr = backing_mem[addr[31:2]];
    endfunction

    function automatic bit predict_hit(input [31:0] addr);
        logic [21:0] req_tag;
        logic [5:0]  req_index;
        begin
            req_tag   = addr[31:10];
            req_index = addr[9:4];

            predict_hit =
                dut.valid_ram[req_index] &&
                (dut.tag_ram[req_index] == req_tag);
        end
    endfunction
    
    task automatic fetch_instr(input [31:0] addr);
        bit          predicted_hit;
        int          wait_cycles;
        logic [31:0] got_data;
        logic [31:0] exp_data;
        begin
            predicted_hit = predict_hit(addr);

            total_accesses++;
            if (predicted_hit)
                total_hits++;
            else
                total_misses++;

            @(negedge clk);
            cpu_addr = addr;
            cpu_req  = 1'b1;

            @(posedge clk);
            wait_cycles = 1;

            while (cpu_ready !== 1'b1) begin
                @(posedge clk);
                wait_cycles++;
            end

            #1;
            got_data = cpu_rdata;
            exp_data = expected_instr(addr);

            if (got_data !== exp_data) begin
                $display("[ERROR] addr=%08h expected=%08h got=%08h time=%0t",
                         addr, exp_data, got_data, $time);
                $fatal;
            end

            @(negedge clk);
            cpu_req = 1'b0;

            $display("[ACCESS] addr=%08h  %s  wait_cycles=%0d  data=%08h  time=%0t",
                     addr,
                     predicted_hit ? "HIT " : "MISS",
                     wait_cycles,
                     got_data,
                     $time);
        end
    endtask

    task automatic idle_cycle;
        begin
            @(negedge clk);
            cpu_req = 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        cpu_addr = 32'b0;
        cpu_req  = 1'b0;
        rst_n    = 1'b0;

        total_accesses = 0;
        total_hits     = 0;
        total_misses   = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n========== TEST 1: cold miss then hits within same line ==========");
        fetch_instr(32'h0000_0000); // miss
        fetch_instr(32'h0000_0004); // hit
        fetch_instr(32'h0000_0008); // hit
        fetch_instr(32'h0000_000C); // hit

        $display("\n========== TEST 2: new line, then re-access ==========");
        fetch_instr(32'h0000_0010); // miss
        fetch_instr(32'h0000_0014); // hit
        fetch_instr(32'h0000_0010); // hit

        $display("\n========== TEST 3: conflict-style access ==========");
        fetch_instr(32'h0000_0000); // likely hit if still present
        fetch_instr(32'h0000_0400); // miss, replaces line at same index
        fetch_instr(32'h0000_0000); // miss again due to conflict
        fetch_instr(32'h0000_0400); // hit if previous fill succeeded

        $display("\n========== TEST 4: sequential workload ==========");
        for (int i = 0; i < 16; i++) begin
            fetch_instr(32'h0000_1000 + i*4);
        end

        $display("\n========== FINAL STATS ==========");
        $display("Total accesses : %0d", total_accesses);
        $display("Total hits     : %0d", total_hits);
        $display("Total misses   : %0d", total_misses);

        if (total_accesses > 0) begin
            real hit_rate;
            real miss_rate;

            hit_rate  = real'(total_hits)   / real'(total_accesses);
            miss_rate = real'(total_misses) / real'(total_accesses);

            $display("Hit rate       : %0f", hit_rate);
            $display("Miss rate      : %0f", miss_rate);
        end

        $finish;
    end

endmodule