`timescale 1ns / 1ps

module hazard_unit (
    // instruction in decode stage
    input  logic [4:0] id_rs1,
    input  logic [4:0] id_rs2,
    
    // instruction in execution stage
    input  logic [4:0] ex_rd,
    input  logic       ex_mem_read,  // check if load instr
    
    // control signals
    output logic       stall,        // stall fetch and decode stages
    output logic       flush_id_ex   // flush ID/EX register (insert bubble)
);

    always_comb begin
        if (ex_mem_read && ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall = 1'b1;        // stall pipeline
            flush_id_ex = 1'b1;  
        end else begin
            stall = 1'b0;
            flush_id_ex = 1'b0;
        end
    end

endmodule