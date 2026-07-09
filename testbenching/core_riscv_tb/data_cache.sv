module data_cache # (
    parameter CACHE_SIZE = 4096,
    parameter BLOCK_SIZE = 16,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_WAYS   = 2
)(
    input  logic clk,
    input  logic rst_n,

    input  logic[ADDR_WIDTH-1:0] addr,
    input  logic[DATA_WIDTH-1:0] wr_data,
    input  logic rd_en,
    input  logic wr_en,

    output logic[DATA_WIDTH-1:0] rd_data,
    output logic                 cache_ready,
    output logic[ADDR_WIDTH-1:0] mem_addr,
    output logic[DATA_WIDTH-1:0] mem_wr_data,
    output logic mem_rd_en,
    output logic mem_wr_en,

    input  logic[DATA_WIDTH-1:0] mem_rd_data,
    input  logic mem_ready
);

endmodule