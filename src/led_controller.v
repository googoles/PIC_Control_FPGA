// led_controller.v - 디버깅 강화 버전
module led_controller (
    input  wire        clk,           // 시스템 클럭
    input  wire        rst_n,         // 액티브 로우 리셋
    input  wire [7:0]  rx_data,       // UART에서 받은 데이터
    input  wire        rx_valid,      // 데이터 유효 신호
    
    output reg  [9:0]  led_out,       // LED 출력 (LEDR[9:0])
    
    // 디버깅용 출력 추가
    output reg  [7:0]  debug_last_rx, // 마지막 수신 데이터
    output reg         debug_u_match, // 'U' 매치 여부
    output reg         debug_0_match, // '0' 매치 여부
    output reg         debug_default  // default case 실행 여부
);

// ============================================================================
// ASCII 코드 정의 (명시적으로 8비트 크기 지정)
// ============================================================================
localparam [7:0] ASCII_U = 8'h55;  // 'U' = 0x55 = 01010101
localparam [7:0] ASCII_0 = 8'h30;  // '0' = 0x30 = 00110000  
localparam [7:0] ASCII_1 = 8'h31;  // '1' = 0x31 = 00110001
localparam [7:0] ASCII_A = 8'h41;  // 'A' = 0x41 = 01000001
localparam [7:0] ASCII_a = 8'h61;  // 'a' = 0x61 = 01100001

// ============================================================================
// 메인 로직
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        led_out <= 10'b0000000000;  // 모든 LED OFF
        debug_last_rx <= 8'h00;
        debug_u_match <= 1'b0;
        debug_0_match <= 1'b0;
        debug_default <= 1'b0;
    end else begin
        // 디버깅 신호 초기화
        debug_u_match <= 1'b0;
        debug_0_match <= 1'b0;
        debug_default <= 1'b0;
        
        if (rx_valid) begin  // 유효한 데이터 수신됨
            debug_last_rx <= rx_data;  // 마지막 수신 데이터 저장
            
            case (rx_data)
                // --------------------------------------------------------
                // 특별 명령어들
                // --------------------------------------------------------
                ASCII_U: begin  // 'U' (0x55) - 테스트용 패턴
                    led_out <= 10'b0101010101;  // 교대로 켜기 (LEDR[0,2,4,6,8] ON)
                    debug_u_match <= 1'b1;     // 'U' 매치됨
                end
                
                ASCII_0: begin  // '0' - 모든 LED OFF
                    led_out <= 10'b0000000000;
                    debug_0_match <= 1'b1;     // '0' 매치됨
                end
                
                ASCII_1: begin  // '1' - 모든 LED ON
                    led_out <= 10'b1111111111;
                end
                
                ASCII_A: begin  // 'A' - 하위 5개 LED ON
                    led_out <= 10'b0000011111;
                end
                
                ASCII_a: begin  // 'a' - 상위 5개 LED ON  
                    led_out <= 10'b1111100000;
                end
                
                // --------------------------------------------------------
                // 개별 LED 제어 (숫자 2~9)
                // --------------------------------------------------------
                8'h32: begin  // '2' - LED[1] toggle
                    led_out[1] <= ~led_out[1];
                end
                
                8'h33: begin  // '3' - LED[2] toggle
                    led_out[2] <= ~led_out[2];
                end
                
                // --------------------------------------------------------
                // 기본: 받은 데이터를 하위 8개 LED에 표시
                // --------------------------------------------------------
                default: begin
                    led_out[7:0] <= rx_data;     // 하위 8개 LED에 데이터 표시
                    led_out[9:8] <= 2'b00;       // 상위 2개 LED는 OFF
                    debug_default <= 1'b1;      // default case 실행됨
                end
            endcase
        end
    end
end

endmodule