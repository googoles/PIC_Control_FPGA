// de10_standard_uart_led_top.v
module de10_standard_uart_led_top (
    input wire CLOCK_50,        // 50MHz clock from DE10-Standard
    input wire KEY0,            // Push button KEY[0] for reset (active-low)
    input wire GPIO_0_RX_DATA,  // GPIO_0[0] for UART RX (connect this to your UART input)
    output wire [9:0] LEDR      // Red LEDs on DE10-Standard
);

    // Internal wires to connect modules
    // These wires carry data from uart_rx to led_controller
    wire [7:0] received_data_internal_wire; // Connects received_byte from uart_rx to received_data of led_controller
    wire       rx_data_valid_internal_wire; // Connects rx_data_valid from uart_rx to data_valid of led_controller
    
    // Internal wire for reset (active-low)
    wire       rst_n;

    // Use KEY[0] as active-low reset
    // KEY0 is directly connected to a push button, which is typically active-low.
    assign rst_n = ~KEY0;

    // Instantiate UART Receiver Module
    // The name 'inst2' in your diagram corresponds to this instance
    uart_rx u_uart_rx ( // 'u_uart_rx' is the instance name, you can choose any valid identifier
        .clk(CLOCK_50),                  // Connect the system clock
        .rst_n(rst_n),                   // Connect the active-low reset
        .uart_rx_in(GPIO_0_RX_DATA),     // Connect the UART RX input from the top-level port
        .received_byte(received_data_internal_wire), // Output received byte to internal wire
        .rx_data_valid(rx_data_valid_internal_wire)  // Output data valid signal to internal wire
    );

    // Instantiate LED Controller Module
    // The name 'inst' in your diagram corresponds to this instance
    led_controller u_led_controller ( // 'u_led_controller' is the instance name
        .clk(CLOCK_50),                       // Connect the system clock
        .rst_n(rst_n),                        // Connect the active-low reset
        .received_data(received_data_internal_wire), // Input received data from internal wire
        .data_valid(rx_data_valid_internal_wire),    // Input data valid signal from internal wire
        .ledr_out(LEDR)                       // Output LED state to the top-level LEDR port
    );

    // Note: This design is receive-only. If you need UART TX for debugging or echoing,
    // you would add a uart_tx module and assign a GPIO pin to its output.
    // For simplicity, we are not adding UART TX in this example.

endmodule