`timescale 1ns/1ps

module uart_rx_tb();

  localparam int BAUD_RATE  = 115200;
  localparam int CLK_FREQ   = 100_000_000;
  localparam int DATA_WIDTH = 8;

  localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
  localparam int CLK_PERIOD_NS = 10; // 100 MHz
  localparam time BIT_TIME = CLKS_PER_BIT * CLK_PERIOD_NS; // in ns

  logic clk, rst_n;
  logic rx;
  logic [DATA_WIDTH-1:0] rx_data;
  logic wr;

  uart_rx #(
    .BAUD_RATE(BAUD_RATE),
    .DATA_WIDTH(DATA_WIDTH),
    .CLK_FREQ(CLK_FREQ)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .rx_data(rx_data),
    .wr(wr)
  );

  // clk generator
  initial begin
    clk = 0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  // expected tracking (simple)
  byte expected [0:15];
  int exp_wr_idx;

  // send task: start + 8 data (LSB first) + stop
  task automatic uart_send_byte(input byte b);
    begin
      // idle high before frame
      rx = 1;
      #(BIT_TIME);

      // start bit
      rx = 0;
      #(BIT_TIME);

      // data bits LSB first
      for (int i = 0; i < 8; i++) begin
        rx = b[i];
        #(BIT_TIME);
      end

      // stop bit
      rx = 1;
      #(BIT_TIME);

      // small gap (optional, makes waveform clearer)
      #(BIT_TIME);
    end
  endtask

  // scoreboard/check on wr pulse
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      exp_wr_idx <= 0;
    end else if (wr) begin
      if (rx_data !== expected[exp_wr_idx]) begin
        $error("[TB] MISMATCH: expected 0x%0h got 0x%0h at idx=%0d time=%0t",
               expected[exp_wr_idx], rx_data, exp_wr_idx, $time);
      end else begin
        $display("[TB] OK: got 0x%0h at idx=%0d time=%0t",
                 rx_data, exp_wr_idx, $time);
      end
      exp_wr_idx <= exp_wr_idx + 1;
    end
  end

  initial begin
    $display("[TB] Starting UART RX test. BIT_TIME=%0t ns, CLKS_PER_BIT=%0d",
             BIT_TIME, CLKS_PER_BIT);

    // init
    rx = 1;
    rst_n = 0;
    exp_wr_idx = 0;

    // reset
    repeat (10) @(posedge clk);
    rst_n = 1;

    // build expected list
    expected[0] = 8'h55; // 01010101 nice for waveform
    expected[1] = 8'hA3;
    expected[2] = 8'h00;
    expected[3] = 8'hFF;

    // send frames
    uart_send_byte(expected[0]);
    uart_send_byte(expected[1]);
    uart_send_byte(expected[2]);
    uart_send_byte(expected[3]);

    // wait enough time for last wr
    #(20*BIT_TIME);

    if (exp_wr_idx != 4) begin
      $error("[TB] Expected 4 received bytes, got %0d", exp_wr_idx);
    end else begin
      $display("[TB] PASS: received all bytes.");
    end

    $finish;
  end

endmodule