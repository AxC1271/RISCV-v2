module wb_interconnect (    
    // master (from core dmem)
    input  logic [31:0] m_addr,
    input  logic [31:0] m_wdata,
    input  logic [3:0]  m_wstrb,
    input  logic        m_rd_en,
    input  logic        m_wr_en,
    output logic [31:0] m_rdata,
    output logic        m_ready,

    // ram slave
    output logic [31:0] ram_addr,
    output logic [31:0] ram_wdata,
    output logic [3:0]  ram_wstrb,
    output logic        ram_rd_en,
    output logic        ram_wr_en,
    input  logic [31:0] ram_rdata,
    input  logic        ram_ready,

    // uart slave
    output logic [31:0] uart_addr,
    output logic [31:0] uart_wdata,
    output logic [3:0]  uart_wstrb,
    output logic        uart_rd_en,
    output logic        uart_wr_en,
    input  logic [31:0] uart_rdata,
    input  logic        uart_ready,

    // gpio slave (for later expansion)
    output logic [31:0] gpio_addr,
    output logic [31:0] gpio_wdata,
    output logic [3:0]  gpio_wstrb,
    output logic        gpio_rd_en,
    output logic        gpio_wr_en,
    input  logic [31:0] gpio_rdata,
    input  logic        gpio_ready
);

    // address decode: select which slave to route to
    logic ram_sel, uart_sel, gpio_sel;
    always_comb begin
        case (m_addr[15:14])
            2'b01: begin   // 0x4000–0x7FFF: ram
                ram_sel   = 1'b1;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b0;
            end
            2'b10: begin   // 0x8000–0xBFFF: uart
                ram_sel   = 1'b0;
                uart_sel  = 1'b1;
                gpio_sel  = 1'b0;
            end
            2'b11: begin   // 0xC000–0xFFFF: gpio
                ram_sel   = 1'b0;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b1;
            end
            default: begin // 0x0000–0x3FFF: no slave (ROM, not here)
                ram_sel   = 1'b0;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b0;
            end
        endcase
    end

    // fanout transaction to selected slave only
    always_comb begin
        ram_addr   = m_addr;
        ram_wdata  = m_wdata;
        ram_wstrb  = m_wstrb;
        ram_rd_en  = m_rd_en & ram_sel;
        ram_wr_en  = m_wr_en & ram_sel;

        uart_addr  = m_addr;
        uart_wdata = m_wdata;
        uart_wstrb = m_wstrb;
        uart_rd_en = m_rd_en & uart_sel;
        uart_wr_en = m_wr_en & uart_sel;

        gpio_addr  = m_addr;
        gpio_wdata = m_wdata;
        gpio_wstrb = m_wstrb;
        gpio_rd_en = m_rd_en & gpio_sel;
        gpio_wr_en = m_wr_en & gpio_sel;
    end

    // mux responses back from selected slave
    always_comb begin
        case (m_addr[15:14])
            2'b01: begin   // ram
                m_rdata = ram_rdata;
                m_ready = ram_ready;
            end
            2'b10: begin   // uart
                m_rdata = uart_rdata;
                m_ready = uart_ready;
            end
            2'b11: begin   // gpio
                m_rdata = gpio_rdata;
                m_ready = gpio_ready;
            end
            default: begin // invalid
                m_rdata = 32'h0;
                m_ready = 1'b0;
            end
        endcase
    end

endmodule