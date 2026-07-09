`timescale 1ns / 1ps

module axilite_master # (
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    input logic cpu_req,
    input logic cpu_we,
    input logic[ADDR_WIDTH-1:0] cpu_addr,
    input logic[DATA_WIDTH-1:0] cpu_wdata,
    input logic[3:0] cpu_wstrb, 
    output logic[DATA_WIDTH-1:0] cpu_rdata,
    output logic cpu_ready,

    output logic[ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic[2:0] m_axi_awprot,
    output logic m_axi_awvalid,
    input logic m_axi_awready,

    output logic[DATA_WIDTH-1:0] m_axi_wdata,
    output logic[3:0] m_axi_wstrb, 
    output logic m_axi_wvalid,
    input logic m_axi_wready,

    input logic[1:0] m_axi_bresp,
    input logic m_axi_bvalid,
    output logic m_axi_bready,

    output logic[ADDR_WIDTH-1:0] m_axi_araddr,
    output logic[2:0] m_axi_arprot,
    output logic m_axi_arvalid,
    input logic m_axi_arready,

    input logic[DATA_WIDTH-1:0] m_axi_rdata,
    input logic[1:0] m_axi_rresp,
    input logic m_axi_rvalid,
    output logic m_axi_rready
);

    typedef enum logic[2:0] {
        IDLE,
        WRITE_ADDR,
        WRITE_DATA,
        WRITE_RESP,
        READ_ADDR,
        READ_DATA
    } axi_state_t;

    axi_state_t current_state, next_state;

    logic [ADDR_WIDTH-1:0] addr_lat;
    logic [DATA_WIDTH-1:0] wdata_lat;
    logic [3:0]            wstrb_lat;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_lat  <= '0;
            wdata_lat <= '0;
            wstrb_lat <= '0;
        end else if (current_state == IDLE && cpu_req) begin
            addr_lat  <= cpu_addr;
            wdata_lat <= cpu_wdata;
            wstrb_lat <= cpu_wstrb;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (cpu_req && cpu_we) begin
                    next_state = WRITE_ADDR;
                end else if (cpu_req && !cpu_we) begin
                    next_state = READ_ADDR;
                end
            end
            WRITE_ADDR: begin
                if (m_axi_awvalid && m_axi_awready) begin
                    next_state = WRITE_DATA;
                end
            end
            WRITE_DATA: begin
                if (m_axi_wvalid && m_axi_wready) begin
                    next_state = WRITE_RESP;
                end
            end
            WRITE_RESP: begin
                if (m_axi_bvalid && m_axi_bready) begin
                    next_state = IDLE;
                end
            end
            READ_ADDR: begin
                if (m_axi_arvalid && m_axi_arready) begin
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                if (m_axi_rvalid && m_axi_rready) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin
        m_axi_awvalid = 1'b0;
        m_axi_awaddr  = '0;
        m_axi_awprot  = 3'b000;

        m_axi_wvalid  = 1'b0;
        m_axi_wdata   = '0;
        m_axi_wstrb   = '0;

        m_axi_bready  = 1'b0;

        m_axi_arvalid = 1'b0;
        m_axi_araddr  = '0;
        m_axi_arprot  = 3'b000;

        m_axi_rready  = 1'b0;

        cpu_ready     = 1'b0;
        cpu_rdata     = '0;

        case (current_state)
            IDLE: begin
            end

            WRITE_ADDR: begin
                m_axi_awvalid = 1'b1;
                m_axi_awaddr  = addr_lat;
                m_axi_awprot  = 3'b000;
            end

            WRITE_DATA: begin
                m_axi_wvalid = 1'b1;
                m_axi_wdata  = wdata_lat;
                m_axi_wstrb  = wstrb_lat;
            end

            WRITE_RESP: begin
                m_axi_bready = 1'b1;
                if (m_axi_bvalid) begin
                    cpu_ready = 1'b1;
                end
            end

            READ_ADDR: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = addr_lat;
                m_axi_arprot  = 3'b000;
            end

            READ_DATA: begin
                m_axi_rready = 1'b1;
                if (m_axi_rvalid) begin
                    cpu_ready = 1'b1;
                    cpu_rdata = m_axi_rdata;
                end
            end

            default: begin
            end
        endcase
    end

endmodule