module bootloader (
    input  logic clk,
    input  logic rst_n,
    
    input  logic        uart_rx,

    output logic [31:0] imem_addr,
    output logic [31:0] imem_wdata,
    output logic        imem_wr_en,

    output logic        cpu_enable
);

    parameter BAUD_DIVIDER = 54; 
    
    logic [7:0] baud_counter;
    logic       baud_tick;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            baud_counter <= 8'b0;
            baud_tick    <= 1'b0;
        end else begin
            if (baud_counter == BAUD_DIVIDER - 1) begin
                baud_counter <= 8'b0;
                baud_tick    <= 1'b1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick    <= 1'b0;
            end
        end
    end
    
    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START,
        RX_SHIFT,
        RX_STOP
    } rx_state_t;
    
    rx_state_t rx_state, rx_state_next;
    
    logic [7:0]  rx_shift_reg;
    logic [3:0]  rx_bit_counter;
    logic [3:0]  rx_sample_counter;
    logic [7:0]  uart_rx_data;
    logic        uart_rx_valid, uart_rx_valid_next;

    always_comb begin
        rx_state_next = rx_state;
        uart_rx_valid_next = 1'b0;
        
        case (rx_state)
            RX_IDLE: begin
                if (!uart_rx) begin
                    rx_state_next = RX_START;
                end
            end
            RX_START: begin
                if (baud_tick && rx_sample_counter == 4'd7) begin
                    if (!uart_rx) begin
                        rx_state_next = RX_SHIFT;
                    end else begin
                        rx_state_next = RX_IDLE;
                    end
                end
            end
            RX_SHIFT: begin
                if (baud_tick && rx_bit_counter == 4'd8) begin
                    rx_state_next = RX_STOP;
                end
            end
            RX_STOP: begin
                if (baud_tick && rx_sample_counter == 4'd15) begin
                    if (uart_rx) begin
                        uart_rx_valid_next = 1'b1;
                    end
                    rx_state_next = RX_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_sample_counter <= 4'd0;
            rx_bit_counter <= 4'd0;
            rx_shift_reg <= 8'b0;
            uart_rx_data <= 8'b0;
            uart_rx_valid <= 1'b0;
        end else begin
            rx_state <= rx_state_next;
            uart_rx_valid <= uart_rx_valid_next;
            
            if (baud_tick) begin
                rx_sample_counter <= (rx_sample_counter == 4'd15) ? 4'd0 : rx_sample_counter + 1;
            end
            
            if (baud_tick && rx_sample_counter == 4'd8 && rx_state == RX_SHIFT) begin
                rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};
                rx_bit_counter <= rx_bit_counter + 1;
            end
            
            if (rx_state == RX_STOP && baud_tick && rx_sample_counter == 4'd15) begin
                uart_rx_data <= rx_shift_reg;
                rx_bit_counter <= 4'd0;
            end
        end
    end
    
    typedef enum logic [2:0] {
        BOOT_IDLE,
        BOOT_LEN_HIGH,
        BOOT_LOAD,
        BOOT_DONE
    } boot_state_t;

    boot_state_t boot_state, boot_state_next;
    logic [15:0] bytes_remaining;
    logic [31:0] current_word;
    logic [1:0]  byte_count;
    logic [31:0] boot_write_addr;

    always_comb begin
        boot_state_next = boot_state;
        
        case (boot_state)
            BOOT_IDLE: begin
                if (uart_rx_valid) begin
                    boot_state_next = BOOT_LEN_HIGH;
                end
            end
            BOOT_LEN_HIGH: begin
                if (uart_rx_valid) begin
                    boot_state_next = BOOT_LOAD;
                end
            end
            BOOT_LOAD: begin
                if (bytes_remaining == 16'h0 && byte_count == 2'b0) begin
                    boot_state_next = BOOT_DONE;
                end
            end
            BOOT_DONE: begin
                boot_state_next = BOOT_DONE;
            end
            default: boot_state_next = BOOT_IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            boot_state <= BOOT_IDLE;
            bytes_remaining <= 16'h0;
            current_word <= 32'h0;
            byte_count <= 2'h0;
            boot_write_addr <= 32'h0;
            cpu_enable <= 1'b0;
        end else begin
            boot_state <= boot_state_next;
            
            if (uart_rx_valid) begin
                case (boot_state)
                    BOOT_IDLE: begin
                        bytes_remaining[15:8] <= uart_rx_data;
                    end
                    BOOT_LEN_HIGH: begin
                        bytes_remaining[7:0] <= uart_rx_data;
                        byte_count <= 2'h0;
                        boot_write_addr <= 32'h0;
                    end
                    BOOT_LOAD: begin
                        case (byte_count)
                            2'b00: current_word[31:24] <= uart_rx_data;
                            2'b01: current_word[23:16] <= uart_rx_data;
                            2'b10: current_word[15:8]  <= uart_rx_data;
                            2'b11: current_word[7:0]   <= uart_rx_data;
                        endcase
                        
                        if (byte_count == 2'b11) begin
                            byte_count <= 2'h0;
                            boot_write_addr <= boot_write_addr + 32'h4;
                        end else begin
                            byte_count <= byte_count + 1;
                        end
                        
                        bytes_remaining <= bytes_remaining - 1;
                    end
                    default: begin

                    end
                endcase
            end
            
            if (boot_state == BOOT_DONE) begin
                cpu_enable <= 1'b1;
            end
        end
    end

    assign imem_wr_en = (boot_state == BOOT_LOAD) && uart_rx_valid && (byte_count == 2'b11);
    assign imem_addr = boot_write_addr;
    assign imem_wdata = current_word;

endmodule