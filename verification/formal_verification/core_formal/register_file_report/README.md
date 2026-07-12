# Register File

## Purpose

The register file is one of the most important modules when it comes to CPU/GPU architectures. It acts as easy access registers that the CPU can quickly access to compute information. In this specific RISC-V architecture, we are declaring a register file of 32 registers, with the following ports:

* `clk`: your master clock signal
* `rst_n`: negative-edge triggered reset
* `rd_addr1`, `rd_addr2`: your read addresses
* `wr_addr`: your write address 
* `wr_data`: the data you want to write
* `wr_en`: write enable
* `rd_data1`, `rd_data2`: read outputs

As an exercise, I would encourage someone to write their own register file in SystemVerilog before comparing to mine.

---

## RTL Code

Here's the design implementation of `register_file.sv` in SystemVerilog:

```Verilog
`timescale 1ns / 1ps

module register_file (
    input logic clk,
    input logic rst_n,
    input logic[4:0] rd_addr1,
    input logic[4:0] rd_addr2,

    input logic[4:0] wr_addr,
    input logic[31:0] wr_data,
    input logic wr_en,

    output logic[31:0] rd_data1,
    output logic[31:0] rd_data2
);

    logic[31:0] mem [0:31];
    localparam int ZERO_REG = 0;

    // make reads combinational
    assign rd_data1 = mem[rd_addr1];
    assign rd_data2 = mem[rd_addr2];

    // write process should be clocked
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                mem[i] <= 32'h0;
            end
        end else begin
            if (wr_en && wr_addr != ZERO_REG) begin
                mem[wr_addr] <= wr_data;
            end
        end
    end
endmodule
```

Notice that in this RTL code, I've decided that writes should be clocked whereas reads are combinational. As for writes, you want to ensure that data changes are done on a rising edge instead of done on a "high" logic level. Such latching behavior is generally bad practice and can introduce timing issues. As for deciding on why the reads should be combinational, your data read buses will be updated automatically without having to wait on the next clock edge.

---

## Simulation + Waveform


---

