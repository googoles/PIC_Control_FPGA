// led_controller.sv
module led_controller (
    input wire         clk,             // System clock
    input wire         rst_n,           // Active-low reset
    input wire  [7:0]  received_data,   // Data from UART receiver
    input wire         data_valid,      // Signal that new data is available

    output reg  [9:0]  ledr_out         // Output to the 10 Red LEDs (LEDR[9:0])
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ledr_out <= 10'b0; // All LEDs off on reset
        end else begin
            if (data_valid) begin
                case (received_data)
                    8'h31: begin // ASCII '1' received
                        ledr_out[0] <= 1'b1; // Turn on LEDR[0]
                    end
                    8'h30: begin // ASCII '0' received
                        ledr_out[0] <= 1'b0; // Turn off LEDR[0]
                    end
                    // Add more cases for other LEDs if needed
                    // For example, to turn on LEDR[1] with '2' (0x32):
                    // 8'h32: begin ledr_out[1] <= 1'b1; end
                    // To turn off LEDR[1] with '3' (0x33):
                    // 8'h33: begin ledr_out[1] <= 1'b0; end
                    default: begin
                        // Do nothing for other characters, or implement specific behavior
                    end
                endcase
            end
        end
    end

endmodule