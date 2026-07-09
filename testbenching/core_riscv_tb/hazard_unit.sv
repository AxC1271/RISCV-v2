module hazard_unit (
    input  logic [4:0] id_rs1,
    input  logic [4:0] id_rs2,
    input  logic [4:0] ex_rd,
    input  logic ex_memread,
    output logic stall,
    output logic insert_bubble
);

    always_comb begin
        stall         = 1'b0;
        insert_bubble = 1'b0;

        if (ex_memread && ex_rd != 5'b00000 && (ex_rd == id_rs1 || ex_rd == id_rs2)) begin
            stall         = 1'b1;
            insert_bubble = 1'b1;
        end
        
    end

endmodule