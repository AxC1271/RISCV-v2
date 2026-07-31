// 2-way set-associative write-back D-cache with a combinational hit path
// and byte write strobes (wstrb) for SB/SH support.

module data_cache #(
    parameter CACHE_SIZE = 4096,
    parameter BLOCK_SIZE = 16,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_WAYS   = 2     // hit/replace logic assumes 2
)(
    input  logic clk,
    input  logic rst_n,

    input  logic[ADDR_WIDTH-1:0] addr,
    input  logic[DATA_WIDTH-1:0] wr_data,
    input  logic[3:0]            wstrb,    // byte lane enables for writes
    input  logic rd_en,
    input  logic wr_en,

    output logic[DATA_WIDTH-1:0] rd_data,
    output logic                 cache_ready,

    output logic[ADDR_WIDTH-1:0] mem_addr,
    output logic[DATA_WIDTH-1:0] mem_wr_data,
    output logic mem_rd_en,
    output logic mem_wr_en,
    input  logic[DATA_WIDTH-1:0] mem_rd_data,
    input  logic mem_ready
);

    localparam BLOCK_WORDS    = BLOCK_SIZE / 4;
    localparam TOTAL_BLOCKS   = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS       = TOTAL_BLOCKS / NUM_WAYS;
    localparam SET_INDEX_BITS = $clog2(NUM_SETS);
    localparam OFFSET_BITS    = $clog2(BLOCK_SIZE);
    localparam WORD_OFF_BITS  = $clog2(BLOCK_WORDS);
    localparam TAG_BITS       = ADDR_WIDTH - SET_INDEX_BITS - OFFSET_BITS;
    localparam IDX_BITS       = SET_INDEX_BITS + 1 + WORD_OFF_BITS; // {set, way, word}

    logic[TAG_BITS-1:0]       tag;
    logic[SET_INDEX_BITS-1:0] set_index;
    logic[WORD_OFF_BITS-1:0]  word_offset;

    assign tag         = addr[ADDR_WIDTH-1 : SET_INDEX_BITS+OFFSET_BITS];
    assign set_index   = addr[SET_INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    assign word_offset = addr[OFFSET_BITS-1 : 2];

    (* ram_style = "distributed" *) logic[7:0] data_p0 [0:NUM_SETS*2*BLOCK_WORDS-1];
    (* ram_style = "distributed" *) logic[7:0] data_p1 [0:NUM_SETS*2*BLOCK_WORDS-1];
    (* ram_style = "distributed" *) logic[7:0] data_p2 [0:NUM_SETS*2*BLOCK_WORDS-1];
    (* ram_style = "distributed" *) logic[7:0] data_p3 [0:NUM_SETS*2*BLOCK_WORDS-1];

    (* ram_style = "distributed" *) logic[TAG_BITS-1:0] tag_w0 [0:NUM_SETS-1];
    (* ram_style = "distributed" *) logic[TAG_BITS-1:0] tag_w1 [0:NUM_SETS-1];

    logic valid_array [0:NUM_SETS-1][0:1];
    logic dirty_array [0:NUM_SETS-1][0:1];
    logic lru_array   [0:NUM_SETS-1];

    logic hit_way0, hit_way1, hit, hit_way;
    assign hit_way0 = valid_array[set_index][0] && (tag_w0[set_index] == tag);
    assign hit_way1 = valid_array[set_index][1] && (tag_w1[set_index] == tag);
    assign hit      = hit_way0 || hit_way1;
    assign hit_way  = hit_way1;

    logic replace_way;
    always_comb begin
        if (!valid_array[set_index][0])      replace_way = 1'b0;
        else if (!valid_array[set_index][1]) replace_way = 1'b1;
        else                                 replace_way = lru_array[set_index];
    end

    typedef enum logic [1:0] {
        IDLE      = 2'd0,
        WRITEBACK = 2'd1,
        ALLOCATE  = 2'd2
    } state_t;

    state_t state;
    logic[WORD_OFF_BITS-1:0]  word_counter;
    logic                     current_way;
    logic[TAG_BITS-1:0]       miss_tag;
    logic[SET_INDEX_BITS-1:0] miss_set;
    logic[TAG_BITS-1:0]       wb_tag;      // victim tag, captured at miss

    logic [IDX_BITS-1:0] rd_idx;
    assign rd_idx = (state == WRITEBACK)
                  ? {miss_set,  current_way, word_counter}
                  : {set_index, hit_way,     word_offset};

    logic [31:0] array_rdata;
    assign array_rdata = {data_p3[rd_idx], data_p2[rd_idx],
                          data_p1[rd_idx], data_p0[rd_idx]};

    // combinational hit path (CPU side)
    assign cache_ready = (state == IDLE) && (rd_en || wr_en) && hit;
    assign rd_data     = array_rdata;

    // memory side
    always_comb begin
        mem_rd_en   = 1'b0;
        mem_wr_en   = 1'b0;
        mem_addr    = '0;
        mem_wr_data = '0;
        case (state)
            WRITEBACK: begin
                mem_wr_en   = 1'b1;
                mem_addr    = {wb_tag, miss_set, word_counter, 2'b00};
                mem_wr_data = array_rdata;
            end
            ALLOCATE: begin
                mem_rd_en = 1'b1;
                mem_addr  = {miss_tag, miss_set, word_counter, 2'b00};
            end
            default: ;
        endcase
    end

    logic [IDX_BITS-1:0] wr_idx;
    logic [31:0]         wr_word;
    logic [3:0]          wr_lane_en;

    always_comb begin
        if (state == ALLOCATE && mem_ready) begin
            wr_idx     = {miss_set, current_way, word_counter};
            wr_word    = mem_rd_data;
            wr_lane_en = 4'b1111;
        end else if (state == IDLE && wr_en && hit) begin
            wr_idx     = {set_index, hit_way, word_offset};
            wr_word    = wr_data;
            wr_lane_en = wstrb;
        end else begin
            wr_idx     = '0;
            wr_word    = '0;
            wr_lane_en = 4'b0000;
        end
    end

    always_ff @(posedge clk) begin
        if (wr_lane_en[0]) data_p0[wr_idx] <= wr_word[7:0];
        if (wr_lane_en[1]) data_p1[wr_idx] <= wr_word[15:8];
        if (wr_lane_en[2]) data_p2[wr_idx] <= wr_word[23:16];
        if (wr_lane_en[3]) data_p3[wr_idx] <= wr_word[31:24];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state        <= IDLE;
            word_counter <= '0;
            current_way  <= 1'b0;
            miss_tag     <= '0;
            miss_set     <= '0;
            wb_tag       <= '0;
            for (int i = 0; i < NUM_SETS; i++) begin
                lru_array[i] <= 1'b0;
                valid_array[i][0] <= 1'b0;
                valid_array[i][1] <= 1'b0;
                dirty_array[i][0] <= 1'b0;
                dirty_array[i][1] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (rd_en || wr_en) begin
                        if (hit) begin
                            if (wr_en)
                                dirty_array[set_index][hit_way] <= 1'b1;
                            lru_array[set_index] <= ~hit_way;
                        end else begin
                            current_way  <= replace_way;
                            miss_tag     <= tag;
                            miss_set     <= set_index;
                            wb_tag       <= replace_way ? tag_w1[set_index]
                                                        : tag_w0[set_index];
                            word_counter <= '0;
                            if (valid_array[set_index][replace_way] &&
                                dirty_array[set_index][replace_way])
                                state <= WRITEBACK;
                            else
                                state <= ALLOCATE;
                        end
                    end
                end
                WRITEBACK: begin
                    if (mem_ready) begin
                        if (word_counter == WORD_OFF_BITS'(BLOCK_WORDS-1)) begin
                            dirty_array[miss_set][current_way] <= 1'b0;
                            word_counter <= '0;
                            state        <= ALLOCATE;
                        end else begin
                            word_counter <= word_counter + 1'b1;
                        end
                    end
                end
                ALLOCATE: begin
                    if (mem_ready) begin
                        if (word_counter == WORD_OFF_BITS'(BLOCK_WORDS-1)) begin
                            if (current_way) tag_w1[miss_set] <= miss_tag;
                            else             tag_w0[miss_set] <= miss_tag;
                            valid_array[miss_set][current_way] <= 1'b1;
                            dirty_array[miss_set][current_way] <= 1'b0;
                            lru_array[miss_set]                <= ~current_way;
                            state                              <= IDLE;
                        end else begin
                            word_counter <= word_counter + 1'b1;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule