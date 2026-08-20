 // direct-mapped I-cache with a combinational hit path
module instr_cache #(
    parameter NUM_SETS       = 64,
    parameter WORDS_PER_LINE = 4,
    parameter ADDR_BITS      = 32
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic[31:0] cpu_addr,
    input  logic       cpu_req,
    output logic[31:0] cpu_rdata,
    output logic       cache_ready,
    output logic[31:0] mem_addr,
    output logic       mem_req,
    input  logic[31:0] mem_rdata,
    input  logic       mem_ready
);
    localparam OFFSET_BITS = $clog2(WORDS_PER_LINE);
    localparam INDEX_BITS  = $clog2(NUM_SETS);
    localparam BYTE_BITS   = 2;
    localparam TAG_BITS    = ADDR_BITS - INDEX_BITS - OFFSET_BITS - BYTE_BITS;

    (* ram_style = "distributed" *) logic[31:0] cache_ram [0:NUM_SETS*WORDS_PER_LINE-1];
    (* ram_style = "distributed" *) logic[TAG_BITS-1:0] tag_ram [0:NUM_SETS-1];
    logic valid_ram [0:NUM_SETS-1];

    logic[TAG_BITS-1:0]    addr_tag;
    logic[INDEX_BITS-1:0]  addr_index;
    logic[OFFSET_BITS-1:0] addr_offset;

    assign addr_tag    = cpu_addr[ADDR_BITS-1:INDEX_BITS+OFFSET_BITS+BYTE_BITS];
    assign addr_index  = cpu_addr[INDEX_BITS+OFFSET_BITS+BYTE_BITS-1:OFFSET_BITS+BYTE_BITS];
    assign addr_offset = cpu_addr[OFFSET_BITS+BYTE_BITS-1:BYTE_BITS];

    typedef enum logic [1:0] {
        IDLE   = 2'd0,
        REFILL = 2'd1
    } cache_state;

    cache_state state;
    logic[OFFSET_BITS-1:0] refill_count;

    logic[TAG_BITS-1:0]   miss_tag;
    logic[INDEX_BITS-1:0] miss_index;

    logic hit;
    assign hit = valid_ram[addr_index] && (tag_ram[addr_index] == addr_tag);

    // combinational hit path
    assign cache_ready = (state == IDLE) && cpu_req && hit;
    assign cpu_rdata   = cache_ram[{addr_index, addr_offset}];

    // memory side
    assign mem_req  = (state == REFILL);
    assign mem_addr = {miss_tag, miss_index, refill_count, 2'b00};

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state        <= IDLE;
            refill_count <= '0;
            miss_tag     <= '0;
            miss_index   <= '0;
            for (int i = 0; i < NUM_SETS; i++)
                valid_ram[i] <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req && !hit) begin
                        miss_tag     <= addr_tag;
                        miss_index   <= addr_index;
                        refill_count <= '0;
                        // invalidate before refill so partial lines never hit
                        valid_ram[addr_index] <= 1'b0;
                        state        <= REFILL;
                    end
                end
                REFILL: begin
                    if (mem_ready) begin
                        cache_ram[{miss_index, refill_count}] <= mem_rdata;
                        if (refill_count == OFFSET_BITS'(WORDS_PER_LINE-1)) begin
                            tag_ram[miss_index]   <= miss_tag;
                            valid_ram[miss_index] <= 1'b1;
                            state                 <= IDLE;
                        end else begin
                            refill_count <= refill_count + 1'b1;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule