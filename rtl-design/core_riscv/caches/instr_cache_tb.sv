`timescale 1ns / 1ps

`timescale 1ns / 1ps

module instr_cache_tb();

    localparam CLK_PERIOD = 10;
    localparam MEM_WORDS  = 4096; // simple backing memory size

    logic        clk;
    logic        rst_n;

    logic [31:0] cpu_addr;
    logic        cpu_req;
    logic [31:0] cpu_rdata;
    logic        cpu_ready;

    logic [31:0] mem_addr;
    logic        mem_req;
    logic [31:0] mem_rdata;
    logic        mem_ready;

    instr_cache dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (cpu_addr),
        .cpu_req   (cpu_req),
        .cpu_rdata (cpu_rdata),
        .cpu_ready (cpu_ready),
        .mem_addr  (mem_addr),
        .mem_req   (mem_req),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );

    logic [31:0] backing_mem [0:MEM_WORDS-1];

    initial begin
        for (int i = 0; i < MEM_WORDS; i++) begin
            // recognizable pattern
            backing_mem[i] = 32'h1000_0000 + i;
        end
    end

    // for simplicity, memory responds 1 cycle after mem_req
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'b0;
        end else begin
            mem_ready <= mem_req;

            if (mem_req) begin
                mem_rdata <= backing_mem[mem_addr[31:2]];
            end
        end
    end

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer total_accesses;
    integer total_hits;
    integer total_misses;

    function automatic [31:0] expected_instr(input [31:0] addr);
        expected_instr = backing_mem[addr[31:2]];
    endfunction

    // IMPORTANT:
    // - holds cpu_req high until cpu_ready
    // - holds cpu_addr stable during miss/refill
    //
    // we classify a hit as "ready seen immediately/very quickly"
    // with zero miss-wait cycles beyond the first chance.
    // more robustly: sample current line hit before issuing.

    task automatic fetch_instr(input [31:0] addr);
        int wait_cycles;
        bit predicted_hit;
        logic [21:0] req_tag;
        logic [5:0]  req_index;
        logic [1:0]  req_offset;
        logic [31:0] got_data;
        logic [31:0] exp_data;
        begin
            req_tag    = addr[31:10];
            req_index  = addr[9:4];
            req_offset = addr[3:2];

            // peek into DUT arrays to classify access before request
            predicted_hit =
                dut.valid_ram[req_index] &&
                (dut.tag_ram[req_index] == req_tag);

            total_accesses++;
            if (predicted_hit)
                total_hits++;
            else
                total_misses++;

            // drive request
            @(negedge clk);
            cpu_addr <= addr;
            cpu_req  <= 1'b1;

            wait_cycles = 0;
            while (cpu_ready !== 1'b1) begin
                @(posedge clk);
                wait_cycles++;
            end

            // sample data once ready
            got_data = cpu_rdata;
            exp_data = expected_instr(addr);

            if (got_data !== exp_data) begin
                $display("[ERROR] addr=%08h expected=%08h got=%08h at time %0t",
                         addr, exp_data, got_data, $time);
                $fatal;
            end

            @(negedge clk);
            cpu_req <= 1'b0;

            $display("[ACCESS] addr=%08h  %s  wait_cycles=%0d  data=%08h  time=%0t",
                     addr,
                     predicted_hit ? "HIT " : "MISS",
                     wait_cycles,
                     got_data,
                     $time);
        end
    endtask

    initial begin
        // init
        cpu_addr = 32'b0;
        cpu_req  = 1'b0;
        rst_n    = 1'b0;

        total_accesses = 0;
        total_hits     = 0;
        total_misses   = 0;

        // reset
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n========== TEST 1: cold miss then hits within same line ==========");
        // line base 0x00000000, offsets 0,4,8,C
        fetch_instr(32'h0000_0000); // miss
        fetch_instr(32'h0000_0004); // hit
        fetch_instr(32'h0000_0008); // hit
        fetch_instr(32'h0000_000C); // hit

        $display("\n========== TEST 2: new line, then re-access ==========");
        fetch_instr(32'h0000_0010); // miss (next line)
        fetch_instr(32'h0000_0014); // hit
        fetch_instr(32'h0000_0010); // hit again

        $display("\n========== TEST 3: conflict-style access ==========");
        // same index, different tag:
        // index = bits [9:4]
        // 0x0000_0000 -> index 0
        // 0x0000_0400 -> also index 0, different tag
        fetch_instr(32'h0000_0000); // likely hit if still resident
        fetch_instr(32'h0000_0400); // miss, evicts/set overwrite at same index
        fetch_instr(32'h0000_0000); // miss again due to conflict
        fetch_instr(32'h0000_0400); // miss or hit depending on previous sequence; here should miss then refill/hit pattern

        $display("\n========== TEST 4: sequential workload ==========");
        // 16 instructions = 4 cache lines
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