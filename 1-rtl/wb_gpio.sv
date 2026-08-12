// wishbone gpio (16 led's + 16 switches + 2 pmod pins)

module wb_gpio (
    input  logic clk,
    input  logic rst_n,
    
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic [3:0]  wb_sel,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,
    
    // basys3 i/o
    output logic [15:0] led,
    output logic [1:0]  pmod,
    input  logic [15:0] sw
);

    // lower 2 bits of address select register
    logic [1:0] addr_reg;
    assign addr_reg = wb_addr[3:2];

    logic valid_req;
    assign valid_req = wb_cycle & wb_strb;

    logic ack_r;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_r <= 1'b0;
        end else begin
            ack_r <= valid_req;
        end
    end
    
    assign wb_ack = ack_r;

    logic [15:0] led_r;
    logic [1:0]  pmod_r;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_r  <= 16'h0000;
            pmod_r <= 2'b00;
        end else if (valid_req && wb_we) begin
            case (addr_reg)
                2'b00: begin
                    // offset 0x0: led/output data
                    // [15:0]  = led's
                    // [31:16] = pmod (only 2 bits used)
                    if (wb_sel[0]) led_r[7:0]   <= wb_dat_w[7:0];
                    if (wb_sel[1]) led_r[15:8]  <= wb_dat_w[15:8];
                    if (wb_sel[2]) pmod_r[1:0]  <= wb_dat_w[17:16];
                end
                default: begin
                    // read-only registers
                end
            endcase
        end
    end
    
    assign led  = led_r;
    assign pmod = pmod_r;

    // read mux
    logic [31:0] read_data;
    
    always_comb begin
        case (addr_reg)
            2'b00: begin
                // offset 0x0: led/output data (read-back)
                read_data = {16'h0000, pmod_r, led_r};
            end
            2'b01: begin
                // offset 0x4: switch/input data (read-only)
                read_data = {16'h0000, sw};
            end
            default: begin
                read_data = 32'h0000_0000;
            end
        endcase
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
            2'b00: read_data_r <= {16'h0000, pmod_r, led_r};
            2'b01: read_data_r <= {16'h0000, sw};
            default: read_data_r <= 32'h0000_0000;
        endcase
    end
    
    assign wb_dat_r = read_data_r;

endmodule