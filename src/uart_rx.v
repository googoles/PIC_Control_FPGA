// uart_rx.sv
module uart_rx (
    input wire         clk,         // 50MHz system clock
    input wire         rst_n,       // Active-low asynchronous reset
    input wire         uart_rx_in,  // Incoming UART data line

    output reg  [7:0]  received_byte, // Output for the received 8-bit data
    output reg         rx_data_valid  // High for one clock cycle when a byte is received
);

    // --- Parameters ---
    // Assuming 50MHz clock frequency
    // Baud Rate: 115200 bps
    // CLK_FREQ / BAUD_RATE = 50,000,000 / 115200 = 434.027...
    // For sampling the center of each bit, we use oversampling (e.g., 8 or 16 times the baud rate).
    // Here we'll use a simple approach for demonstration, sampling once per bit at its center.
    // To achieve sampling at the center, the counter should reach CLK_PER_BIT-1 at the end of a bit.
    // For 16x oversampling: CLK_PER_BIT_16X = CLK_FREQ / (BAUD_RATE * 16) = 50,000,000 / (115200 * 16) = 27.126... -> use 27
    localparam BAUD_RATE_CLOCK_DIV = 27; // For 16x oversampling at 115200 baud (50MHz / 115200 / 16)
    localparam OVERSAMPLE_FACTOR   = 16; // 16 samples per bit

    // --- Internal States and Registers ---
    reg [3:0]   bit_count;        // Counts 0 to 9 (start, 8 data, stop bits)
    reg [4:0]   sample_count;     // Counts samples within a bit time
    reg         rx_state;         // 0: IDLE, 1: RECEIVING_BITS

    reg [9:0]   rx_shift_reg;     // Stores incoming bits: [start_bit, D0, D1, ..., D7, stop_bit]

    // --- Main Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state        <= 0;
            bit_count       <= 0;
            sample_count    <= 0;
            rx_shift_reg    <= 0;
            received_byte   <= 0;
            rx_data_valid   <= 0;
        end else begin
            rx_data_valid <= 0; // Default to low

            case (rx_state)
                0: begin // IDLE state
                    if (!uart_rx_in) begin // Detect falling edge for start bit
                        rx_state     <= 1;                      // Move to receiving state
                        sample_count <= BAUD_RATE_CLOCK_DIV * (OVERSAMPLE_FACTOR / 2) -1 ; // Sample in the middle of the start bit
                        bit_count    <= 0;                     // Reset bit counter
                    end
                end
                1: begin // RECEIVING_BITS state
                    if (sample_count == 0) begin // End of a sample period
                        sample_count <= BAUD_RATE_CLOCK_DIV - 1; // Reset sample counter for next bit

                        if (bit_count < 10) begin // Receiving start, 8 data, and stop bits
                            if (bit_count == 0) begin // Start bit processing
                                // Do nothing, just consume the start bit.
                                // In a robust design, you'd check if it's still low here.
                            end else if (bit_count >= 1 && bit_count <= 8) begin // Data bits (D0 to D7)
                                rx_shift_reg[bit_count - 1] <= uart_rx_in; // Store data bits
                            end else if (bit_count == 9) begin // Stop bit
                                if (uart_rx_in) begin // Stop bit must be high
                                    received_byte <= rx_shift_reg[7:0]; // Output received byte
                                    rx_data_valid <= 1;                 // Assert data valid
                                end
                                rx_state <= 0; // Go back to IDLE
                            end
                            bit_count <= bit_count + 1; // Move to next bit
                        end
                    end else begin
                        sample_count <= sample_count - 1; // Decrement sample counter
                    end
                end
            endcase
        end
    end

endmodule