module register_file (
    input logic clk,
    input logic rst_n,
    input logic[4:0] rd_addr1,
    input logic[4:0] rd_addr2,

    input logic[4:0] wr_addr,
    input logic[31:0] wr_data,
    input logic wr_en,

    output logic[31:0] rd_data1,
    output logic[31:0] rd_data2
);

    logic[31:0] mem [0:31];

    // make reads combinational
    assign rd_data1 = mem[rd_addr1];
    assign rd_data2 = mem[rd_addr2];

    // write process should be clocked
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                mem[i] <= 32'h0;
            end
        end else begin
            if (wr_en && wr_addr != 5'b00000) begin
                mem[wr_addr] <= wr_data;
            end
        end
    end
endmodule