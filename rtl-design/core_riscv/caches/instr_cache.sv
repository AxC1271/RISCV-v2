`timescale 1ns / 1ps

// 1kB direct-mapped instruction cache
// 64 lines x 4 words/line x 4 bytes/word

module instr_cache # (
    parameter DEPTH = 256
)(
    input logic clk,
    input logic rst_n,

    // cpu interface
    input logic [31:0] cpu_addr,
    input logic cpu_req,
    output logic [31:0] cpu_rdata,
    output logic cpu_ready,

    // memory interface
    output logic [31:0] mem_addr,
    output logic mem_req,
    input logic [31:0] mem_rdata,
    input logic mem_ready
);

    logic [21:0] tag_ram   [0:63];
    logic valid_ram [0:63];
    logic [31:0] cache_ram [0:63][0:3];

    logic [21:0] addr_tag;
    logic [5:0] addr_index;
    logic [1:0] addr_offset;

    assign addr_tag = cpu_addr[31:10];
    assign addr_index = cpu_addr[9:4];
    assign addr_offset = cpu_addr[3:2];

    logic [21:0] miss_tag;
    logic [5:0] miss_index;
    logic [1:0] miss_offset;

    logic hit;
    assign hit = valid_ram[addr_index] &&
                 (tag_ram[addr_index] == addr_tag);

    typedef enum logic [1:0] {
        IDLE   = 2'd0,
        REFILL = 2'd1,
        DONE   = 2'd2
    } state_t;

    state_t state;
    logic [1:0] refill_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            refill_count <= 2'd0;
            miss_tag <= '0;
            miss_index <= '0;
            miss_offset <= '0;
            for (int i = 0; i < 64; i++)
                valid_ram[i] <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req && !hit) begin
                        miss_tag <= addr_tag;
                        miss_index <= addr_index;
                        miss_offset <= addr_offset;
                        refill_count <= 2'd0;
                        state <= REFILL;
                    end
                end
                REFILL: begin
                    if (mem_ready) begin
                        cache_ram[miss_index][refill_count] <= mem_rdata;

                        if (refill_count == 2'd3) begin
                            tag_ram[miss_index] <= miss_tag;
                            valid_ram[miss_index] <= 1'b1;
                            state <= DONE;
                        end else begin
                            refill_count <= refill_count + 2'd1;
                        end
                    end
                end
                DONE: begin
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    assign mem_req  = (state == REFILL);
    assign mem_addr = {miss_tag, miss_index, refill_count, 2'b00};

    logic [31:0] cpu_rdata_r;
    logic        cpu_ready_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rdata_r <= '0;
            cpu_ready_r <= 1'b0;
        end else begin
            cpu_ready_r <= 1'b0; // default: deassert every cycle
            case (state)
                IDLE: begin
                    if (cpu_req && hit) begin
                        cpu_rdata_r <= cache_ram[addr_index][addr_offset];
                        cpu_ready_r <= 1'b1;
                    end
                end
                DONE: begin
                    cpu_rdata_r <= cache_ram[miss_index][miss_offset];
                    cpu_ready_r <= 1'b1;
                end
                default: ;
            endcase
        end
    end
    assign cpu_rdata = cpu_rdata_r;
    assign cpu_ready = cpu_ready_r;
endmodule