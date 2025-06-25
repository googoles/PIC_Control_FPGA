// de10_standard_uart_led_top.v
module de10_standard_uart_led_top (
    input wire CLOCK_50,        // 50MHz clock from DE10-Standard
    input wire KEY0,            // Push button KEY[0] for reset (active-low)
    input wire GPIO_0_RX_DATA,  // GPIO_0[0] for UART RX (connect this to your UART input)
    output wire GPIO_0_TX_DATA, // NEW: GPIO_0[1] for UART TX (connect this to your UART output)
    output wire [9:0] LEDR      // Red LEDs on DE10-Standard
);

    // Internal wires to connect modules
    wire [7:0] received_data_internal_wire; // Data from uart_rx to led_controller and uart_tx
    wire       rx_data_valid_internal_wire; // Data valid signal from uart_rx
    wire       rst_n;

    // For UART TX control
    reg        tx_start_reg;     // Signal to start TX
    wire       tx_busy_wire;     // TX busy signal from uart_tx

    assign rst_n = ~KEY0;

    // Instantiate UART Receiver Module
    uart_rx u_uart_rx (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .uart_rx_in(GPIO_0_RX_DATA),
        .received_byte(received_data_internal_wire),
        .rx_data_valid(rx_data_valid_internal_wire)
    );

    // Instantiate LED Controller Module
    led_controller u_led_controller (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .received_data(received_data_internal_wire),
        .data_valid(rx_data_valid_internal_wire),
        .ledr_out(LEDR)
    );

    // Instantiate UART Transmitter Module
    uart_tx u_uart_tx (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .tx_data(received_data_internal_wire), // Transmit the received data
        .tx_start(tx_start_reg),             // Start TX when data is valid and not busy
        .uart_tx_out(GPIO_0_TX_DATA),        // Connect to a general purpose I/O pin for UART TX
        .tx_busy(tx_busy_wire)
    );

    // Logic to trigger UART TX: Echo the received data
    // When new data is valid AND the TX module is not busy, start transmission.
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            tx_start_reg <= 1'b0;
        end else begin
            // tx_start_reg should be a single clock pulse
            if (rx_data_valid_internal_wire && !tx_busy_wire) begin
                tx_start_reg <= 1'b1;
            end else begin
                tx_start_reg <= 1'b0;
            end
        end
    end

endmodule