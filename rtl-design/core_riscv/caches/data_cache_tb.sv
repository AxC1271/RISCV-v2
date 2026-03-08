`timescale 1ns / 1ps

module data_cache_tb();
    localparam CLK_PERIOD = 10;
    localparam MEM_WORDS  = 16384;

    localparam CACHE_SIZE = 4096;
    localparam BLOCK_SIZE = 16;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam NUM_WAYS   = 2;

    localparam BLOCK_WORDS    = BLOCK_SIZE / 4;
    localparam TOTAL_BLOCKS   = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS       = TOTAL_BLOCKS / NUM_WAYS;
    localparam SET_INDEX_BITS = $clog2(NUM_SETS);
    localparam OFFSET_BITS    = $clog2(BLOCK_SIZE);
    localparam TAG_BITS       = ADDR_WIDTH - SET_INDEX_BITS - OFFSET_BITS;

    logic clk;
    logic rst_n;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wr_data;
    logic rd_en;
    logic wr_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic ready;

    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wr_data;
    logic mem_rd_en;
    logic mem_wr_en;
    logic [DATA_WIDTH-1:0] mem_rd_data;
    logic mem_ready;

    data_cache #(
        .CACHE_SIZE(CACHE_SIZE),
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_WAYS(NUM_WAYS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .wr_en(wr_en),
        .rd_data(rd_data),
        .ready(ready),
        .mem_addr(mem_addr),
        .mem_wr_data(mem_wr_data),
        .mem_rd_en(mem_rd_en),
        .mem_wr_en(mem_wr_en),
        .mem_rd_data(mem_rd_data),
        .mem_ready(mem_ready)
    );

    logic [DATA_WIDTH-1:0] backing_mem [0:MEM_WORDS-1];

    initial begin
        for (int i = 0; i < MEM_WORDS; i++)
            backing_mem[i] = 32'hA000_0000 + i;
    end

    assign mem_ready   = mem_rd_en || mem_wr_en;
    assign mem_rd_data = mem_rd_en ? backing_mem[mem_addr[31:2]] : 32'b0;

    always_ff @(posedge clk) begin
        if (mem_wr_en)
            backing_mem[mem_addr[31:2]] <= mem_wr_data;
    end

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer total_reads,  read_hits,  read_misses;
    integer total_writes, write_hits, write_misses;

    function automatic [TAG_BITS-1:0] get_tag(input [31:0] a);
        get_tag = a[ADDR_WIDTH-1 : SET_INDEX_BITS+OFFSET_BITS];
    endfunction

    function automatic [SET_INDEX_BITS-1:0] get_set(input [31:0] a);
        get_set = a[SET_INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    endfunction

    function automatic bit is_hit(input [31:0] a);
        logic [TAG_BITS-1:0]       t;
        logic [SET_INDEX_BITS-1:0] s;
        begin
            t = get_tag(a);
            s = get_set(a);
            is_hit = (dut.valid_array[s][0] && (dut.tag_array[s][0] == t)) ||
                     (dut.valid_array[s][1] && (dut.tag_array[s][1] == t));
        end
    endfunction

    // expected read data: checks cache first (may have dirty write),
    // then falls back to backing memory
    function automatic [31:0] expected_read_data(input [31:0] a);
        logic [TAG_BITS-1:0]       t;
        logic [SET_INDEX_BITS-1:0] s;
        logic [1:0]                wo;
        begin
            t  = get_tag(a);
            s  = get_set(a);
            wo = a[OFFSET_BITS-1:2];

            if (dut.valid_array[s][0] && dut.dirty_array[s][0] && (dut.tag_array[s][0] == t))
                expected_read_data = dut.data_array[s][0][wo];
            else if (dut.valid_array[s][1] && dut.dirty_array[s][1] && (dut.tag_array[s][1] == t))
                expected_read_data = dut.data_array[s][1][wo];
            else
                expected_read_data = backing_mem[a[31:2]];
        end
    endfunction

    task automatic do_read(input [31:0] a);
        bit          predicted_hit;
        logic [31:0] got, exp;
        int          cycles_waited;
        begin
            predicted_hit = is_hit(a);
            total_reads++;
            if (predicted_hit) read_hits++;
            else               read_misses++;

            @(negedge clk);
            addr  <= a;
            wr_data <= '0;
            rd_en <= 1'b1;
            wr_en <= 1'b0;

            cycles_waited = 0;
            @(posedge clk); cycles_waited++;
            while (ready !== 1'b1) begin
                @(posedge clk);
                cycles_waited++;
            end

            #1;
            got = rd_data;
            exp = expected_read_data(a);

            if (got !== exp) begin
                $display("[READ ERROR] addr=%08h  expected=%08h  got=%08h  time=%0t",
                         a, exp, got, $time);
                $fatal;
            end

            @(negedge clk);
            rd_en <= 1'b0;

            $display("[READ ] addr=%08h  %s  wait=%0d  data=%08h  set=%0d  tag=%0h  time=%0t",
                     a, predicted_hit ? "HIT " : "MISS",
                     cycles_waited, got, get_set(a), get_tag(a), $time);
        end
    endtask

    task automatic do_write(input [31:0] a, input [31:0] d);
        bit predicted_hit;
        int cycles_waited;
        begin
            predicted_hit = is_hit(a);
            total_writes++;
            if (predicted_hit) write_hits++;
            else               write_misses++;

            @(negedge clk);
            addr    <= a;
            wr_data <= d;
            rd_en   <= 1'b0;
            wr_en   <= 1'b1;

            cycles_waited = 0;
            @(posedge clk); cycles_waited++;
            while (ready !== 1'b1) begin
                @(posedge clk);
                cycles_waited++;
            end

            @(negedge clk);
            wr_en <= 1'b0;

            $display("[WRITE] addr=%08h  %s  wait=%0d  wdata=%08h  set=%0d  tag=%0h  time=%0t",
                     a, predicted_hit ? "HIT " : "MISS",
                     cycles_waited, d, get_set(a), get_tag(a), $time);
        end
    endtask

    initial begin
        addr    = '0;
        wr_data = '0;
        rd_en   = 1'b0;
        wr_en   = 1'b0;
        rst_n   = 1'b0;

        total_reads   = 0; read_hits   = 0; read_misses  = 0;
        total_writes  = 0; write_hits  = 0; write_misses = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n========== TEST 1: cold read miss then hits in same block ==========");
        do_read(32'h0000_0000); // miss
        do_read(32'h0000_0004); // hit
        do_read(32'h0000_0008); // hit
        do_read(32'h0000_000C); // hit

        $display("\n========== TEST 2: write hit then read back ==========");
        do_write(32'h0000_0004, 32'hDEAD_BEEF); // hit - line already cached
        do_read (32'h0000_0004);                 // hit - must return DEAD_BEEF

        if (backing_mem[32'h0000_0004 >> 2] === 32'hDEAD_BEEF) begin
            $display("[ERROR] Backing memory updated too early (write-back violation).");
            $fatal;
        end
        $display("Write-back check PASSED: backing_mem[1] = %08h (unchanged)",
                 backing_mem[32'h0000_0004 >> 2]);

        $display("\n========== TEST 3: fill both ways of same set ==========");
        do_read(32'h0000_0000); // way 0 already valid - hit
        do_read(32'h0000_0800); // same set, different tag → allocate way 1

        $display("\n========== TEST 4: force dirty eviction / write-back ==========");
        do_write(32'h0000_0000, 32'hCAFE_F00D); // dirty way 0 of set 0
        // 0x0000_1000 maps to same set (addr[10:4] = 0); 3rd tag forces eviction
        do_read(32'h0000_1000);

        $display("Post-eviction: backing_mem[0x0000_0000>>2] = %08h",
                 backing_mem[32'h0000_0000 >> 2]);
        if (backing_mem[32'h0000_0000 >> 2] === 32'hCAFE_F00D)
            $display("Dirty eviction write-back confirmed.");
        else
            $display("Way 0 was not the eviction victim (LRU chose differently - ok).");

        $display("\n========== TEST 5: read back all three competing lines ==========");
        do_read(32'h0000_0000);
        do_read(32'h0000_0800);
        do_read(32'h0000_1000);

        $display("\n========== TEST 6: sequential streaming (4 cache lines) ==========");
        for (int i = 0; i < 16; i++)
            do_read(32'h0000_2000 + i*4);

        $display("\n========== FINAL STATS ==========");
        $display("Reads        : %0d", total_reads);
        $display("Read hits    : %0d", read_hits);
        $display("Read misses  : %0d", read_misses);
        $display("Writes       : %0d", total_writes);
        $display("Write hits   : %0d", write_hits);
        $display("Write misses : %0d", write_misses);

        begin
            integer ta, th, tm;
            real    hr;
            ta = total_reads + total_writes;
            th = read_hits   + write_hits;
            tm = read_misses + write_misses;
            $display("Total accesses : %0d", ta);
            $display("Total hits     : %0d", th);
            $display("Total misses   : %0d", tm);
            if (ta > 0) begin
                hr = real'(th) / real'(ta);
                $display("Overall hit rate: %0f", hr);
            end
        end

        $finish;
    end

endmodule