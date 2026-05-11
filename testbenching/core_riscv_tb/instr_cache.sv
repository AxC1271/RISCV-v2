`timescale 1ns / 1ps
module instr_cache # (
    parameter DEPTH = 256
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] cpu_addr,
    input  logic        cpu_req,
    input logic         mem_stall,
    output logic [31:0] cpu_rdata,
    output logic        cpu_ready,
    output logic [31:0] mem_addr,
    output logic        mem_req,
    input  logic [31:0] mem_rdata,
    input  logic        mem_ready
);
    logic [21:0] tag_ram   [0:63];
    logic        valid_ram [0:63];
    logic [31:0] cache_ram [0:63][0:3];
    logic [21:0] addr_tag;
    logic [5:0]  addr_index;
    logic [1:0]  addr_offset;
    assign addr_tag    = cpu_addr[31:10];
    assign addr_index  = cpu_addr[9:4];
    assign addr_offset = cpu_addr[3:2];
    logic [21:0] miss_tag;
    logic [5:0]  miss_index;
    logic [1:0]  miss_offset;
    logic hit;
    assign hit = valid_ram[addr_index] && (tag_ram[addr_index] == addr_tag);
    typedef enum logic [1:0] {
        IDLE   = 2'd0,
        REFILL = 2'd1
    } state_t;
    state_t      state;
    logic [1:0]  refill_count;
    logic [31:0] hit_data_r;
    logic        cpu_ready_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            refill_count <= 2'd0;
            miss_tag     <= '0;
            miss_index   <= '0;
            miss_offset  <= '0;
            hit_data_r   <= '0;
            cpu_ready_r  <= 1'b0;
            for (int i = 0; i < 64; i++)
                valid_ram[i] <= 1'b0;
        end else begin
            cpu_ready_r <= 1'b0; // default deassert
            case (state)
                IDLE: begin
                    if (!mem_stall && cpu_req) begin
                        if (hit) begin
                            // hit: return data and pulse ready, stay in IDLE
                            hit_data_r  <= cache_ram[addr_index][addr_offset];
                            cpu_ready_r <= 1'b1;
                        end else begin
                            // miss: latch request and start refill
                            miss_tag     <= addr_tag;
                            miss_index   <= addr_index;
                            miss_offset  <= addr_offset;
                            refill_count <= 2'd0;
                            state        <= REFILL;
                        end
                    end
                end
                REFILL: begin
                    if (mem_ready) begin
                        cache_ram[miss_index][refill_count] <= mem_rdata;
                        
                        // Capture immediately when target word arrives
                        if (refill_count == miss_offset)
                            hit_data_r <= mem_rdata;
                            
                        if (refill_count == 2'd3) begin
                            tag_ram[miss_index]   <= miss_tag;
                            valid_ram[miss_index] <= 1'b1;
                            // hit_data_r already set above; no refill lookup needed
                            cpu_ready_r <= 1'b1;
                            state       <= IDLE;
                        end else begin
                            refill_count <= refill_count + 2'd1;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
    assign mem_req   = (state == REFILL);
    assign mem_addr  = {miss_tag, miss_index, refill_count, 2'b00};
    assign cpu_ready = cpu_ready_r;
    assign cpu_rdata = hit_data_r;
endmodule