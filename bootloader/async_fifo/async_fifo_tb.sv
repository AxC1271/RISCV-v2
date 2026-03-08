`timescale 1ns / 1ps

module tb_async_fifo();

  localparam int DATA_WIDTH = 8;
  localparam int DEPTH      = 64;

  logic clk_w, clk_r;
  logic rst_n_w, rst_n_r;

  logic wr_en;
  logic [DATA_WIDTH-1:0] wr_data;

  logic rd_en;
  logic [DATA_WIDTH-1:0] rd_data;

  logic empty, full;

  // instantiate the unit under test
  async_fifo # (
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
  ) dut (
    .clk_w(clk_w),
    .rst_n_w(rst_n_w),
    .wr_en(wr_en),
    .wr_data(wr_data),

    .clk_r(clk_r),
    .rst_n_r(rst_n_r),
    .rd_en(rd_en),
    .rd_data(rd_data),

    .empty(empty),
    .full(full)
  );

  // two independent clocks
  initial begin
    clk_w = 0;
    forever #5 clk_w = ~clk_w;  // 10ns
  end

  initial begin
    clk_r = 0;
    forever #7 clk_r = ~clk_r;  // 14ns (async)
  end

  // simple expected model: fixed array + counters
  byte expected [0:DEPTH-1];
  int  wr_count;
  int  rd_count;

  // write until full with a known pattern
  task automatic write_until_full();
    begin
      wr_count = 0;
      wr_en    = 0;
      wr_data  = '0;

      // fill expected pattern
      for (int i = 0; i < DEPTH; i++) expected[i] = byte'(i);

      while (!full && wr_count < DEPTH) begin
        @(posedge clk_w);
        wr_en   <= 1;
        wr_data <= expected[wr_count];

        // if fifo accepts it (not full), count it
        if (!full) wr_count++;
      end

      @(posedge clk_w);
      wr_en <= 0;

      $display("[TB] Wrote %0d bytes. full=%0b time=%0t", wr_count, full, $time);

      if (wr_count == 0) $error("[TB] FIFO never accepted any writes!");
    end
  endtask

  // read until empty and check data ordering
  task automatic read_and_check_until_empty();
    byte got;
    begin
      rd_count = 0;
      rd_en    = 0;

      // give synchronizers a moment (optional but helps reduce false surprises)
      repeat (5) @(posedge clk_r);

      while (!empty && rd_count < wr_count) begin
        @(posedge clk_r);
        rd_en <= 1;

        if (!empty) begin
          // rd_data updates on this same edge (nonblocking in DUT)
          // wait a tiny delay so rd_data is visible in TB
          #1;
          got = rd_data;

          if (got !== expected[rd_count]) begin
            $error("[TB] MISMATCH: expected %0d got %0d at rd_count=%0d time=%0t",
                   expected[rd_count], got, rd_count, $time);
          end

          rd_count++;
        end
      end

      @(posedge clk_r);
      rd_en <= 0;

      $display("[TB] Read %0d bytes. empty=%0b time=%0t", rd_count, empty, $time);

      if (rd_count != wr_count) begin
        $error("[TB] Read count (%0d) != write count (%0d)", rd_count, wr_count);
      end
    end
  endtask

  // main
  initial begin
    $display("[TB] Starting simple async FIFO test...");

    // init
    wr_en   = 0;
    rd_en   = 0;
    wr_data = 0;

    // reset
    rst_n_w = 0;
    rst_n_r = 0;

    repeat (5) @(posedge clk_w);
    repeat (5) @(posedge clk_r);

    rst_n_w = 1;
    rst_n_r = 1;

    // let flags settle
    repeat (5) @(posedge clk_r);

    // sanity after reset
    if (!empty) $error("[TB] After reset, expected empty=1");
    if (full)   $error("[TB] After reset, expected full=0");

    // directed tests
    write_until_full();
    read_and_check_until_empty();

    // Try reading while empty (should not advance / should not crash)
    $display("[TB] Trying reads while empty...");
    repeat (5) begin
      @(posedge clk_r);
      rd_en <= 1;
    end
    @(posedge clk_r);
    rd_en <= 0;

    // Try writing after draining (should work again)
    $display("[TB] Writing a few bytes after empty...");
    wr_count = 0;
    for (int i = 0; i < 8; i++) expected[i] = byte'(8'hA0 + i);

    repeat (2) @(posedge clk_w);
    for (int i = 0; i < 8; i++) begin
      @(posedge clk_w);
      wr_en   <= 1;
      wr_data <= expected[i];
      if (!full) wr_count++;
    end
    @(posedge clk_w);
    wr_en <= 0;

    // read back 8
    repeat (5) @(posedge clk_r);
    rd_count = 0;
    while (rd_count < wr_count) begin
      @(posedge clk_r);
      rd_en <= 1;
      if (!empty) begin
        #1;
        if (rd_data !== expected[rd_count]) begin
          $error("[TB] Post-drain MISMATCH: expected 0x%0h got 0x%0h at i=%0d",
                 expected[rd_count], rd_data, rd_count);
        end
        rd_count++;
      end
    end
    @(posedge clk_r);
    rd_en <= 0;

    $display("[TB] DONE.");
    $finish;
  end

endmodule