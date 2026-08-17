module wb_gpio (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic [3:0]  wb_sel,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,
    
    output logic [15:0] led,
    output logic [1:0]  pmod,
    input  logic [15:0] sw
);

    logic [2:0] addr_reg;
    assign addr_reg = wb_addr[3:2];
    
    logic valid_req;
    assign valid_req = wb_cycle & wb_strb;
    
    logic ack_r;
    
    always_ff @(posedge clk) begin
        if (!rst_n)
            ack_r <= 1'b0;
        else
            ack_r <= valid_req;
    end
    
    assign wb_ack = ack_r;

    logic [15:0] led_r;
    logic [1:0]  pmod_r;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            led_r  <= 16'h0000;
            pmod_r <= 2'b00;
        end else if (valid_req && wb_we) begin
            case (addr_reg)
                3'b000: begin
                    if (wb_sel[0]) led_r[7:0]   <= wb_dat_w[7:0];
                    if (wb_sel[1]) led_r[15:8]  <= wb_dat_w[15:8];
                    if (wb_sel[2]) pmod_r[1:0]  <= wb_dat_w[17:16];
                end
            endcase
        end
    end
    
    assign led  = led_r;
    assign pmod = pmod_r;
    
    logic [2:0] addr_r;
    
    always_ff @(posedge clk) begin
        if (valid_req) begin
            addr_r <= addr_reg;
        end
    end
    
    always_ff @(posedge clk) begin
        case (addr_r)
            3'b000: wb_dat_r <= {14'b0, pmod_r, led_r};      
            3'b001: wb_dat_r <= {16'b0, sw};                
            default: wb_dat_r <= 32'h0000_0000;
        endcase
    end

endmodule