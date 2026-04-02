`timescale 1ns / 1ps

module forward_unit (
    // curr instruction in ex stage
    input logic [4:0] ex_rs1,        
    input logic [4:0] ex_rs2,        
    
    // curr instruction in mem stage
    input logic [4:0] mem_rd,       
    input logic mem_reg_write,       
    
    // instruction in WB stage
    input logic [4:0] wb_rd,         
    input logic wb_reg_write,       
    
    output logic [1:0] forward_a, // forward for rs1
    output logic [1:0] forward_b  // forward for rs2
);

    // forward A (for rs1)
    always_comb begin
        // priority: mem > wb > none
        
        // mem hazard (most recent)
        if (mem_reg_write && (mem_rd != 0) && (mem_rd == ex_rs1)) begin
            forward_a = 2'b10;  // forward from mem stage
        end
        // writeback hazard (less recent)
        else if (wb_reg_write && (wb_rd != 0) && (wb_rd == ex_rs1)) begin
            forward_a = 2'b01;  // forward from wb stage
        end
        // no hazard
        else begin
            forward_a = 2'b00;  // no forwarding
        end
    end
    
    // forward B (for rs2)
    always_comb begin
        if (mem_reg_write && (mem_rd != 0) && (mem_rd == ex_rs2)) begin
            forward_b = 2'b10;
        end
        else if (wb_reg_write && (wb_rd != 0) && (wb_rd == ex_rs2)) begin
            forward_b = 2'b01;
        end
        else begin
            forward_b = 2'b00;
        end
    end

endmodule