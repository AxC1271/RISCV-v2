// based on specs, our address space is 0x4000 - 0x7FFF due to linker

module wb_ram (
    input  logic clk,
    input  logic rst_n,
    
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic [3:0]  wb_sel,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    
    // output from ram
    output logic [31:0] wb_dat_r,
    output logic        wb_ack
);

    // 4096 words since 

endmodule