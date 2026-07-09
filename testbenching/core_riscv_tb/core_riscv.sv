module core_riscv (
    input  logic clk,
    input  logic rst_n,
    input  logic cpu_enable,

    output logic [31:0] imem_addr,
    output logic        imem_req,
    input  logic [31:0] imem_rdata,
    input  logic        imem_ready,

    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_rd_en,
    output logic        dmem_wr_en,
    output logic [2:0]  dmem_size,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_ready
);

endmodule