`timescale 1ns / 1ps

module hazard_unit (
    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,
    input logic [4:0] ex_rd,
    input logic ex_mem_read,
    input logic mem_stall,
    output logic stall,
    output logic flush_id_ex
);
    always_comb begin
        if (!mem_stall && ex_mem_read &&
                ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall = 1'b1;
            flush_id_ex = 1'b1;
        end else begin
            stall = 1'b0;
            flush_id_ex = 1'b0;
        end
    end

endmodule