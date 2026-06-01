`timescale 1ns / 1ps

module hazard_unit (
    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,
    input logic [4:0] ex_rd,
    input logic ex_mem_read,
    input logic mem_stall,
    output logic stall,
    output logic flush_id_ex,
    output logic flush_mem_wb
);

    logic load_use_hazard;

    assign load_use_hazard = ex_mem_read
                          && (ex_rd != 5'd0)
                          && ((ex_rd == id_rs1) || (ex_rd == id_rs2));

    always_comb begin
        stall = mem_stall;
        flush_id_ex = load_use_hazard || mem_stall;
        flush_mem_wb = mem_stall;
    end

endmodule