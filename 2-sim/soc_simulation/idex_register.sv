module idex_register (
    input  logic clk,
    input  logic rst_n,
    input  logic stall,
    input  logic flush,

    input  logic[31:0] id_pc,
    input  logic[31:0] id_instr,
    input  logic[31:0] id_rs1_data,
    input  logic[31:0] id_rs2_data,
    input  logic[31:0] id_imm,
    input  logic[4:0]  id_rs1,
    input  logic[4:0]  id_rs2,
    input  logic[4:0]  id_rd,
    input  logic[3:0]  id_alu_opcode,
    input  logic[1:0]  id_op_a_sel,
    input  logic       id_alusrc,
    input  logic       id_memread,
    input  logic       id_memwrite,
    input  logic       id_memtoreg,
    input  logic       id_regwrite,
    input  logic       id_branch,
    input  logic       id_jump,
    input  logic       id_jalr,
    input  logic       id_ebreak,

    output logic[31:0] ex_pc,
    output logic[31:0] ex_instr,
    output logic[31:0] ex_rs1_data,
    output logic[31:0] ex_rs2_data,
    output logic[31:0] ex_imm,
    output logic[4:0]  ex_rs1,
    output logic[4:0]  ex_rs2,
    output logic[4:0]  ex_rd,
    output logic[3:0]  ex_alu_opcode,
    output logic[1:0]  ex_op_a_sel,
    output logic       ex_alusrc,
    output logic       ex_memread,
    output logic       ex_memwrite,
    output logic       ex_memtoreg,
    output logic       ex_regwrite,
    output logic       ex_branch,
    output logic       ex_jump,
    output logic       ex_jalr,
    output logic       ex_ebreak
);

    always_ff @(posedge clk) begin
        if (!rst_n || flush) begin
            ex_pc         <= 32'b0;
            ex_instr      <= 32'h00000013;
            ex_rs1_data   <= 32'b0;
            ex_rs2_data   <= 32'b0;
            ex_imm        <= 32'b0;
            ex_rs1        <= 5'b0;
            ex_rs2        <= 5'b0;
            ex_rd         <= 5'b0;
            ex_alu_opcode <= 4'b0;
            ex_op_a_sel   <= 2'b0;
            ex_alusrc     <= 1'b0;
            ex_memread    <= 1'b0;
            ex_memwrite   <= 1'b0;
            ex_memtoreg   <= 1'b0;
            ex_regwrite   <= 1'b0;
            ex_branch     <= 1'b0;
            ex_jump       <= 1'b0;
            ex_jalr       <= 1'b0;
            ex_ebreak     <= 1'b0;
        end else if (stall) begin
            // hold
        end else begin
            ex_pc         <= id_pc;
            ex_instr      <= id_instr;
            ex_rs1_data   <= id_rs1_data;
            ex_rs2_data   <= id_rs2_data;
            ex_imm        <= id_imm;
            ex_rs1        <= id_rs1;
            ex_rs2        <= id_rs2;
            ex_rd         <= id_rd;
            ex_alu_opcode <= id_alu_opcode;
            ex_op_a_sel   <= id_op_a_sel;
            ex_alusrc     <= id_alusrc;
            ex_memread    <= id_memread;
            ex_memwrite   <= id_memwrite;
            ex_memtoreg   <= id_memtoreg;
            ex_regwrite   <= id_regwrite;
            ex_branch     <= id_branch;
            ex_jump       <= id_jump;
            ex_jalr       <= id_jalr;
            ex_ebreak     <= id_ebreak;
        end
    end

endmodule