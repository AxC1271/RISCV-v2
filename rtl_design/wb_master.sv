module wb_master (
    // cpu interface
    input  logic [31:0] dmem_addr,
    input  logic [31:0] dmem_wdata,
    input  logic [3:0]  dmem_wstrb,
    input  logic        dmem_rd_en,
    input  logic        dmem_wr_en,
    output logic [31:0] dmem_rdata,
    output logic        dmem_ready,
    // master output ports
    output logic        wb_cycle, // bus cycle in progress
    output logic        wb_stb,   // this current transfer is valid
    output logic        wb_we,    // 1 = write, 0 = read
    output logic [31:0] wb_adr,   // byte address
    output logic [31:0] wb_dat_w, // write data
    output logic [3:0]  wb_sel,   // byte lane enable
    input  logic [31:0] wb_dat_r, // read data
    input  logic        wb_ack    // acknowledge
);

    // let's just do the easy assigns first on the wishbone side
    assign wb_cycle = (dmem_rd_en || dmem_wr_en);
    assign wb_stb   = (dmem_rd_en || dmem_wr_en);
    assign wb_adr   = dmem_addr;
    assign wb_dat_w = dmem_wdata;
    assign wb_sel   = dmem_wstrb;
    assign wb_we    = dmem_wr_en;

    // let's assign the signals from the CPU side
    assign dmem_rdata = wb_dat_r;
    assign dmem_ready = wb_ack;
endmodule