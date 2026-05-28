`timescale 1ns / 1ps

module axilite_interconnect (
    input logic clk,
    input logic rst_n,

    input logic [31:0] m_awaddr,
    input logic m_awvalid,
    output logic m_awready,
    input logic [31:0] m_wdata,
    input logic [3:0] m_wstrb,
    input logic m_wvalid,
    output logic m_wready,
    output logic [1:0] m_bresp,
    output logic m_bvalid,
    input logic m_bready,
    input logic [31:0] m_araddr,
    input logic m_arvalid,
    output logic m_arready,
    output logic [31:0] m_rdata,
    output logic [1:0] m_rresp,
    output logic m_rvalid,
    input logic m_rready,

    output logic [31:0] s0_awaddr,
    output logic s0_awvalid,
    input logic s0_awready,
    output logic [31:0] s0_wdata,
    output logic [3:0] s0_wstrb,
    output logic s0_wvalid,
    input logic s0_wready,
    input logic [1:0] s0_bresp,
    input logic s0_bvalid,
    output logic s0_bready,
    output logic [31:0] s0_araddr,
    output logic s0_arvalid,
    input logic s0_arready,
    input logic [31:0] s0_rdata,
    input logic [1:0] s0_rresp,
    input logic s0_rvalid,
    output logic s0_rready,

    output logic [31:0] s1_awaddr,
    output logic s1_awvalid,
    input logic s1_awready,
    output logic [31:0] s1_wdata,
    output logic [3:0] s1_wstrb,
    output logic s1_wvalid,
    input logic s1_wready,
    input logic [1:0] s1_bresp,
    input logic s1_bvalid,
    output logic s1_bready,
    output logic [31:0] s1_araddr,
    output logic s1_arvalid,
    input logic s1_arready,
    input logic [31:0] s1_rdata,
    input logic [1:0] s1_rresp,
    input logic s1_rvalid,
    output logic s1_rready,

    output logic [31:0] s2_awaddr,
    output logic s2_awvalid,
    input logic s2_awready,
    output logic [31:0] s2_wdata,
    output logic [3:0] s2_wstrb,
    output logic s2_wvalid,
    input logic s2_wready,
    input logic [1:0] s2_bresp,
    input logic s2_bvalid,
    output logic s2_bready,
    output logic [31:0] s2_araddr,
    output logic s2_arvalid,
    input logic s2_arready,
    input logic [31:0] s2_rdata,
    input logic [1:0] s2_rresp,
    input logic s2_rvalid,
    output logic s2_rready,

    output logic [31:0] s3_awaddr,
    output logic s3_awvalid,
    input logic s3_awready,
    output logic [31:0] s3_wdata,
    output logic [3:0] s3_wstrb,
    output logic s3_wvalid,
    input logic s3_wready,
    input logic [1:0] s3_bresp,
    input logic s3_bvalid,
    output logic s3_bready,
    output logic [31:0] s3_araddr,
    output logic s3_arvalid,
    input logic s3_arready,
    input logic [31:0] s3_rdata,
    input logic [1:0] s3_rresp,
    input logic s3_rvalid,
    output logic s3_rready
);

    logic [1:0] wr_sel_comb, rd_sel_comb;
    logic [1:0] wr_sel, rd_sel;
    logic wr_active, rd_active;

    always_comb begin
        case (m_awaddr[19:16])
            4'h0:    wr_sel_comb = 2'd0;
            4'h1:    wr_sel_comb = 2'd1;
            4'h2:    wr_sel_comb = 2'd2;
            4'h3:    wr_sel_comb = 2'd3;
            default: wr_sel_comb = 2'd0;
        endcase

        case (m_araddr[19:16])
            4'h0:    rd_sel_comb = 2'd0;
            4'h1:    rd_sel_comb = 2'd1;
            4'h2:    rd_sel_comb = 2'd2;
            4'h3:    rd_sel_comb = 2'd3;
            default: rd_sel_comb = 2'd0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_sel    <= 2'd0;
            rd_sel    <= 2'd0;
            wr_active <= 1'b0;
            rd_active <= 1'b0;
        end else begin
            if (m_awvalid && m_awready && !wr_active) begin
                wr_sel    <= wr_sel_comb;
                wr_active <= 1'b1;
            end else if (m_bvalid && m_bready) begin
                wr_active <= 1'b0;
            end

            if (m_arvalid && m_arready && !rd_active) begin
                rd_sel    <= rd_sel_comb;
                rd_active <= 1'b1;
            end else if (m_rvalid && m_rready) begin
                rd_active <= 1'b0;
            end
        end
    end

    logic [1:0] wr_sel_eff, rd_sel_eff;
    assign wr_sel_eff = wr_active ? wr_sel : wr_sel_comb;
    assign rd_sel_eff = rd_active ? rd_sel : rd_sel_comb;

    assign s0_awaddr = m_awaddr;
    assign s1_awaddr = m_awaddr;
    assign s2_awaddr = m_awaddr;
    assign s3_awaddr = m_awaddr;

    assign s0_awvalid = m_awvalid && (wr_sel_eff == 2'd0);
    assign s1_awvalid = m_awvalid && (wr_sel_eff == 2'd1);
    assign s2_awvalid = m_awvalid && (wr_sel_eff == 2'd2);
    assign s3_awvalid = m_awvalid && (wr_sel_eff == 2'd3);

    always_comb begin
        case (wr_sel_eff)
            2'd0:    m_awready = s0_awready;
            2'd1:    m_awready = s1_awready;
            2'd2:    m_awready = s2_awready;
            2'd3:    m_awready = s3_awready;
            default: m_awready = 1'b0;
        endcase
    end

    assign s0_wdata  = m_wdata;  assign s0_wstrb  = m_wstrb;
    assign s1_wdata  = m_wdata;  assign s1_wstrb  = m_wstrb;
    assign s2_wdata  = m_wdata;  assign s2_wstrb  = m_wstrb;
    assign s3_wdata  = m_wdata;  assign s3_wstrb  = m_wstrb;

    assign s0_wvalid = m_wvalid && (wr_sel_eff == 2'd0);
    assign s1_wvalid = m_wvalid && (wr_sel_eff == 2'd1);
    assign s2_wvalid = m_wvalid && (wr_sel_eff == 2'd2);
    assign s3_wvalid = m_wvalid && (wr_sel_eff == 2'd3);

    always_comb begin
        case (wr_sel_eff)
            2'd0:    m_wready = s0_wready;
            2'd1:    m_wready = s1_wready;
            2'd2:    m_wready = s2_wready;
            2'd3:    m_wready = s3_wready;
            default: m_wready = 1'b0;
        endcase
    end

    assign s0_bready = m_bready && (wr_sel_eff == 2'd0);
    assign s1_bready = m_bready && (wr_sel_eff == 2'd1);
    assign s2_bready = m_bready && (wr_sel_eff == 2'd2);
    assign s3_bready = m_bready && (wr_sel_eff == 2'd3);

    always_comb begin
        case (wr_sel_eff)
            2'd0:    begin m_bresp = s0_bresp; m_bvalid = s0_bvalid; end
            2'd1:    begin m_bresp = s1_bresp; m_bvalid = s1_bvalid; end
            2'd2:    begin m_bresp = s2_bresp; m_bvalid = s2_bvalid; end
            2'd3:    begin m_bresp = s3_bresp; m_bvalid = s3_bvalid; end
            default: begin m_bresp = 2'b00;    m_bvalid = 1'b0;      end
        endcase
    end

    assign s0_araddr  = m_araddr;
    assign s1_araddr  = m_araddr;
    assign s2_araddr  = m_araddr;
    assign s3_araddr  = m_araddr;

    assign s0_arvalid = m_arvalid && (rd_sel_eff == 2'd0);
    assign s1_arvalid = m_arvalid && (rd_sel_eff == 2'd1);
    assign s2_arvalid = m_arvalid && (rd_sel_eff == 2'd2);
    assign s3_arvalid = m_arvalid && (rd_sel_eff == 2'd3);

    always_comb begin
        case (rd_sel_eff)
            2'd0:    m_arready = s0_arready;
            2'd1:    m_arready = s1_arready;
            2'd2:    m_arready = s2_arready;
            2'd3:    m_arready = s3_arready;
            default: m_arready = 1'b0;
        endcase
    end

    assign s0_rready = m_rready && (rd_sel_eff == 2'd0);
    assign s1_rready = m_rready && (rd_sel_eff == 2'd1);
    assign s2_rready = m_rready && (rd_sel_eff == 2'd2);
    assign s3_rready = m_rready && (rd_sel_eff == 2'd3);

    always_comb begin
        case (rd_sel_eff)
            2'd0:    begin m_rdata = s0_rdata; m_rresp = s0_rresp; m_rvalid = s0_rvalid; end
            2'd1:    begin m_rdata = s1_rdata; m_rresp = s1_rresp; m_rvalid = s1_rvalid; end
            2'd2:    begin m_rdata = s2_rdata; m_rresp = s2_rresp; m_rvalid = s2_rvalid; end
            2'd3:    begin m_rdata = s3_rdata; m_rresp = s3_rresp; m_rvalid = s3_rvalid; end
            default: begin m_rdata = 32'h0;    m_rresp = 2'b00;    m_rvalid = 1'b0;      end
        endcase
    end

endmodule