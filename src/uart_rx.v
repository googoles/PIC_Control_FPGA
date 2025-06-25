// uart_rx.v - Start bit 감지 로직 수정
module uart_rx (
    input wire         clk,         // 50MHz system clock
    input wire         rst_n,       // Active-low asynchronous reset
    input wire         uart_rx_in,  // Incoming UART data line

    output reg  [7:0]  received_byte, // Output for the received 8-bit data
    output reg         rx_data_valid  // High for one clock cycle when a byte is received
);

    // --- Parameters ---
    localparam BAUD_RATE_CLOCK_DIV = 27; // 50MHz / (115200 * 16) = 27.126 -> 27
    localparam OVERSAMPLE_FACTOR   = 16; // 16 samples per bit

    // --- Internal States and Registers ---
    reg [3:0]   bit_count;        // Counts 0 to 9 (start, 8 data, stop bits)
    reg [4:0]   sample_count;     // Counts samples within a bit time
    reg         rx_state;         // 0: IDLE, 1: RECEIVING_BITS
    reg [7:0]   rx_shift_reg;     // Stores incoming data bits
    
    // Start bit 감지를 위한 추가 신호
    reg uart_rx_prev;             // 이전 클럭의 uart_rx_in 값
    wire start_bit_detected;      // Start bit 감지 신호
    
    // Start bit 감지: HIGH -> LOW 전환 감지
    assign start_bit_detected = uart_rx_prev && !uart_rx_in;

    // --- Main Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state        <= 1'b0;
            bit_count       <= 4'b0;
            sample_count    <= 5'b0;
            rx_shift_reg    <= 8'b0;
            received_byte   <= 8'b0;
            rx_data_valid   <= 1'b0;
            uart_rx_prev    <= 1'b1; // UART idle state is HIGH
        end else begin
            // 이전 값 저장
            uart_rx_prev <= uart_rx_in;
            
            rx_data_valid <= 1'b0; // Default to low

            case (rx_state)
                1'b0: begin // IDLE state
                    if (start_bit_detected) begin // Start bit 감지됨
                        rx_state     <= 1'b1;                      // Move to receiving state
                        sample_count <= (BAUD_RATE_CLOCK_DIV * (OVERSAMPLE_FACTOR / 2)) - 1; // Sample in the middle of the start bit
                        bit_count    <= 4'b0;                     // Reset bit counter
                    end
                end
                
                1'b1: begin // RECEIVING_BITS state
                    if (sample_count == 0) begin // End of a sample period
                        sample_count <= BAUD_RATE_CLOCK_DIV - 1; // Reset sample counter for next bit

                        if (bit_count < 10) begin // Receiving start, 8 data, and stop bits
                            if (bit_count == 0) begin // Start bit processing
                                // Start bit 검증 (여전히 LOW인지 확인)
                                if (uart_rx_in == 1'b0) begin
                                    bit_count <= bit_count + 1; // Valid start bit
                                end else begin
                                    rx_state <= 1'b0; // Invalid start bit, go back to IDLE
                                end
                            end else if (bit_count >= 1 && bit_count <= 8) begin // Data bits (D0 to D7)
                                rx_shift_reg[bit_count - 1] <= uart_rx_in; // Store data bits (LSB first)
                                bit_count <= bit_count + 1;
                            end else if (bit_count == 9) begin // Stop bit
                                if (uart_rx_in == 1'b1) begin // Stop bit must be high
                                    received_byte <= rx_shift_reg; // Output received byte
                                    rx_data_valid <= 1'b1;                 // Assert data valid
                                end
                                rx_state <= 1'b0; // Go back to IDLE
                            end
                        end
                    end else begin
                        sample_count <= sample_count - 1; // Decrement sample counter
                    end
                end
            endcase
        end
    end

endmodule