module hazard_unit (
    // load-use detection
    input  logic [4:0] id_rs1,      // zeroed by decode when unused
    input  logic [4:0] id_rs2,
    input  logic [4:0] ex_rd,
    input  logic       ex_memread,

    // control transfer resolved in EX
    input  logic       redirect,

    // memory readiness
    input  logic       fetch_ready,   // I-cache hit this cycle
    input  logic       mem_access,    // MEM stage has a load/store
    input  logic       mem_ready,     // D-cache done this cycle

    input  logic       run,           // cpu_enable && !halted

    // status (also useful for waves / formal)
    output logic       load_use_stall,
    output logic       mem_stall,
    output logic       fetch_stall,

    // pipeline register control
    output logic       pc_write,
    output logic       ifid_stall,
    output logic       ifid_flush,
    output logic       idex_stall,
    output logic       idex_flush,
    output logic       exmem_stall,
    output logic       memwb_stall
);

    always_comb begin
        load_use_stall = ex_memread && (ex_rd != 5'b00000) &&
                         ((ex_rd == id_rs1) || (ex_rd == id_rs2));
        mem_stall      = mem_access && !mem_ready;
        fetch_stall    = !fetch_ready;

        // global freeze: D-cache miss or core disabled/halted
        if (mem_stall || !run) begin
            pc_write    = 1'b0;
            ifid_stall  = 1'b1;
            ifid_flush  = 1'b0;
            idex_stall  = 1'b1;
            idex_flush  = 1'b0;
            exmem_stall = 1'b1;
            memwb_stall = 1'b1;
        end else begin
            // EX/MEM and MEM/WB always advance outside a global freeze --
            // stalling them while ID/EX advances is how instructions get
            // executed twice.
            exmem_stall = 1'b0;
            memwb_stall = 1'b0;

            if (redirect) begin
                // squash the two wrong-path instructions behind the branch
                pc_write   = 1'b1;
                ifid_stall = 1'b0;
                ifid_flush = 1'b1;
                idex_stall = 1'b0;
                idex_flush = 1'b1;
            end else if (load_use_stall) begin
                // hold the consumer in ID, bubble into EX
                pc_write   = 1'b0;
                ifid_stall = 1'b1;
                ifid_flush = 1'b0;
                idex_stall = 1'b0;
                idex_flush = 1'b1;
            end else if (fetch_stall) begin
                // nothing valid to latch: bubble into ID, hold PC
                pc_write   = 1'b0;
                ifid_stall = 1'b0;
                ifid_flush = 1'b1;
                idex_stall = 1'b0;
                idex_flush = 1'b0;
            end else begin
                pc_write   = 1'b1;
                ifid_stall = 1'b0;
                ifid_flush = 1'b0;
                idex_stall = 1'b0;
                idex_flush = 1'b0;
            end
        end
    end

endmodule