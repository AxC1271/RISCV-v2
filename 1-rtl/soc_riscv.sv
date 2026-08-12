module soc_riscv (
    input  logic clk,
    input  logic rst_n,
    
    output logic [15:0] led,
    output logic [1:0]  pmod_out,
    input  logic [15:0] sw,
    
    input  logic        usb_uart_rx,

    input  logic        pmod_uart_rx,
    output logic        pmod_uart_tx
);

    localparam RESET_VECTOR = 32'h0;
    
    logic [31:0] imem [0:4095];
    
    logic [31:0] cpu_imem_addr;
    logic [31:0] cpu_imem_rdata;
    assign cpu_imem_rdata = imem[cpu_imem_addr[15:2]];
    
    logic [31:0] boot_imem_addr;
    logic [31:0] boot_imem_wdata;
    logic        boot_imem_wr_en;
    
    always_ff @(posedge clk) begin
        if (boot_imem_wr_en) begin
            imem[boot_imem_addr[15:2]] <= boot_imem_wdata;
        end
    end
    
    logic        cpu_enable;

    bootloader bootloader (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(usb_uart_rx),
        .imem_addr(boot_imem_addr),
        .imem_wdata(boot_imem_wdata),
        .imem_wr_en(boot_imem_wr_en),
        .cpu_enable(cpu_enable)
    );
    
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    core_riscv #(
        .RESET_VECTOR(RESET_VECTOR)
    ) core (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_enable(cpu_enable),
        
        .imem_addr(cpu_imem_addr),
        .imem_req(),
        .imem_rdata(cpu_imem_rdata),
        .imem_ready(1'b1),

        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_rd_en(dmem_rd_en),
        .dmem_wr_en(dmem_wr_en),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),

        .debug_pc(),
        .debug_instr(),
        .debug_reg_data(),
        .debug_halted()
    );
    
    logic [31:0] ram_addr,   uart_addr,   timer_addr,   gpio_addr;
    logic [31:0] ram_wdata,  uart_wdata,  timer_wdata,  gpio_wdata;
    logic [31:0] ram_rdata,  uart_rdata,  timer_rdata,  gpio_rdata;
    logic [3:0]  ram_wstrb,  uart_wstrb,  timer_wstrb,  gpio_wstrb;
    logic        ram_rd_en,  uart_rd_en,  timer_rd_en,  gpio_rd_en;
    logic        ram_wr_en,  uart_wr_en,  timer_wr_en,  gpio_wr_en;
    logic        ram_ready,  uart_ready,  timer_ready,  gpio_ready;

    wb_interconnect bus (
        .m_addr(dmem_addr),
        .m_wdata(dmem_wdata),
        .m_wstrb(dmem_wstrb),
        .m_rd_en(dmem_rd_en),
        .m_wr_en(dmem_wr_en),
        .m_rdata(dmem_rdata),
        .m_ready(dmem_ready),

        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata),
        .ram_wstrb(ram_wstrb),
        .ram_rd_en(ram_rd_en),
        .ram_wr_en(ram_wr_en),
        .ram_rdata(ram_rdata),
        .ram_ready(ram_ready),

        .timer_addr(timer_addr),
        .timer_wdata(timer_wdata),
        .timer_wstrb(timer_wstrb),
        .timer_rd_en(timer_rd_en),
        .timer_wr_en(timer_wr_en),
        .timer_rdata(timer_rdata),
        .timer_ready(timer_ready),

        .uart_addr(uart_addr),
        .uart_wdata(uart_wdata),
        .uart_wstrb(uart_wstrb),
        .uart_rd_en(uart_rd_en),
        .uart_wr_en(uart_wr_en),
        .uart_rdata(uart_rdata),
        .uart_ready(uart_ready),

        .gpio_addr(gpio_addr),
        .gpio_wdata(gpio_wdata),
        .gpio_wstrb(gpio_wstrb),
        .gpio_rd_en(gpio_rd_en),
        .gpio_wr_en(gpio_wr_en),
        .gpio_rdata(gpio_rdata),
        .gpio_ready(gpio_ready)
    );

    wb_ram ram (
        .clk(clk),
        .rst_n(rst_n),
        .wb_addr(ram_addr),
        .wb_dat_w(ram_wdata),
        .wb_sel(ram_wstrb),
        .wb_we(ram_wr_en),
        .wb_strb(ram_rd_en | ram_wr_en),
        .wb_cycle(ram_rd_en | ram_wr_en),
        .wb_dat_r(ram_rdata),
        .wb_ack(ram_ready)
    );

    wb_timer timer (
        .clk(clk),
        .rst_n(rst_n),
        .wb_addr(timer_addr),
        .wb_dat_w(timer_wdata),
        .wb_sel(timer_wstrb),
        .wb_we(timer_wr_en),
        .wb_strb(timer_rd_en | timer_wr_en),
        .wb_cycle(timer_rd_en | timer_wr_en),
        .wb_dat_r(timer_rdata),
        .wb_ack(timer_ready)
    );

    wb_uart uart (
        .clk(clk),
        .rst_n(rst_n),
        .wb_addr(uart_addr),
        .wb_dat_w(uart_wdata),
        .wb_we(uart_wr_en),
        .wb_strb(uart_rd_en | uart_wr_en),
        .wb_cycle(uart_rd_en | uart_wr_en),
        .wb_dat_r(uart_rdata),
        .wb_ack(uart_ready),
        .uart_rx(pmod_uart_rx),
        .uart_tx(pmod_uart_tx)
    );

    wb_gpio gpio (
        .clk(clk),
        .rst_n(rst_n),
        .wb_addr(gpio_addr),
        .wb_dat_w(gpio_wdata),
        .wb_sel(gpio_wstrb),
        .wb_we(gpio_wr_en),
        .wb_strb(gpio_rd_en | gpio_wr_en),
        .wb_cycle(gpio_rd_en | gpio_wr_en),
        .wb_dat_r(gpio_rdata),
        .wb_ack(gpio_ready),
        .led(led),
        .pmod(pmod_out),
        .sw(sw)
    );

endmodule