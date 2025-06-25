// de10_standard_uart_led_top.v - 깔끔한 UART + LED 제어 시스템
module de10_standard_uart_led_top (
    // 시스템 신호
    input  wire        CLOCK_50,      // 50MHz 시스템 클럭
    input  wire        KEY0,          // 리셋 버튼 (액티브 로우)
    
    // UART 신호
    input  wire        GPIO_0_RX_DATA, // UART RX (GPIO_0 pin 0)
    output wire        GPIO_0_TX_DATA, // UART TX (GPIO_0 pin 1)
    
    // LED 출력
    output wire [9:0]  LEDR           // Red LEDs
);

// ============================================================================
// 내부 신호 선언
// ============================================================================
wire        rst_n;                    // 내부 리셋 신호
wire [7:0]  rx_data;                  // UART RX 데이터
wire        rx_valid;                 // UART RX 유효 신호
wire        tx_busy;                  // UART TX 비지 신호
reg         tx_start;                 // UART TX 시작 신호
reg  [7:0]  tx_data;                  // UART TX 데이터

// 디버깅용 신호 (Signal Tap에서 관찰)
wire [2:0]  rx_debug_state;
wire [4:0]  rx_debug_bit_cnt;
wire [8:0]  rx_debug_clk_cnt;
wire [2:0]  tx_debug_state;
wire [4:0]  tx_debug_bit_cnt;
wire [8:0]  tx_debug_clk_cnt;

// ============================================================================
// 리셋 신호 처리
// ============================================================================
assign rst_n = KEY0;  // KEY0를 누르면 리셋 (액티브 로우)

// ============================================================================
// UART RX 모듈 인스턴스
// ============================================================================
uart_rx u_uart_rx (
    .clk           (CLOCK_50),
    .rst_n         (rst_n),
    .uart_rx_in    (GPIO_0_RX_DATA),
    .rx_data       (rx_data),
    .rx_valid      (rx_valid),
    .debug_state   (rx_debug_state),
    .debug_bit_cnt (rx_debug_bit_cnt),
    .debug_clk_cnt (rx_debug_clk_cnt)
);

// ============================================================================
// UART TX 모듈 인스턴스
// ============================================================================
uart_tx u_uart_tx (
    .clk           (CLOCK_50),
    .rst_n         (rst_n),
    .tx_data       (tx_data),
    .tx_start      (tx_start),
    .uart_tx_out   (GPIO_0_TX_DATA),
    .tx_busy       (tx_busy),
    .debug_state   (tx_debug_state),
    .debug_bit_cnt (tx_debug_bit_cnt),
    .debug_clk_cnt (tx_debug_clk_cnt)
);

// ============================================================================
// LED 컨트롤러 모듈 인스턴스
// ============================================================================
led_controller u_led_controller (
    .clk      (CLOCK_50),
    .rst_n    (rst_n),
    .rx_data  (rx_data),
    .rx_valid (rx_valid),
    .led_out  (LEDR)
);

// ============================================================================
// UART TX 에코백 로직
// ============================================================================
always @(posedge CLOCK_50 or negedge rst_n) begin
    if (!rst_n) begin
        tx_start <= 1'b0;
        tx_data  <= 8'h00;
    end else begin
        // 기본값
        tx_start <= 1'b0;
        
        // 새로운 데이터가 수신되고 TX가 바쁘지 않을 때 에코백
        if (rx_valid && !tx_busy) begin
            tx_data  <= rx_data;  // 받은 데이터를 그대로 에코백
            tx_start <= 1'b1;    // TX 시작
        end
    end
end

endmodule