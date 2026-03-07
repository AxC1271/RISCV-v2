`timescale 1ns / 1ps

module data_cache_tb();

    localparam CLK_PERIOD = 10;
    localparam MEM_WORDS  = 16384; // backing memory words

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

    logic                  clk;
    logic                  rst_n;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  rd_en;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  ready;

    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wr_data;
    logic                  mem_rd_en;
    logic                  mem_wr_en;
    logic [DATA_WIDTH-1:0] mem_rd_data;
    logic                  mem_ready;

    data_cache #(
        .CACHE_SIZE (CACHE_SIZE),
        .BLOCK_SIZE (BLOCK_SIZE),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_WAYS   (NUM_WAYS)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .addr       (addr),
        .wr_data    (wr_data),
        .rd_en      (rd_en),
        .wr_en      (wr_en),
        .rd_data    (rd_data),
        .ready      (ready),
        .mem_addr   (mem_addr),
        .mem_wr_data(mem_wr_data),
        .mem_rd_en  (mem_rd_en),
        .mem_wr_en  (mem_wr_en),
        .mem_rd_data(mem_rd_data),
        .mem_ready  (mem_ready)
    );

    logic [31:0] backing_mem [0:MEM_WORDS-1];

    initial begin
        for (int i = 0; i < MEM_WORDS; i++) begin
            backing_mem[i] = 32'hA000_0000 + i;
        end
    end

    // one-cycle memory model
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready   <= 1'b0;
            mem_rd_data <= 32'b0;
        end else begin
            mem_ready <= 1'b0;

            if (mem_rd_en) begin
                mem_ready   <= 1'b1;
                mem_rd_data <= backing_mem[mem_addr[31:2]];
            end

            if (mem_wr_en) begin
                mem_ready <= 1'b1;
                backing_mem[mem_addr[31:2]] <= mem_wr_data;
            end
        end
    end

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer total_reads, read_hits, read_misses;
    integer total_writes, write_hits, write_misses;

    function automatic [TAG_BITS-1:0] get_tag(input [31:0] a);
        get_tag = a[ADDR_WIDTH-1:SET_INDEX_BITS+OFFSET_BITS];
    endfunction

    function automatic [SET_INDEX_BITS-1:0] get_set(input [31:0] a);
        get_set = a[SET_INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
    endfunction

    function automatic [1:0] get_word_offset(input [31:0] a);
        get_word_offset = a[OFFSET_BITS-1:2];
    endfunction

    function automatic bit is_hit(input [31:0] a);
        logic [TAG_BITS-1:0] t;
        logic [SET_INDEX_BITS-1:0] s;
        begin
            t = get_tag(a);
            s = get_set(a);
            is_hit =
                (dut.valid_array[s][0] && (dut.tag_array[s][0] == t)) ||
                (dut.valid_array[s][1] && (dut.tag_array[s][1] == t));
        end
    endfunction

    function automatic [31:0] expected_mem_data(input [31:0] a);
        expected_mem_data = backing_mem[a[31:2]];
    endfunction

    task automatic do_read(input [31:0] a);
        bit predicted_hit;
        logic [31:0] got, exp;
        int cycles_waited;
        begin
            predicted_hit = is_hit(a);
            total_reads++;
            if (predicted_hit) read_hits++;
            else               read_misses++;

            @(negedge clk);
            addr    <= a;
            wr_data <= '0;
            rd_en   <= 1'b1;
            wr_en   <= 1'b0;

            cycles_waited = 0;
            while (ready !== 1'b1) begin
                @(posedge clk);
                cycles_waited++;
            end

            got = rd_data;
            exp = expected_mem_data(a);

            if (got !== exp) begin
                $display("[READ ERROR] addr=%08h expected=%08h got=%08h time=%0t",
                         a, exp, got, $time);
                $fatal;
            end

            @(negedge clk);
            rd_en <= 1'b0;

            $display("[READ ] addr=%08h  %s  wait=%0d  data=%08h  set=%0d tag=%0h time=%0t",
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
            while (ready !== 1'b1) begin
                @(posedge clk);
                cycles_waited++;
            end

            @(negedge clk);
            wr_en <= 1'b0;

            $display("[WRITE] addr=%08h  %s  wait=%0d  wdata=%08h  set=%0d tag=%0h time=%0t",
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

        total_reads   = 0;
        read_hits     = 0;
        read_misses   = 0;
        total_writes  = 0;
        write_hits    = 0;
        write_misses  = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("\n========== TEST 1: cold read miss then read hits in same block ==========");
        do_read(32'h0000_0000); // miss
        do_read(32'h0000_0004); // hit
        do_read(32'h0000_0008); // hit
        do_read(32'h0000_000C); // hit

        $display("\n========== TEST 2: write hit then read back ==========");
        do_write(32'h0000_0004, 32'hDEAD_BEEF); // should hit
        do_read (32'h0000_0004);                // should hit and return DEAD_BEEF

        // check backing memory has NOT changed yet (write-back cache)
        if (backing_mem[32'h0000_0004 >> 2] === 32'hDEAD_BEEF) begin
            $display("[ERROR] Backing memory updated too early on write-back cache.");
            $fatal;
        end

        $display("\n========== TEST 3: fill both ways of same set ==========");
        // These addresses map to same set if they differ in tag above bit [10:4].
        // Since OFFSET_BITS=4 and SET_INDEX_BITS=7, set is bits [10:4].
        // Adding 0x800 changes tag while preserving set.
        do_read(32'h0000_0000); // existing line
        do_read(32'h0000_0800); // same set, different tag -> occupy other way

        $display("\n========== TEST 4: force dirty eviction/writeback ==========");
        // Make 0x0000_0000 dirty, then bring in a 3rd tag for same set
        do_write(32'h0000_0000, 32'hCAFE_F00D);
        do_read (32'h0000_1000); // same set again, forces eviction of one way

        // At this point, depending on LRU, the dirty line may have been written back.
        // Check whether backing memory now reflects writeback if line was evicted.
        // We don't hard-fail here because exact victim depends on your LRU/update behavior.
        $display("Post-eviction backing_mem[0x0000_0000>>2] = %08h",
                 backing_mem[32'h0000_0000 >> 2]);

        $display("\n========== TEST 5: read back all three competing lines ==========");
        do_read(32'h0000_0000);
        do_read(32'h0000_0800);
        do_read(32'h0000_1000);

        $display("\n========== TEST 6: sequential streaming ==========");
        for (int i = 0; i < 16; i++) begin
            do_read(32'h0000_2000 + i*4);
        end

        $display("\n========== FINAL STATS ==========");
        $display("Reads        : %0d", total_reads);
        $display("Read hits    : %0d", read_hits);
        $display("Read misses  : %0d", read_misses);
        $display("Writes       : %0d", total_writes);
        $display("Write hits   : %0d", write_hits);
        $display("Write misses : %0d", write_misses);

        if (total_reads > 0) begin
            real rhr;
            rhr = real'(read_hits) / real'(total_reads);
            $display("Read hit rate  : %0f", rhr);
        end

        if (total_writes > 0) begin
            real whr;
            whr = real'(write_hits) / real'(total_writes);
            $display("Write hit rate : %0f", whr);
        end

        begin
            integer total_accesses, total_hits, total_misses;
            real overall_hr;
            total_accesses = total_reads + total_writes;
            total_hits     = read_hits + write_hits;
            total_misses   = read_misses + write_misses;

            $display("Total accesses : %0d", total_accesses);
            $display("Total hits     : %0d", total_hits);
            $display("Total misses   : %0d", total_misses);

            if (total_accesses > 0) begin
                overall_hr = real'(total_hits) / real'(total_accesses);
                $display("Overall hit rate: %0f", overall_hr);
            end
        end

        $finish;
    end

endmodule