module soc_riscv (
    input  logic clk,
    input  logic rst_n,
);

    localparam RESET_VECTOR = 32'h0;

    core_riscv core # (
        .RESET_VECTOR(RESET_VECTOR)
    )(
        .clk(clk),
        .rst_n(rst_n)
        .cpu_enable(),
        
        .imem_addr(),
        .imem_req(),
        .imem_rdata(),
        .imem_ready(),

        .dmem_addr(),
        .dmem_wdata(),
        .dmem_wstrb(),
        .dmem_rd_en(),
        .dmem_wr_en(),
        .dmem_rdata(),
        .dmem_ready(),

        .debug_pc(),
        .debug_instr(),
        .debug_reg_data(),
        .debug_halted()
    );

    wb_master master (
        .dmem_addr(),
        .dmem_wdata(),
        .dmem_wstrb(),
        .dmem_rd_en(),
        .dmem_wr_en(),
        .dmem_rdata(),
        .dmem_ready(),
        .wb_cycle(),
        .wb_strb(),
        .wb_we(),
        .wb_addr(),
        .wb_dat_w(),
        .wb_sel(),
        .wb_dat_r(),
        .wb_ack()
    );

    wb_interconnect bus (
        .m_addr(),
        .m_wdata(),
        .m_wstrb(),
        .m_rd_en(),
        .m_wr_en(),
        .m_rdata(),
        .m_ready(),

        .ram_addr(),
        .ram_wdata(),
        .ram_wstrb(),
        .ram_rd_en(),
        .ram_wr_en(),
        .ram_rdata(),
        .ram_ready(),

        .uart_addr(),
        .uart_wdata(),
        .uart_wstrb(),
        .uart_rd_en(),
        .uart_wr_en(),
        .uart_rdata(),
        .uart_ready(),

        .gpio_addr(),
        .gpio_wdata(),
        .gpio_wstrb(),
        .gpio_rd_en(),
        .gpio_wr_en(),
        .gpio_rdata(),
        .gpio_ready()
    );

endmodule