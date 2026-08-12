module wb_ram (
    input  logic clk,
    input  logic rst_n,
    
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic [3:0]  wb_sel,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    
    output logic [31:0] wb_dat_r,
    output logic        wb_ack
);

    // 4096 words (16 kB / 4 bytes per word)
    logic [31:0] ram [0:4095];

    // lower 14 bits of address gives word address (0–4095)
    logic [13:0] addr_word;
    assign addr_word = wb_addr[15:2];

    // valid request: cycle high, strobe high
    logic valid_req;
    assign valid_req = wb_cycle & wb_strb;

    // registered acknowledge signal
    logic ack_r;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_r <= 1'b0;
        end else begin
            ack_r <= valid_req;
        end
    end
    
    assign wb_ack = ack_r;

    // synchronous read: latch address, read on next cycle
    logic [13:0] addr_r;
    
    always_ff @(posedge clk) begin
        if (valid_req) begin
            addr_r <= addr_word;
        end
    end
    
    // data out from latched address
    assign wb_dat_r = ram[addr_r];

    // write with byte enables
    always_ff @(posedge clk) begin
        if (valid_req && wb_we) begin
            if (wb_sel[3]) ram[addr_word][31:24] <= wb_dat_w[31:24];
            if (wb_sel[2]) ram[addr_word][23:16] <= wb_dat_w[23:16];
            if (wb_sel[1]) ram[addr_word][15:8]  <= wb_dat_w[15:8];
            if (wb_sel[0]) ram[addr_word][7:0]   <= wb_dat_w[7:0];
        end
    end

    // optional: initialize RAM to zero on reset
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4096; i++) begin
                ram[i] <= 32'h0000_0000;
            end
        end
    end

endmodule