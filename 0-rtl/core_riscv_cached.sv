// 5-stage in-order RV32I core with Integrated I-Cache and D-Cache
// IF -> ID -> EX -> MEM -> WB
module core_riscv # (
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic clk,
    input  logic rst_n,
    input  logic cpu_enable,

    output logic [31:0] imem_addr,
    output logic        imem_req,
    input  logic [31:0] imem_rdata,
    input  logic        imem_ready,

    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_rd_en,
    output logic        dmem_wr_en,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_ready,

    output logic [31:0] debug_pc,
    output logic [31:0] debug_instr,
    output logic [31:0] debug_reg_data,
    output logic        debug_halted
);

    logic load_use_stall, mem_stall, fetch_stall;
    logic pc_write, ifid_stall, ifid_flush, idex_stall, idex_flush;
    logic exmem_stall, memwb_stall;
    logic redirect;
    logic [31:0] redirect_target;
    logic run;

    assign run = cpu_enable && !debug_halted;

    logic icache_ready;
    logic [31:0] icache_rdata;

    logic dcache_ready;
    logic [31:0] dcache_rdata;

    logic [31:0] pc_current, pc_next, pc_plus4;
    logic [31:0] if_instr;
    logic        if_valid;

    assign if_instr = icache_rdata;
    assign if_valid = run && icache_ready;

    assign pc_plus4 = pc_current + 32'd4;
    assign pc_next  = redirect ? redirect_target : pc_plus4;

    program_counter #(.RESET_VECTOR(RESET_VECTOR)) pc_reg (
        .clk      (clk),
        .rst_n    (rst_n),
        .pc_write (pc_write),
        .pc_in    (pc_next),
        .pc_out   (pc_current)
    );

    instr_cache #(
        .NUM_SETS       (64),
        .WORDS_PER_LINE (4),
        .ADDR_BITS      (32)
    ) icache (
        .clk         (clk),
        .rst_n       (rst_n),
        .cpu_addr    (pc_current),
        .cpu_req     (run),
        .cpu_rdata   (icache_rdata),
        .cache_ready (icache_ready),
        .mem_addr    (imem_addr),
        .mem_req     (imem_req),
        .mem_rdata   (imem_rdata),
        .mem_ready   (imem_ready)
    );

    logic [31:0] id_pc, id_instr;
    logic        id_valid;

    ifid_register ifid (
        .clk      (clk),
        .rst_n    (rst_n),
        .stall    (ifid_stall),
        .flush    (ifid_flush),
        .if_pc    (pc_current),
        .if_instr (if_instr),
        .if_valid (if_valid),
        .id_pc    (id_pc),
        .id_instr (id_instr),
        .id_valid (id_valid)
    );

    logic [3:0] id_alu_opcode;
    logic [1:0] id_op_a_sel;
    logic id_alusrc, id_regwrite, id_memread, id_memwrite;
    logic id_branch, id_memtoreg, id_jump, id_jalr;
    logic id_uses_rs1, id_uses_rs2, id_ebreak;

    control_unit ctrl (
        .instruction (id_instr),
        .alu_opcode  (id_alu_opcode),
        .op_a_sel    (id_op_a_sel),
        .alusrc      (id_alusrc),
        .regwrite    (id_regwrite),
        .memread     (id_memread),
        .memwrite    (id_memwrite),
        .branch      (id_branch),
        .memtoreg    (id_memtoreg),
        .jump        (id_jump),
        .jalr        (id_jalr),
        .uses_rs1    (id_uses_rs1),
        .uses_rs2    (id_uses_rs2),
        .ebreak      (id_ebreak)
    );

    logic [4:0] id_rs1, id_rs2, id_rd;
    assign id_rs1 = id_uses_rs1 ? id_instr[19:15] : 5'b0;
    assign id_rs2 = id_uses_rs2 ? id_instr[24:20] : 5'b0;
    assign id_rd  = id_instr[11:7];

    logic [31:0] id_rs1_data, id_rs2_data;
    logic [31:0] wb_result;
    logic [4:0]  wb_rd;
    logic        wb_regwrite;

    register_file rf (
        .clk       (clk),
        .rst_n     (rst_n),
        .rd_addr1  (id_rs1),
        .rd_addr2  (id_rs2),
        .rd_data1  (id_rs1_data),
        .rd_data2  (id_rs2_data),
        .wr_addr   (wb_rd),
        .wr_data   (wb_result),
        .reg_write (wb_regwrite)
    );

    logic [31:0] id_imm;
    immediate_generator immgen (
        .instr (id_instr),
        .imm   (id_imm)
    );

    logic [31:0] ex_pc, ex_instr, ex_rs1_data, ex_rs2_data, ex_imm;
    logic [4:0]  ex_rs1, ex_rs2, ex_rd;
    logic [3:0]  ex_alu_opcode;
    logic [1:0]  ex_op_a_sel;
    logic ex_alusrc, ex_memread, ex_memwrite, ex_memtoreg, ex_regwrite;
    logic ex_branch, ex_jump, ex_jalr, ex_ebreak;
    logic ex_valid;

    idex_register idex (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (idex_stall),
        .flush         (idex_flush),
        .id_pc         (id_pc),
        .id_instr      (id_instr),
        .id_rs1_data   (id_rs1_data),
        .id_rs2_data   (id_rs2_data),
        .id_imm        (id_imm),
        .id_rs1        (id_rs1),
        .id_rs2        (id_rs2),
        .id_rd         (id_rd),
        .id_alu_opcode (id_alu_opcode),
        .id_op_a_sel   (id_op_a_sel),
        .id_alusrc     (id_alusrc),
        .id_memread    (id_memread),
        .id_memwrite   (id_memwrite),
        .id_memtoreg   (id_memtoreg),
        .id_regwrite   (id_regwrite),
        .id_branch     (id_branch),
        .id_jump       (id_jump),
        .id_jalr       (id_jalr),
        .id_ebreak     (id_ebreak),
        .id_valid      (id_valid),
        .ex_pc         (ex_pc),
        .ex_instr      (ex_instr),
        .ex_rs1_data   (ex_rs1_data),
        .ex_rs2_data   (ex_rs2_data),
        .ex_imm        (ex_imm),
        .ex_rs1        (ex_rs1),
        .ex_rs2        (ex_rs2),
        .ex_rd         (ex_rd),
        .ex_alu_opcode (ex_alu_opcode),
        .ex_op_a_sel   (ex_op_a_sel),
        .ex_alusrc     (ex_alusrc),
        .ex_memread    (ex_memread),
        .ex_memwrite   (ex_memwrite),
        .ex_memtoreg   (ex_memtoreg),
        .ex_regwrite   (ex_regwrite),
        .ex_branch     (ex_branch),
        .ex_jump       (ex_jump),
        .ex_jalr       (ex_jalr),
        .ex_ebreak     (ex_ebreak),
        .ex_valid      (ex_valid)
    );

    logic [1:0] forward_a, forward_b;
    logic [31:0] mem_alu_result;
    logic [4:0]  mem_rd;
    logic        mem_regwrite;

    forward_unit fwd (
        .idex_rs1       (ex_rs1),
        .idex_rs2       (ex_rs2),
        .exmem_rd       (mem_rd),
        .exmem_regwrite (mem_regwrite),
        .memwb_rd       (wb_rd),
        .memwb_regwrite (wb_regwrite),
        .forward_a      (forward_a),
        .forward_b      (forward_b)
    );

    logic [31:0] rs1_fwd, rs2_fwd;
    always_comb begin
        case (forward_a)
            2'b10:   rs1_fwd = mem_alu_result;
            2'b01:   rs1_fwd = wb_result;
            default: rs1_fwd = ex_rs1_data;
        endcase
        case (forward_b)
            2'b10:   rs2_fwd = mem_alu_result;
            2'b01:   rs2_fwd = wb_result;
            default: rs2_fwd = ex_rs2_data;
        endcase
    end

    logic [31:0] alu_a, alu_b, alu_result;
    always_comb begin
        case (ex_op_a_sel)
            2'b01:   alu_a = ex_pc;
            2'b10:   alu_a = 32'b0;
            default: alu_a = rs1_fwd;
        endcase
    end
    assign alu_b = ex_alusrc ? ex_imm : rs2_fwd;

    alu ex_alu (
        .a          (alu_a),
        .b          (alu_b),
        .alu_opcode (ex_alu_opcode),
        .result     (alu_result)
    );

    logic        branch_taken;
    logic [31:0] branch_target;
    branch_unit bu (
        .rs1_data      (rs1_fwd),
        .rs2_data      (rs2_fwd),
        .branch        (ex_branch),
        .funct3        (ex_instr[14:12]),
        .pc            (ex_pc),
        .imm           (ex_imm),
        .branch_taken  (branch_taken),
        .branch_target (branch_target)
    );

    assign redirect        = ex_jump || branch_taken;
    assign redirect_target = ex_jalr ? {alu_result[31:1], 1'b0} : branch_target;

    logic [31:0] ex_result;
    assign ex_result = ex_jump ? ex_pc + 32'd4 : alu_result;

    logic [31:0] mem_store_data;
    logic [2:0]  mem_funct3;
    logic mem_memread, mem_memwrite, mem_memtoreg, mem_ebreak;
    logic mem_valid;

    exmem_register exmem (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (exmem_stall),
        .ex_result      (ex_result),
        .ex_store_data  (rs2_fwd),
        .ex_rd          (ex_rd),
        .ex_funct3      (ex_instr[14:12]),
        .ex_memread     (ex_memread),
        .ex_memwrite    (ex_memwrite),
        .ex_memtoreg    (ex_memtoreg),
        .ex_regwrite    (ex_regwrite),
        .ex_ebreak      (ex_ebreak),
        .ex_valid       (ex_valid),
        .mem_alu_result (mem_alu_result),
        .mem_store_data (mem_store_data),
        .mem_rd         (mem_rd),
        .mem_funct3     (mem_funct3),
        .mem_memread    (mem_memread),
        .mem_memwrite   (mem_memwrite),
        .mem_memtoreg   (mem_memtoreg),
        .mem_regwrite   (mem_regwrite),
        .mem_ebreak     (mem_ebreak),
        .mem_valid      (mem_valid)
    );

    logic [3:0]  store_wstrb;
    logic [31:0] store_wdata;
    always_comb begin
        case (mem_funct3[1:0])
            2'b00: begin // SB
                store_wdata = {4{mem_store_data[7:0]}};
                store_wstrb = 4'b0001 << mem_alu_result[1:0];
            end
            2'b01: begin // SH
                store_wdata = {2{mem_store_data[15:0]}};
                store_wstrb = mem_alu_result[1] ? 4'b1100 : 4'b0011;
            end
            default: begin // SW
                store_wdata = mem_store_data;
                store_wstrb = 4'b1111;
            end
        endcase
    end

    data_cache #(
        .CACHE_SIZE (4096),
        .BLOCK_SIZE (16),
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .NUM_WAYS   (2)
    ) dcache (
        .clk         (clk),
        .rst_n       (rst_n),
        .addr        (mem_alu_result),
        .wr_data     (store_wdata),
        .wstrb       (store_wstrb),
        .rd_en       (mem_memread),
        .wr_en       (mem_memwrite),
        .rd_data     (dcache_rdata),
        .cache_ready (dcache_ready),
        .mem_addr    (dmem_addr),
        .mem_wr_data (dmem_wdata),
        .mem_rd_en   (dmem_rd_en),
        .mem_wr_en   (dmem_wr_en),
        .mem_rd_data (dmem_rdata),
        .mem_ready   (dmem_ready)
    );

    logic [31:0] mem_load_data;
    logic [7:0]  load_byte;
    logic [15:0] load_half;

    always_comb begin
        load_byte = dcache_rdata[8*mem_alu_result[1:0] +: 8];
        load_half = mem_alu_result[1] ? dcache_rdata[31:16] : dcache_rdata[15:0];
        case (mem_funct3)
            3'b000:  mem_load_data = {{24{load_byte[7]}}, load_byte};   // LB
            3'b001:  mem_load_data = {{16{load_half[15]}}, load_half};  // LH
            3'b100:  mem_load_data = {24'b0, load_byte};                // LBU
            3'b101:  mem_load_data = {16'b0, load_half};                // LHU
            default: mem_load_data = dcache_rdata;                      // LW
        endcase
    end

    logic [31:0] wb_alu_result, wb_rdata;
    logic wb_memtoreg, wb_ebreak;
    logic wb_valid;

    memwb_register memwb (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (memwb_stall),
        .mem_alu_result (mem_alu_result),
        .mem_rdata      (mem_load_data),
        .mem_rd         (mem_rd),
        .mem_regwrite   (mem_regwrite),
        .mem_memtoreg   (mem_memtoreg),
        .mem_ebreak     (mem_ebreak),
        .mem_valid      (mem_valid),
        .wb_alu_result  (wb_alu_result),
        .wb_rdata       (wb_rdata),
        .wb_rd          (wb_rd),
        .wb_regwrite    (wb_regwrite),
        .wb_memtoreg    (wb_memtoreg),
        .wb_ebreak      (wb_ebreak),
        .wb_valid       (wb_valid)
    );

    assign wb_result = wb_memtoreg ? wb_rdata : wb_alu_result;


    hazard_unit hu (
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .ex_rd          (ex_rd),
        .ex_memread     (ex_memread),
        .redirect       (redirect),
        .fetch_ready    (icache_ready),
        .mem_access     (mem_memread || mem_memwrite),
        .mem_ready      (dcache_ready),
        .run            (run),
        .load_use_stall (load_use_stall),
        .mem_stall      (mem_stall),
        .fetch_stall    (fetch_stall),
        .pc_write       (pc_write),
        .ifid_stall     (ifid_stall),
        .ifid_flush     (ifid_flush),
        .idex_stall     (idex_stall),
        .idex_flush     (idex_flush),
        .exmem_stall    (exmem_stall),
        .memwb_stall    (memwb_stall)
    );

    assign debug_pc       = pc_current;
    assign debug_instr    = id_instr;
    assign debug_reg_data = wb_result;

    always_ff @(posedge clk) begin
        if (!rst_n)
            debug_halted <= 1'b0;
        else if (wb_ebreak)
            debug_halted <= 1'b1;
    end

endmodule