// uart_rx.v - 타이밍 수정된 115200 baud RX 모듈
module uart_rx (
    input  wire        clk,           // 50MHz 시스템 클럭
    input  wire        rst_n,         // 액티브 로우 리셋
    input  wire        uart_rx_in,    // UART 입력 신호
    
    output reg  [7:0]  rx_data,       // 수신된 8비트 데이터
    output reg         rx_valid,      // 데이터 유효 신호 (1 클럭 펄스)
    
    // 디버깅용 출력
    output wire [2:0]  debug_state,   // 현재 상태
    output wire [4:0]  debug_bit_cnt, // 비트 카운터
    output wire [15:0] debug_clk_cnt  // 클럭 카운터 (16비트로 확장)
);

// ============================================================================
// 수정된 파라미터 정의
// ============================================================================
localparam CLK_PER_BIT = 434;         // 50MHz / 115200 = 434.03 ≈ 434
localparam CLK_PER_HALF_BIT = 217;    // 비트 중앙 샘플링용 (434/2)

// 상태 정의
localparam IDLE       = 3'b000;
localparam START_BIT  = 3'b001;
localparam DATA_BITS  = 3'b010;
localparam STOP_BIT   = 3'b011;
localparam CLEANUP    = 3'b100;

// ============================================================================
// 내부 신호
// ============================================================================
reg [2:0]  state;
reg [15:0] clk_count;    // 0~433 카운트 (16비트로 확장)
reg [4:0]  bit_index;    // 0~7 비트 인덱스
reg [7:0]  rx_byte;      // 수신 중인 바이트

// 디버깅 신호 연결
assign debug_state   = state;
assign debug_bit_cnt = bit_index;
assign debug_clk_cnt = clk_count;

// ============================================================================
// 메인 로직
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= IDLE;
        clk_count <= 16'd0;
        bit_index <= 5'd0;
        rx_byte   <= 8'd0;
        rx_data   <= 8'd0;
        rx_valid  <= 1'b0;
    end else begin
        // 기본값
        rx_valid <= 1'b0;
        
        case (state)
            // ================================================================
            // IDLE: start bit (falling edge) 대기
            // ================================================================
            IDLE: begin
                clk_count <= 16'd0;
                bit_index <= 5'd0;
                
                if (uart_rx_in == 1'b0) begin  // start bit 감지
                    state <= START_BIT;
                    clk_count <= 16'd0;
                end
            end
            
            // ================================================================
            // START_BIT: start bit 중앙에서 검증
            // ================================================================
            START_BIT: begin
                if (clk_count == CLK_PER_HALF_BIT) begin  // start bit 중앙
                    if (uart_rx_in == 1'b0) begin  // start bit 유효
                        clk_count <= 16'd0;
                        state <= DATA_BITS;
                    end else begin  // 잘못된 start bit
                        state <= IDLE;
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            // ================================================================
            // DATA_BITS: 8개 데이터 비트 수신 (LSB first)
            // ================================================================
            DATA_BITS: begin
                if (clk_count == CLK_PER_BIT) begin  // 비트 중앙에서 샘플링
                    clk_count <= 16'd0;
                    rx_byte[bit_index] <= uart_rx_in;  // 현재 비트 저장
                    
                    if (bit_index == 7) begin  // 8비트 모두 수신
                        bit_index <= 5'd0;
                        state <= STOP_BIT;
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            // ================================================================
            // STOP_BIT: stop bit 검증
            // ================================================================
            STOP_BIT: begin
                if (clk_count == CLK_PER_BIT) begin
                    if (uart_rx_in == 1'b1) begin  // 유효한 stop bit
                        rx_data  <= rx_byte;     // 데이터 출력
                        rx_valid <= 1'b1;       // 유효 신호 어서트
                    end
                    state <= CLEANUP;
                    clk_count <= 16'd0;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            // ================================================================
            // CLEANUP: 다음 프레임을 위한 정리
            // ================================================================
            CLEANUP: begin
                if (clk_count == CLK_PER_BIT) begin
                    state <= IDLE;
                    clk_count <= 16'd0;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule