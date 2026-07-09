module forward_unit (
    input  logic[4:0] idex_rs1,
    input  logic[4:0] idex_rs2,

    input  logic[4:0] exmem_rd,
    input  logic      exmem_regwrite,

    input  logic[4:0] memwb_rd,
    input  logic      memwb_regwrite,

    output logic[1:0] forward_a,
    output logic[1:0] forward_b
);

    // encoding for forward select
    // 2'b00 = no forwarding (use idex register value)
    // 2'b01: forward memwb (use wb stage result)
    // 2'b10: forward exmem (use mem stage result)

    always_comb begin
        // default case: don't forward
        forward_a = 2'b00;
        forward_b = 2'b00;

        // hazard for forward_a
        if (idex_rs1 == exmem_rd && exmem_regwrite && exmem_rd != 5'b00000) begin
            forward_a = 2'b10;
        end else if (idex_rs1 == memwb_rd && memwb_regwrite && memwb_rd != 5'b00000) begin
            forward_a = 2'b01;
        end

        // hazard for forward_b
        if (idex_rs2 == exmem_rd && exmem_regwrite && exmem_rd != 5'b00000) begin
            forward_b = 2'b10;
        end else if (idex_rs2 == memwb_rd && memwb_regwrite && memwb_rd != 5'b00000) begin
            forward_b = 2'b01;
        end
    end

endmodule