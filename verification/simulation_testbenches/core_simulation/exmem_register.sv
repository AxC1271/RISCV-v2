module exmem_register (
    input  logic clk,
    input  logic rst_n,
    input  logic stall,

    // ex_result is the post-mux EX value: pc+4 for JAL/JALR, otherwise the
    // ALU result. jump is fully consumed in EX, so it does not travel here.
    input  logic[31:0] ex_result,
    input  logic[31:0] ex_store_data,   // forwarded rs2
    input  logic[4:0]  ex_rd,
    input  logic[2:0]  ex_funct3,       // load/store size + sign
    input  logic       ex_memread,
    input  logic       ex_memwrite,
    input  logic       ex_memtoreg,
    input  logic       ex_regwrite,
    input  logic       ex_ebreak,

    output logic[31:0] mem_alu_result,
    output logic[31:0] mem_store_data,
    output logic[4:0]  mem_rd,
    output logic[2:0]  mem_funct3,
    output logic       mem_memread,
    output logic       mem_memwrite,
    output logic       mem_memtoreg,
    output logic       mem_regwrite,
    output logic       mem_ebreak
);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mem_alu_result <= 32'h0;
            mem_store_data <= 32'b0;
            mem_rd         <= 5'b0;
            mem_funct3     <= 3'b0;
            mem_memread    <= 1'b0;
            mem_memwrite   <= 1'b0;
            mem_memtoreg   <= 1'b0;
            mem_regwrite   <= 1'b0;
            mem_ebreak     <= 1'b0;
        end else if (stall) begin
            // hold
        end else begin
            mem_alu_result <= ex_result;
            mem_store_data <= ex_store_data;
            mem_rd         <= ex_rd;
            mem_funct3     <= ex_funct3;
            mem_memread    <= ex_memread;
            mem_memwrite   <= ex_memwrite;
            mem_memtoreg   <= ex_memtoreg;
            mem_regwrite   <= ex_regwrite;
            mem_ebreak     <= ex_ebreak;
        end
    end

endmodule