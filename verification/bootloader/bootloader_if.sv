// bootloader interface class

interface bootloader_if(input bit clk);
    // inputs
    logic uart_clk,
    logic uart_rst_n;
    logic uart_rx;

    logic cpu_clk;
    logic cpu_rst_n;

    // outputs
    logic imem_wr_data;
    logic imem_wr_addr;
    logic imem_wr_en;

    logic boot_done;
    logic boot_error;

    // clocking 
    clocking driver_cb @(posedge clk);
        output uart_clk;
        output uart_rst_n;
        output uart_rx;
        output cpu_clk;
        output cpu_rst_n;
        input imem_wr_data;
        input imem_wr_addr;
        input imem_wr_en;
        input boot_done;
        input boot_error;
    endclocking

    clocking monitor_cb @(posedge clk);
        input uart_clk;
        input uart_rst_n;
        input uart_rx;
        input cpu_clk;
        input cpu_rst_n;
        input imem_wr_data;
        input imem_wr_addr;
        input imem_wr_en;
        input boot_done;
        input boot_error;
    endclocking

    modport DRIVER (clocking driver_cb, input clk);
    modport MONITOR (clocking monitor_cb, input clk);
endinterface