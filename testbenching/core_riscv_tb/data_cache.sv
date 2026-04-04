`timescale 1ns / 1ps

// 4kB 2-way set associative write-back / write-allocate data cache

module data_cache # (
    parameter CACHE_SIZE = 4096,
    parameter BLOCK_SIZE = 16,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_WAYS = 2
)(
    input logic clk,
    input logic rst_n,

    // cpu interface
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic rd_en,
    input logic wr_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic ready,

    // memory interface (combinational outputs)
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wr_data,
    output logic mem_rd_en,
    output logic mem_wr_en,
    input logic [DATA_WIDTH-1:0] mem_rd_data,
    input logic mem_ready
);

    localparam BLOCK_WORDS    = BLOCK_SIZE / 4;
    localparam TOTAL_BLOCKS   = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS       = TOTAL_BLOCKS / NUM_WAYS;
    localparam SET_INDEX_BITS = $clog2(NUM_SETS);
    localparam OFFSET_BITS    = $clog2(BLOCK_SIZE);
    localparam WORD_OFF_BITS  = $clog2(BLOCK_WORDS);
    localparam TAG_BITS       = ADDR_WIDTH - SET_INDEX_BITS - OFFSET_BITS;

    // address decode (combinational)
    logic [TAG_BITS-1:0] tag;
    logic [SET_INDEX_BITS-1:0] set_index;
    logic [WORD_OFF_BITS-1:0] word_offset;

    assign tag = addr[ADDR_WIDTH-1 : SET_INDEX_BITS+OFFSET_BITS];
    assign set_index = addr[SET_INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    assign word_offset = addr[OFFSET_BITS-1 : 2];

    // latched request (stable throughout miss/refill)
    logic [TAG_BITS-1:0] miss_tag;
    logic [SET_INDEX_BITS-1:0] miss_set;
    logic [WORD_OFF_BITS-1:0] miss_word_offset;
    logic miss_wr_en;
    logic [DATA_WIDTH-1:0] miss_wr_data;

    // actual cache storage arrays
    logic [DATA_WIDTH-1:0] data_array [NUM_SETS-1:0][NUM_WAYS-1:0][BLOCK_WORDS-1:0];
    logic [TAG_BITS-1:0] tag_array [NUM_SETS-1:0][NUM_WAYS-1:0];
    logic valid_array [NUM_SETS-1:0][NUM_WAYS-1:0];
    logic dirty_array [NUM_SETS-1:0][NUM_WAYS-1:0];
    logic lru_array [NUM_SETS-1:0];

    // hit detection (combinational, uses live address)
    logic hit_way0, hit_way1, hit;
    logic hit_way;

    assign hit_way0 = valid_array[set_index][0] && (tag_array[set_index][0] == tag);
    assign hit_way1 = valid_array[set_index][1] && (tag_array[set_index][1] == tag);
    assign hit = hit_way0 || hit_way1;
    assign hit_way = hit_way1 ? 1'b1 : 1'b0;

    // determine replacement way combinationally
    logic replace_way;
    always_comb begin
        if (!valid_array[set_index][0]) replace_way = 1'b0;
        else if (!valid_array[set_index][1]) replace_way = 1'b1;
        else replace_way = lru_array[set_index];
    end

    // finite state machine definition (registered)
    typedef enum logic [1:0] {
        IDLE = 2'd0,
        WRITE_BACK = 2'd1,
        ALLOCATE = 2'd2,
        DONE = 2'd3
    } state_t;

    state_t state;
    logic [WORD_OFF_BITS-1:0] word_counter;
    logic current_way;

    // shadow register: mirrors every word written to data_array during refill
    logic [DATA_WIDTH-1:0] refill_data [BLOCK_WORDS-1:0];

    always_comb begin
        mem_rd_en = 1'b0;
        mem_wr_en = 1'b0;
        mem_addr = '0;
        mem_wr_data = '0;

        case (state)
            WRITE_BACK: begin
                mem_wr_en = 1'b1;
                mem_addr = {tag_array[miss_set][current_way],
                               miss_set, word_counter, 2'b00};
                mem_wr_data = data_array[miss_set][current_way][word_counter];
            end
            ALLOCATE: begin
                mem_rd_en = 1'b1;
                mem_addr  = {miss_tag, miss_set, word_counter, 2'b00};
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            rd_data <= '0;
            word_counter <= '0;
            current_way <= 1'b0;
            miss_tag <= '0;
            miss_set <= '0;
            miss_word_offset <= '0;
            miss_wr_en <= 1'b0;
            miss_wr_data <= '0;

            for (int i = 0; i < BLOCK_WORDS; i++)
                refill_data[i] <= '0;

            for (int i = 0; i < NUM_SETS; i++) begin
                lru_array[i] <= 1'b0;
                for (int j = 0; j < NUM_WAYS; j++) begin
                    valid_array[i][j] <= 1'b0;
                    dirty_array[i][j] <= 1'b0;
                end
            end

        end else begin
            ready <= 1'b0; // default

            case (state)
                IDLE: begin
                    if (rd_en || wr_en) begin
                        if (hit) begin
                            if (wr_en) begin
                                data_array[set_index][hit_way][word_offset] <= wr_data;
                                dirty_array[set_index][hit_way] <= 1'b1;
                            end

                            rd_data <= wr_en ? wr_data
                                             : data_array[set_index][hit_way][word_offset];

                            lru_array[set_index] <= ~hit_way;
                            state <= DONE;

                        end else begin
                            // miss -- latch request, choose victim
                            current_way <= replace_way;
                            miss_tag <= tag;
                            miss_set <= set_index;
                            miss_word_offset <= word_offset;
                            miss_wr_en <= wr_en;
                            miss_wr_data <= wr_data;
                            word_counter <= '0;

                            if (valid_array[set_index][replace_way] &&
                                dirty_array[set_index][replace_way])
                                state <= WRITE_BACK;
                            else
                                state <= ALLOCATE;
                        end
                    end
                end
                WRITE_BACK: begin
                    if (mem_ready) begin
                        if (word_counter == WORD_OFF_BITS'(BLOCK_WORDS - 1)) begin
                            dirty_array[miss_set][current_way] <= 1'b0;
                            word_counter <= '0;
                            state <= ALLOCATE;
                        end else begin
                            word_counter <= word_counter + 1'b1;
                        end
                    end
                end
                ALLOCATE: begin
                    if (mem_ready) begin
                        if (miss_wr_en && (word_counter == miss_word_offset)) begin
                            data_array[miss_set][current_way][word_counter] <= miss_wr_data;
                            refill_data[word_counter] <= miss_wr_data;
                        end else begin
                            data_array[miss_set][current_way][word_counter] <= mem_rd_data;
                            refill_data[word_counter] <= mem_rd_data;
                        end
                        if (word_counter == WORD_OFF_BITS'(BLOCK_WORDS - 1)) begin
                            tag_array[miss_set][current_way] <= miss_tag;
                            valid_array[miss_set][current_way] <= 1'b1;
                            dirty_array[miss_set][current_way] <= miss_wr_en;

                            if (miss_wr_en)
                                rd_data <= miss_wr_data;
                            else if (word_counter == miss_word_offset)
                                rd_data <= mem_rd_data;
                            else
                                rd_data <= refill_data[miss_word_offset];
                            lru_array[miss_set] <= ~current_way;
                            state <= DONE;
                        end else begin
                            word_counter <= word_counter + 1'b1;
                        end
                    end
                end
                DONE: begin
                    ready <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule