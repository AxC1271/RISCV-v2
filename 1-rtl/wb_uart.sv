module wb_uart (
    input  logic clk,
    input  logic rst_n,
    
    // wishbone slave interface
    input  logic [31:0] wb_addr,
    input  logic [31:0] wb_dat_w,
    input  logic        wb_we,
    input  logic        wb_strb,
    input  logic        wb_cycle,
    output logic [31:0] wb_dat_r,
    output logic        wb_ack,
    
    // uart pins
    input  logic        uart_rx,
    output logic        uart_tx
);

    parameter BAUD_DIVIDER = 54; // assuming 115200 baud rate

    // baud rate generator
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

    // rx path: uart to cpu
    logic [7:0]  rx_shift_reg;
    logic [3:0]  rx_bit_counter;
    logic [3:0]  rx_sample_counter;
    logic [7:0]  rx_data;
    logic        rx_valid, rx_valid_next;
    logic        rx_overflow, rx_overflow_next;
    
    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START,
        RX_SHIFT,
        RX_STOP
    } rx_state_t;
    
    rx_state_t rx_state, rx_state_next;

    always_comb begin
        rx_state_next     = rx_state;
        rx_valid_next     = 1'b0;
        rx_overflow_next  = rx_overflow;
        
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
                        rx_valid_next = 1'b1;
                    end
                    rx_state_next = RX_IDLE;
                end
                
                if (!uart_rx && rx_valid) begin
                    rx_overflow_next = 1'b1;
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
            rx_data <= 8'b0;
            rx_valid <= 1'b0;
            rx_overflow <= 1'b0;
        end else begin
            rx_state <= rx_state_next;
            rx_valid <= rx_valid_next;
            
            if (rx_overflow) begin
                rx_overflow <= 1'b0;
            end else begin
                rx_overflow <= rx_overflow_next;
            end
            
            if (baud_tick) begin
                rx_sample_counter <= (rx_sample_counter == 4'd15) ? 4'd0 : rx_sample_counter + 1;
            end
            
            if (baud_tick && rx_sample_counter == 4'd8 && rx_state == RX_SHIFT) begin
                rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};
                rx_bit_counter <= rx_bit_counter + 1;
            end
            
            if (rx_state == RX_STOP && baud_tick && rx_sample_counter == 4'd15) begin
                rx_data <= rx_shift_reg;
                rx_bit_counter <= 4'd0;
            end
        end
    end

    logic [9:0]  tx_shift_reg;      
    logic [3:0]  tx_bit_counter;    
    logic [3:0]  tx_sample_counter; 
    logic [7:0]  tx_data_latch;
    logic        tx_empty, tx_empty_next;
    logic        tx_busy, tx_busy_next;
    logic        tx_load;
    
    typedef enum logic [1:0] {
        TX_IDLE,
        TX_LOAD,
        TX_SHIFT
    } tx_state_t;
    
    tx_state_t tx_state, tx_state_next;

    always_comb begin
        tx_state_next = tx_state;
        tx_empty_next = tx_empty;
        tx_busy_next  = tx_busy;
        
        case (tx_state)
            TX_IDLE: begin
                if (tx_load) begin
                    tx_state_next = TX_LOAD;
                    tx_empty_next = 1'b0;
                    tx_busy_next  = 1'b1;
                end
            end
            TX_LOAD: begin
                tx_state_next = TX_SHIFT;
            end
            TX_SHIFT: begin
                if (baud_tick && tx_sample_counter == 4'd15 && tx_bit_counter == 4'd9) begin
                    tx_state_next = TX_IDLE;
                    tx_empty_next = 1'b1;
                    tx_busy_next  = 1'b0;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_sample_counter <= 4'd0;
            tx_bit_counter <= 4'd0;
            tx_shift_reg <= 10'b1111111111; 
            tx_data_latch <= 8'b0;
            tx_empty <= 1'b1;
            tx_busy <= 1'b0;
        end else begin
            tx_state <= tx_state_next;
            tx_empty <= tx_empty_next;
            tx_busy <= tx_busy_next;
            
            if (tx_state == TX_LOAD) begin
                tx_shift_reg <= {1'b1, tx_data_latch, 1'b0}; 
                tx_bit_counter <= 4'd0;
                tx_sample_counter <= 4'd0;
            end
            
            if (tx_state == TX_SHIFT && baud_tick) begin
                tx_sample_counter <= (tx_sample_counter == 4'd15) ? 4'd0 : tx_sample_counter + 1;
                
                if (tx_sample_counter == 4'd15) begin
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]}; 
                    tx_bit_counter <= tx_bit_counter + 1;
                end
            end
            
            if (tx_load) begin
                tx_data_latch <= wb_dat_w[7:0];
            end
        end
    end
    
    logic wb_valid;
    logic wb_addr_data;
    logic wb_addr_status;
    
    assign wb_valid = wb_strb & wb_cycle;
    assign wb_addr_data = (wb_addr[2:0] == 3'b000);
    assign wb_addr_status = (wb_addr[2:0] == 3'b100);
    
    always_comb begin
        wb_ack   = 1'b0;
        wb_dat_r = 32'b0;
        tx_load  = 1'b0;
        
        if (wb_valid) begin
            wb_ack = 1'b1;
            
            if (wb_addr_data) begin
                if (wb_we) begin
                    tx_load = 1'b1;
                end else begin
                    wb_dat_r = {24'b0, rx_data};
                end
            end else if (wb_addr_status) begin
                wb_dat_r = {28'b0, rx_overflow, rx_valid, tx_busy, tx_empty};
            end
        end
    end

    assign uart_tx = tx_shift_reg[0]; 

endmodule