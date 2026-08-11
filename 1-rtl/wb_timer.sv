// timer peripheral 

module wb_timer (
    input  logic clk,
    input  logic rst_n,
    
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic [3:0]  wb_sel,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    
    // output from timer
);

    always_ff @(posedge clk) begin
    end

endmodule