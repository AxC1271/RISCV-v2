// address map:
//   0x4000–0x7FFF: ram
//   0x8000–0x8FFF: timer
//   0x9000–0xBFFF: uart
//   0xC000–0xCFFF: gpio

module wb_interconnect (
    // master side
    input  logic [31:0] m_addr,
    input  logic [31:0] m_wdata,
    input  logic [3:0]  m_wstrb,
    input  logic        m_rd_en,
    input  logic        m_wr_en,
    output logic [31:0] m_rdata,
    output logic        m_ready,

    // ram pins
    output logic [31:0] ram_addr,
    output logic [31:0] ram_wdata,
    output logic [3:0]  ram_wstrb,
    output logic        ram_rd_en,
    output logic        ram_wr_en,
    input  logic [31:0] ram_rdata,
    input  logic        ram_ready,

    // timer pins
    output logic [31:0] timer_addr,
    output logic [31:0] timer_wdata,
    output logic [3:0]  timer_wstrb,
    output logic        timer_rd_en,
    output logic        timer_wr_en,
    input  logic [31:0] timer_rdata,
    input  logic        timer_ready,

    // uart pins
    output logic [31:0] uart_addr,
    output logic [31:0] uart_wdata,
    output logic [3:0]  uart_wstrb,
    output logic        uart_rd_en,
    output logic        uart_wr_en,
    input  logic [31:0] uart_rdata,
    input  logic        uart_ready,

    // gpio pins
    output logic [31:0] gpio_addr,
    output logic [31:0] gpio_wdata,
    output logic [3:0]  gpio_wstrb,
    output logic        gpio_rd_en,
    output logic        gpio_wr_en,
    input  logic [31:0] gpio_rdata,
    input  logic        gpio_ready
);

    // address decode: select which slave
    logic ram_sel, timer_sel, uart_sel, gpio_sel;
    
    always_comb begin
        case (m_addr[15:12])
            4'b0100, 4'b0101, 4'b0110, 4'b0111: begin
                ram_sel   = 1'b1;
                timer_sel = 1'b0;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b0;
            end
            4'b1000: begin
                ram_sel   = 1'b0;
                timer_sel = 1'b1;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b0;
            end
            4'b1001, 4'b1010, 4'b1011: begin
                ram_sel   = 1'b0;
                timer_sel = 1'b0;
                uart_sel  = 1'b1;
                gpio_sel  = 1'b0;
            end
            4'b1100: begin
                ram_sel   = 1'b0;
                timer_sel = 1'b0;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b1;
            end
            default: begin
                ram_sel   = 1'b0;
                timer_sel = 1'b0;
                uart_sel  = 1'b0;
                gpio_sel  = 1'b0;
            end
        endcase
    end

    // route signals to selected slave
    always_comb begin
        ram_addr   = m_addr;
        ram_wdata  = m_wdata;
        ram_wstrb  = m_wstrb;
        ram_rd_en  = m_rd_en & ram_sel;
        ram_wr_en  = m_wr_en & ram_sel;

        timer_addr   = m_addr;
        timer_wdata  = m_wdata;
        timer_wstrb  = m_wstrb;
        timer_rd_en  = m_rd_en & timer_sel;
        timer_wr_en  = m_wr_en & timer_sel;

        uart_addr   = m_addr;
        uart_wdata  = m_wdata;
        uart_wstrb  = m_wstrb;
        uart_rd_en  = m_rd_en & uart_sel;
        uart_wr_en  = m_wr_en & uart_sel;

        gpio_addr   = m_addr;
        gpio_wdata  = m_wdata;
        gpio_wstrb  = m_wstrb;
        gpio_rd_en  = m_rd_en & gpio_sel;
        gpio_wr_en  = m_wr_en & gpio_sel;
    end

    // mux response from selected slave
    always_comb begin
        case (m_addr[15:12])
            4'b0100, 4'b0101, 4'b0110, 4'b0111: begin
                // RAM
                m_rdata = ram_rdata;
                m_ready = ram_ready;
            end
            4'b1000: begin
                // Timer
                m_rdata = timer_rdata;
                m_ready = timer_ready;
            end
            4'b1001, 4'b1010, 4'b1011: begin
                // UART
                m_rdata = uart_rdata;
                m_ready = uart_ready;
            end
            4'b1100: begin
                // GPIO
                m_rdata = gpio_rdata;
                m_ready = gpio_ready;
            end
            default: begin
                // Invalid address: no slave selected
                m_rdata = 32'h0;
                m_ready = 1'b0;
            end
        endcase
    end

endmodule