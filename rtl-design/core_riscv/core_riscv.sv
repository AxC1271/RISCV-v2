`timescale 1ns / 1ps

// this is just the RISC-V core,
// not the entire integrated system
module core_riscv (
    // top level signals
    input logic clk,
    input logic rst_n,

    // write port to the instr_memory
    input logic[31:0] instr,
    input logic instrmem_write,

    // define external ports for 
    // memory mapped I/O later
);

// instantiate necessary signals here

    // program counter
    logic [31:0] pc_in, pc_out;

    // instruction memory
    logic [31:0] curr_instr;

    // control unit
    logic RegWrite,
    logic MemRead,
    logic MemWrite,
    logic BranchEq,
    logic MemToReg,
    logic ALUSrc,
    logic ALUCont,
    logic JMP


// instantiate modules here
    program_counter pc (
        .clk(clk),
        .rst_n(rst_n)
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    instr_memory im (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(),
        .wr_instr(),

        // pass in pc pointer
        .pc_in(pc_out),
        .instr(curr_instr)
    );

    instr_cache instr_cache (
        .clk(clk),
        .rst_(rst_n),
        .cpu_addr(),
        .cpu_req(),
        .cpu_rdata(),
        .cpu_ready(),
        .mem_addr(),
        .mem_req(),
        .mem_rdata(),
        .mem_ready()
    );

    register_file rf (
        .clk(clk),
        .rst_n(rst_n),

        // derived from instr_memory
        .rd_addr1(curr_instr[19:15]),
        .rd_addr2(curr_instr[24:20]),

        .wr_addr(curr_instr[11:7]),
        .wr_data(),
        .wr_en(),

        .rd_data1(),
        .rd_data2(),

    );

    control_unit cu (
        .opcode(curr_instr[6:0]),
        .funct3(curr_instr[14:12]),
        .funct6(curr_instr[31:25]),
        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .BranchEq(BranchEq),
        .MemToReg(MemToReg),
        .ALUSrc(ALUSrc),
        .ALUCont(ALUCont),
        .JMP(JMP)
    );

    arith_logic_unit alu (
        .a(),
        .b(),
        .opcode(),
        .res(),
        .zero_flag()
    );

    data_memory dm (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(),
        .wr_data()
    );

    data_cache data_cache (
        .clk(clk),
        .rst_n(rst_n),
        .addr(),
        .wr_data(),
        .rd_en(),
        .wr_en(),
        .rd_data(),
        .ready(),
        .mem_addr(),
        .mem_wr_data(),
        .mem_rd_en(),
        .mem_wr_en(),
        .mem_rd_data(),
        .mem_ready()
    );

    ifid_register ifid (
        .clk(clk),
        .rst_n(rst_n),
        .stall(),
        .flush(),
        .if_pc(),
        .if_instruction(),
        .id_pc(),
        .id_instruction()
    );

    idex_register idex (
`       .clk(clk),
        .rst_n(rst_n),
        .flush(),
        .id_pc(),
        .id_rs1_data(),
        .id_rs2_data(),
        .id_immediate(),
        .id_rs1(),
        .id_rs2(),
        .id_rd(),
        .id_alu_op(),
        .id_alu_src(),
        .id_mem_read(),
        .id_mem_write(),
        .id_reg_write(),
        .id_mem_to_reg(),
        .ex_pc(),
        .ex_rs1_data(),
        .ex_rs2_data(),
        .ex_immediate(),
        .ex_rs1(),
        .ex_rs2(),
        .ex_rd(),
        .ex_alu_op(),
        .ex_alu_src(),
        .ex_mem_read(),
        .ex_mem_write(),
        .ex_reg_write(),
        .ex_mem_to_reg()
    )

    exmem_register exmem (
        .clk(),
        .rst_n(),
        .ex_alu_result(),
        .ex_rs2_data(),
        .ex_rd(),
        .ex_zero_flag()
    );

    memwb_register memwb (

    );

// instantiate processes here

    always_ff @ (posedge clk or negedge rst_n) begin
    end

endmodule