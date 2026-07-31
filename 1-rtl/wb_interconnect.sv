module wb_interconnect (
    // ports from master wrapper
    input  logic        mstr_cycle,
    input  logic        mstr_strb, 
    input  logic        mstr_we,
    input  logic [31:0] mstr_addr,
    input  logic [31:0] mstr_dat_w, 
    input  logic [3:0]  mstr_sel,
    output logic [31:0] mstr_dat_r,
    output logic        mstr_ack,
    // decode ports to peripherals
    // connects the cpu to four peripherals:
    // ram, gpio, uart, and a timer, 5th
    // bit is added for invalid addresses
    output logic [4:0]  slve_sel, // one hot encoded

    // acknowledge/data signals of each slave
    output logic        ram_ack,
    output logic [31:0] ram_rdata,
    output logic        gpio_ack,
    output logic [31:0] gpio_rdata,
    output logic        uart_ack,
    output logic [31:0] uart_rdata,
    output logic        timer_ack,
    output logic [31:0] timer_rdata
);

    // how I'm doing naming conventions: mstr_ means the signals connect
    // straight to the master port, but doesn't necessarily mean master 
    // drives it. mstr_ack, for example, is an acknowledge signal from a
    // slave saent TO the master


endmodule