module wb_uart (
    // for the basys3 fpga the clk is 100mhz
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

    parameter BAUD_DIVIDER = 54; // for 115200 baud rate
    
    logic [7:0] baud_counter;
    logic       baud_tick;
    
    // clock dividers are really bad if written poorly, you want to still
    // drive using the master clk in the sensitivity list but use the 
    // tick as an enable pin to ensure it stays on global clock tree
    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            baud_counter <= 8'b0;
            baud_tick    <= 1'b0;
        end else begin
            if (baud_counter == BAUD_DIVIDER-1) begin
                baud_counter <= 8'b0;
                baud_tick    <= 1'b1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick    <= 1'b0;
            end
        end
    end
    
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

    // state machine process
    always_comb begin
        rx_state_next   = rx_state;
        rx_valid_next   = rx_valid;
        rx_overflow_next = rx_overflow;
        
        case (rx_state) 
            RX_IDLE: begin
                if (!uart_rx) begin
                    rx_state_next = RX_START;
                end
            end
            RX_START: begin
                // oversample by 16 bits to check if we have stable level
                if (baud_tick && rx_sample_counter == 4'd15) begin
                    rx_state_next = RX_SHIFT;
                end
            end
            RX_SHIFT: begin
                // after 8 bits (a full byte) move to stop
                if (baud_tick && rx_bit_counter == 4'd8) begin
                    rx_state_next = RX_STOP;
                end
            end
            RX_STOP: begin
                // after 16 ticks (stop bit period), return to idle
                if (baud_tick && rx_sample_counter == 4'd15) begin
                    if (uart_rx) begin
                        // valid stop bit detected
                        rx_valid_next = 1'b1;
                    end
                    rx_state_next = RX_IDLE;
                end
                
                // overflow: new start bit while byte still valid
                if (!uart_rx && rx_valid) begin
                    rx_overflow_next = 1'b1;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n)
            rx_state <= RX_IDLE;
        else
            rx_state <= rx_state_next; 
    end

    // define actual rx assignments here
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_sample_counter <= 4'd0;
            rx_bit_counter <= 4'd0;
            rx_shift_reg <= 8'b0;
            rx_data <= 8'b0;
            rx_valid <= 1'b0;
            rx_overflow <= 1'b0;
        end else begin
            // sample counter ticks on every baud_tick
            if (baud_tick) begin
                rx_sample_counter <= (rx_sample_counter == 4'd15) ? 4'd0 : rx_sample_counter + 1;
            end
            
            // shift in data on sample 8 of each bit period
            if (baud_tick && rx_sample_counter == 4'd8 && rx_state == RX_SHIFT) begin
                rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};  // LSB first
                rx_bit_counter <= rx_bit_counter + 1;
            end
            
            // latch rx_data when byte complete
            if (rx_state == RX_STOP && baud_tick && rx_sample_counter == 4'd15) begin
                rx_data <= rx_shift_reg;
            end
            
            // clear rx_valid after 1 cycle
            if (rx_valid) begin
                rx_valid <= 1'b0;
            end
            
            // update state from FSM
            rx_valid <= rx_valid_next;
            rx_overflow <= rx_overflow_next;
        end
    end
    
    logic [9:0]  tx_shift_reg;  
    logic [3:0]  tx_bit_counter;
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
                if (tx_load) tx_state_next = TX_LOAD;
            end
            TX_LOAD: begin

            end
            TX_SHIFT: begin

            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n)
            tx_state <= TX_IDLE;
        else
            tx_state <= tx_state_next; 
    end
    
    // actual assignments
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            
        end
    end
    
    // decode wishbone interface
    logic wb_valid       = wb_strb & wb_cycle;
    logic wb_addr_data   = (wb_addr[2:0] == 3'b000);
    logic wb_addr_status = (wb_addr[2:0] == 3'b100);
    
    always_comb begin
        wb_ack   = 1'b0;
        wb_dat_r = 32'b0;
        tx_load  = 1'b0;

        if (wb_valid) begin
            if (wb_addr_data) begin
                if (wb_we) begin
                    tx_load = 1'b1;
                end else begin
                    wb_dat_r = {24'b0, rx_data};
                end
                wb_ack = 1'b1;
            end else if (wb_addr_status) begin
                wb_dat_r = {28'b0, rx_overflow, rx_valid, tx_busy, tx_empty};
                wb_ack   = 1'b1;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_state   <= RX_IDLE;
            rx_valid   <= 1'b0;
            rx_overflow <= 1'b0;
            rx_data    <= 8'b0;
            tx_state   <= TX_IDLE;
            tx_empty   <= 1'b1;
            tx_busy    <= 1'b0;
            tx_shift_reg <= 10'b1111111111; // idle state
            baud_counter <= 8'b0;
        end else begin
            rx_state   <= rx_state_next;
            rx_valid   <= rx_valid_next;
            rx_overflow <= rx_overflow_next;
            tx_state   <= tx_state_next;
            tx_empty   <= tx_empty_next;
            tx_busy    <= tx_busy_next;
            
            // TODO: implement baud counter update
            // TODO: implement rx/tx shift register updates
        end
    end
    
    assign uart_tx = tx_shift_reg[0]; // LSB on wire

endmodule