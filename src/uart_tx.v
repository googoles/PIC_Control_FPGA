// uart_tx.v
module uart_tx (
    input wire         clk,           // 50MHz system clock
    input wire         rst_n,         // Active-low asynchronous reset
    input wire  [7:0]  tx_data,       // Data to be transmitted
    input wire         tx_start,      // Pulse high for one clock cycle to start transmission

    output reg         uart_tx_out,   // Outgoing UART data line
    output reg         tx_busy        // High when transmission is in progress
);

    // --- Parameters ---
    // Same as uart_rx, for 115200 baud at 50MHz clock, 16x oversampling
    localparam BAUD_RATE_CLOCK_DIV = 27; // 50,000,000 / (115200 * 16) = 27.126 -> use 27
    localparam OVERSAMPLE_FACTOR   = 16; // 16 samples per bit

    // --- Internal States and Registers ---
    reg [3:0]   bit_count;        // Counts 0 to 9 (start, 8 data, stop bits)
    reg [4:0]   sample_count;     // Counts samples within a bit time
    reg         tx_state;         // 0: IDLE, 1: SENDING_BITS

    reg [9:0]   tx_shift_reg;     // Stores bits to send: [start_bit, D0, ..., D7, stop_bit]

    // State machine for transmission
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state        <= 0;
            bit_count       <= 0;
            sample_count    <= 0;
            uart_tx_out     <= 1'b1; // UART TX idle is High
            tx_busy         <= 1'b0;
        end else begin
            tx_busy <= (tx_state == 1); // Indicate busy when sending

            case (tx_state)
                0: begin // IDLE state
                    uart_tx_out <= 1'b1; // Keep TX line high in idle
                    if (tx_start) begin // Start transmission
                        tx_state     <= 1;
                        bit_count    <= 0;
                        sample_count <= BAUD_RATE_CLOCK_DIV - 1; // Start at the beginning of the first bit
                        // Load the shift register: [stop_bit, D7, ..., D0, start_bit]
                        // Note: Bit order is LSB first for UART.
                        tx_shift_reg <= {1'b1, tx_data, 1'b0}; // {Stop_Bit, Data[7:0], Start_Bit}
                    end
                end
                1: begin // SENDING_BITS state
                    if (sample_count == 0) begin // End of a sample period (time to send next bit)
                        sample_count <= BAUD_RATE_CLOCK_DIV - 1; // Reset sample counter

                        if (bit_count < 10) begin // Send 10 bits (start, 8 data, stop)
                            uart_tx_out <= tx_shift_reg[bit_count]; // Output current bit
                            bit_count   <= bit_count + 1;           // Move to next bit
                        end else begin // All bits sent
                            tx_state <= 0; // Go back to IDLE
                        end
                    end else begin
                        sample_count <= sample_count - 1; // Decrement sample counter
                    end
                end
            endcase
        end
    end

endmodule