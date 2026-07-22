module register_file (
    input  logic clk,
    input  logic rst_n,

    // read ports
    input  logic[4:0]  rd_addr1,
    input  logic[4:0]  rd_addr2,
    output logic[31:0] rd_data1,
    output logic[31:0] rd_data2,

    // write port
    input  logic[4:0]  wr_addr,
    input  logic[31:0] wr_data,
    input  logic       reg_write
);

    logic[31:0] mem [0:31];

    logic bypass1, bypass2;
    assign bypass1 = reg_write && (wr_addr != 5'b0) && (wr_addr == rd_addr1);
    assign bypass2 = reg_write && (wr_addr != 5'b0) && (wr_addr == rd_addr2);

    assign rd_data1 = bypass1 ? wr_data : mem[rd_addr1];
    assign rd_data2 = bypass2 ? wr_data : mem[rd_addr2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                mem[i] <= 32'h0;
            end
        end else begin
            if (reg_write && wr_addr != 5'b00000) begin
                mem[wr_addr] <= wr_data;
            end
        end
    end

endmodule