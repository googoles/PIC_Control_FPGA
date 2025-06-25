// uart_tx.v - 115200 baud, 깔끔한 구현
module uart_tx (
    input  wire        clk,           // 50MHz 시스템 클럭
    input  wire        rst_n,         // 액티브 로우 리셋
    input  wire [7:0]  tx_data,       // 전송할 8비트 데이터
    input  wire        tx_start,      // 전송 시작 신호 (1 클럭 펄스)
    
    output reg         uart_tx_out,   // UART 출력 신호
    output reg         tx_busy,       // 전송 중 신호
    
    // 디버깅용 출력
    output wire [2:0]  debug_state,   // 현재 상태
    output wire [4:0]  debug_bit_cnt, // 비트 카운터
    output wire [8:0]  debug_clk_cnt  // 클럭 카운터
);

// ============================================================================
// 파라미터 정의
// ============================================================================
localparam CLK_PER_BIT = 434;         // 50MHz / 115200 = 434.03 ≈ 434

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
reg [8:0]  clk_count;    // 0~433 카운트
reg [4:0]  bit_index;    // 0~7 비트 인덱스
reg [7:0]  tx_byte;      // 전송 중인 바이트

// 디버깅 신호 연결
assign debug_state   = state;
assign debug_bit_cnt = bit_index;
assign debug_clk_cnt = clk_count;

// ============================================================================
// 메인 로직
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state       <= IDLE;
        clk_count   <= 9'd0;
        bit_index   <= 5'd0;
        tx_byte     <= 8'd0;
        uart_tx_out <= 1'b1;        // UART idle = HIGH
        tx_busy     <= 1'b0;
    end else begin
        
        case (state)
            // ================================================================
            // IDLE: 전송 시작 대기
            // ================================================================
            IDLE: begin
                uart_tx_out <= 1'b1;    // idle state = HIGH
                tx_busy     <= 1'b0;
                clk_count   <= 9'd0;
                bit_index   <= 5'd0;
                
                if (tx_start) begin      // 전송 시작
                    tx_byte <= tx_data;  // 데이터 래치
                    state   <= START_BIT;
                    tx_busy <= 1'b1;
                end
            end
            
            // ================================================================
            // START_BIT: start bit (LOW) 전송
            // ================================================================
            START_BIT: begin
                uart_tx_out <= 1'b0;    // start bit = LOW
                
                if (clk_count == CLK_PER_BIT - 1) begin
                    clk_count <= 9'd0;
                    state     <= DATA_BITS;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            // ================================================================
            // DATA_BITS: 8개 데이터 비트 전송 (LSB first)
            // ================================================================
            DATA_BITS: begin
                uart_tx_out <= tx_byte[bit_index];  // 현재 비트 출력
                
                if (clk_count == CLK_PER_BIT - 1) begin
                    clk_count <= 9'd0;
                    
                    if (bit_index == 7) begin        // 8비트 모두 전송
                        bit_index <= 5'd0;
                        state     <= STOP_BIT;
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            // ================================================================
            // STOP_BIT: stop bit (HIGH) 전송
            // ================================================================
            STOP_BIT: begin
                uart_tx_out <= 1'b1;    // stop bit = HIGH
                
                if (clk_count == CLK_PER_BIT - 1) begin
                    clk_count <= 9'd0;
                    state     <= CLEANUP;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end
            
            // ================================================================
            // CLEANUP: 전송 완료, idle로 복귀 준비
            // ================================================================
            CLEANUP: begin
                uart_tx_out <= 1'b1;    // idle state = HIGH
                tx_busy     <= 1'b0;
                state       <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule