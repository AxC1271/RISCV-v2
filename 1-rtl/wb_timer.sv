// wishbone timer (free-running 32-bit counter)

module wb_timer (
    input  logic clk,
    input  logic rst_n,
    
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic [3:0]  wb_sel,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    
    output logic [31:0] wb_dat_r,
    output logic        wb_ack
);

    // lower 2 bits of address select register
    logic [1:0] addr_reg;
    assign addr_reg = wb_addr[3:2];

    // valid request
    logic valid_req;
    assign valid_req = wb_cycle & wb_strb;

    // pipelined ack
    logic ack_r;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_r <= 1'b0;
        end else begin
            ack_r <= valid_req;
        end
    end
    
    assign wb_ack = ack_r;

    // timer control and counter
    logic timer_enable;
    logic [31:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_enable <= 1'b0;
            counter      <= 32'h0000_0000;
        end else begin
            if (valid_req && wb_we) begin
                case (addr_reg)
                    2'b00: begin
                        if (wb_sel[0]) timer_enable <= wb_dat_w[0];
                    end
                    2'b01: begin
                        if (wb_sel[0]) counter[7:0]   <= wb_dat_w[7:0];
                        if (wb_sel[1]) counter[15:8]  <= wb_dat_w[15:8];
                        if (wb_sel[2]) counter[23:16] <= wb_dat_w[23:16];
                        if (wb_sel[3]) counter[31:24] <= wb_dat_w[31:24];
                    end
                    default: begin
                        // no-op
                    end
                endcase
            end
            
            // counter increment (free-running when enabled)
            if (timer_enable) begin
                counter <= counter + 32'h0000_0001;
            end
        end
    end

    // synchronous read: latch address, read on next cycle
    logic [1:0] addr_r;
    
    always_ff @(posedge clk) begin
        if (valid_req) begin
            addr_r <= addr_reg;
        end
    end

    logic [31:0] read_data_r;
    
    always_ff @(posedge clk) begin
        case (addr_r)
            2'b00: begin
                read_data_r <= {31'h0000_0000, timer_enable};
            end
            2'b01: begin
                read_data_r <= counter;
            end
            2'b10: begin
                read_data_r <= {31'h0000_0000, timer_enable};
            end
            default: begin
                read_data_r <= 32'h0000_0000;
            end
        endcase
    end
    
    assign wb_dat_r = read_data_r;

endmodule