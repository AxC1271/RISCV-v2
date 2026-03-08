# Bootloader

## Purpose

Unlike the previous processor, which needed a preloaded set of RISC-V instructions etched into the silicon during synthesis, this bootloader module aims to make the processor programmable through serial communication. 

---

## RTL Code

### Asynchronous FIFO

To see the RTL code, check `./asynchronous_fifo/async_fifo.sv`. I'll go over the block diagram and the big picture of what an asynchronous FIFO is supposed to achieve.

### UART Receiver

To see the RTL code, check `./uart_receiver/uart_rx.sv`. 


### Word Assembler

To see the RTL code, check `./word_assembler/word_assembler.sv`. 


### Complete Integration

```Verilog
module bootloader # (
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ = 100_000_000,
    parameter IMEM_DEPTH = 1024  // 1K instructions = 4KB
) (
    // uart interface
    input  logic uart_clk,      
    input  logic uart_rst_n,
    input  logic uart_rx,
    
    // cpu interface
    input  logic cpu_clk,
    input  logic cpu_rst_n,
    
    // instruction memory write interface
    output logic [31:0] imem_wr_data,
    output logic [9:0]  imem_wr_addr,  // log2(1024) = 10 bits
    output logic        imem_wr_en,
    
    // status flags
    output logic boot_done,
    output logic boot_error
);

    // uart rx signals
    logic [7:0] uart_rx_data;
    logic uart_rx_valid;
    
    // async fifo signals
    logic [7:0] fifo_rd_data;
    logic fifo_rd_en;
    logic fifo_empty;
    logic fifo_full;
    
    // word assembler signals
    logic [31:0] word_data;
    logic word_valid;
    logic word_ready;
    
    logic [9:0] wr_addr_counter;
    logic [11:0] expected_bytes;  
    logic [11:0] received_bytes;
    
    // instantiate uart_rx
    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLK_FREQ(CLK_FREQ),
        .DATA_WIDTH(8)
    ) uart_rx_inst (
        .clk(uart_clk),
        .rst_n(uart_rst_n),
        .rx(uart_rx),
        .rx_data(uart_rx_data),
        .wr(uart_rx_valid)
    );
    
    // instantiate 8-bit FIFO
    async_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(64)  // Buffer up to 64 bytes
    ) fifo_inst (
        .clk_w(uart_clk),
        .rst_n_w(uart_rst_n),
        .wr_en(uart_rx_valid),
        .wr_data(uart_rx_data),
        
        .clk_r(cpu_clk),
        .rst_n_r(cpu_rst_n),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        
        .empty(fifo_empty),
        .full(fifo_full)
    );
    
    // instantiate word assembler (8-bit -> 32-bit)
    word_assembler #(
        .WORD_WIDTH(32),
        .BYTE_WIDTH(8)
    ) word_asm_inst (
        .clk(cpu_clk),
        .rst_n(cpu_rst_n),
        
        .byte_in(fifo_rd_data),
        .byte_valid(!fifo_empty && fifo_rd_en),
        .byte_ready(fifo_rd_en),
        
        .word_out(word_data),
        .word_valid(word_valid),
        .word_ready(word_ready)
    );
    
    // read from FIFO when it has data and word assembler is ready
    assign fifo_rd_en = !fifo_empty && (word_ready || word_valid == 0);
    
    // instruction memory write controller
    always_ff @(posedge cpu_clk or negedge cpu_rst_n) begin
        if (!cpu_rst_n) begin
            wr_addr_counter <= '0;
            received_bytes <= '0;
            boot_done <= 1'b0;
            boot_error <= 1'b0;
            imem_wr_en <= 1'b0;
            imem_wr_addr <= '0;
            imem_wr_data <= '0;
            word_ready <= 1'b1;
        end else begin
            imem_wr_en <= 1'b0;  // no write
            
            // check if word assembler has a complete word
            if (word_valid && word_ready) begin
                // write to instruction memory
                imem_wr_data <= word_data;
                imem_wr_addr <= wr_addr_counter;
                imem_wr_en <= 1'b1;
                
                // increment address
                wr_addr_counter <= wr_addr_counter + 1'b1;
                received_bytes <= received_bytes + 4;  // 4 bytes per word
                
                // check if we've received all expected data
                // (you'd set expected_bytes via some protocol)
                if (received_bytes >= expected_bytes) begin
                    boot_done <= 1'b1;
                    word_ready <= 1'b0; 
                end
                
                // check for overflow
                if (wr_addr_counter >= IMEM_DEPTH) begin
                    boot_error <= 1'b1;
                    word_ready <= 1'b0;
                end
            end
        end
    end
endmodule
```

---

## Simulation + Waveform

---

## References