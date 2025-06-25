module dac_command_manager (
    input wire clk,
    input wire rst_n,
    
    // UART 인터페이스
    input wire [7:0] uart_rx_data,
    input wire uart_rx_valid,
    output reg [7:0] uart_tx_data,
    output reg uart_tx_start,
    input wire uart_tx_busy,
    
    // DAC 제어 인터페이스
    output reg [287:0] all_channel_data,
    output reg [4:0] target_channel,
    output reg [11:0] single_dac_value,
    output reg update_single_channel,
    output reg update_all_channels,
    input wire dac_busy,
    input wire update_complete,
    
    // 상태 정보
    input wire [31:0] total_updates,
    input wire [15:0] last_update_time,
    input wire [3:0] mode_switches,
    output reg [9:0] status_leds
);

    // =======================================================================
    // 명령 프로토콜 정의
    // =======================================================================
    /*
    명령 형식:
    1. 단일 채널 업데이트: [0xAA] [CH] [VAL_H] [VAL_L] [0x55]
       - CH: 채널 번호 (0-23)
       - VAL: 12비트 DAC 값 (0-4095)
    
    2. 전체 채널 업데이트: [0xBB] [DATA...] [0x55]
       - DATA: 24채널 × 12비트 = 288비트 = 36바이트
    
    3. 상태 조회: [0xCC] [0x55]
       - 응답: 현재 모든 채널 값 + 상태 정보
    
    4. 채널 읽기: [0xDD] [CH] [0x55]
       - 응답: 해당 채널의 현재 설정값
    */

    // 명령 상태 머신
    reg [3:0] cmd_state;
    reg [7:0] cmd_buffer [0:39];  // 최대 40바이트 버퍼
    reg [5:0] byte_count;
    reg [4:0] expected_length;
    
    // 채널 데이터 저장 배열 (각 채널별 12비트)
    reg [11:0] channel_values [0:23];
    
    localparam CMD_IDLE = 0,
               CMD_HEADER = 1,
               CMD_COLLECTING = 2,
               CMD_PROCESSING = 3,
               CMD_EXECUTING = 4,
               CMD_RESPONDING = 5,
               CMD_ERROR = 6;

    // =======================================================================
    // 명령 처리 상태 머신
    // =======================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_state <= CMD_IDLE;
            byte_count <= 0;
            expected_length <= 0;
            update_single_channel <= 0;
            update_all_channels <= 0;
            uart_tx_start <= 0;
            
            // 모든 채널 초기값 설정 (중간값)
            for (integer i = 0; i < 24; i = i + 1) begin
                channel_values[i] <= 12'h800;  // 2048 (중간값)
            end
            
            status_leds <= 10'b0000000001;  // 전원 표시
        end else begin
            
            // 기본값 설정
            update_single_channel <= 0;
            update_all_channels <= 0;
            uart_tx_start <= 0;
            
            case (cmd_state)
                CMD_IDLE: begin
                    status_leds[9:1] <= 9'b000000000;
                    status_leds[0] <= 1'b1;  // Ready
                    
                    if (uart_rx_valid) begin
                        cmd_buffer[0] <= uart_rx_data;
                        byte_count <= 1;
                        cmd_state <= CMD_HEADER;
                        status_leds[1] <= 1'b1;  // Receiving
                    end
                end
                
                CMD_HEADER: begin
                    case (cmd_buffer[0])
                        8'hAA: expected_length <= 5;   // 단일 채널 (5바이트)
                        8'hBB: expected_length <= 38;  // 전체 채널 (38바이트)
                        8'hCC: expected_length <= 2;   // 상태 조회 (2바이트)
                        8'hDD: expected_length <= 3;   // 채널 읽기 (3바이트)
                        default: begin
                            cmd_state <= CMD_ERROR;
                            status_leds[9] <= 1'b1;  // Error
                        end
                    endcase
                    cmd_state <= CMD_COLLECTING;
                end
                
                CMD_COLLECTING: begin
                    if (uart_rx_valid) begin
                        cmd_buffer[byte_count] <= uart_rx_data;
                        byte_count <= byte_count + 1;
                        
                        if (byte_count == expected_length - 1) begin
                            cmd_state <= CMD_PROCESSING;
                        end
                    end
                end
                
                CMD_PROCESSING: begin
                    // 종료 마커 확인
                    if (cmd_buffer[expected_length-1] == 8'h55) begin
                        case (cmd_buffer[0])
                            8'hAA: begin  // 단일 채널 업데이트
                                if (cmd_buffer[1] < 24) begin
                                    target_channel <= cmd_buffer[1];
                                    single_dac_value <= {cmd_buffer[2], cmd_buffer[3][7:4]};
                                    cmd_state <= CMD_EXECUTING;
                                    status_leds[2] <= 1'b1;  // Processing
                                end else begin
                                    cmd_state <= CMD_ERROR;
                                end
                            end
                            
                            8'hBB: begin  // 전체 채널 업데이트
                                // 36바이트 데이터를 24개 채널로 변환
                                for (integer i = 0; i < 24; i = i + 1) begin
                                    channel_values[i] <= {
                                        cmd_buffer[1 + i*3/2],
                                        cmd_buffer[2 + i*3/2][7:4]
                                    };
                                end
                                cmd_state <= CMD_EXECUTING;
                                status_leds[3] <= 1'b1;  // Bulk update
                            end
                            
                            8'hCC: begin  // 상태 조회
                                cmd_state <= CMD_RESPONDING;
                                status_leds[4] <= 1'b1;  // Status query
                            end
                            
                            8'hDD: begin  // 채널 읽기
                                if (cmd_buffer[1] < 24) begin
                                    target_channel <= cmd_buffer[1];
                                    cmd_state <= CMD_RESPONDING;
                                    status_leds[5] <= 1'b1;  // Channel read
                                end else begin
                                    cmd_state <= CMD_ERROR;
                                end
                            end
                        endcase
                    end else begin
                        cmd_state <= CMD_ERROR;
                        status_leds[9] <= 1'b1;  // Protocol error
                    end
                end
                
                CMD_EXECUTING: begin
                    if (!dac_busy) begin
                        case (cmd_buffer[0])
                            8'hAA: begin  // 단일 채널
                                channel_values[target_channel] <= single_dac_value;
                                update_single_channel <= 1;
                            end
                            
                            8'hBB: begin  // 전체 채널
                                // all_channel_data 구성
                                for (integer i = 0; i < 24; i = i + 1) begin
                                    all_channel_data[i*12 +: 12] <= channel_values[i];
                                end
                                update_all_channels <= 1;
                            end
                        endcase
                        status_leds[6] <= 1'b1;  // Executing
                    end
                    
                    if (update_complete) begin
                        cmd_state <= CMD_IDLE;
                        status_leds[7] <= 1'b1;  // Complete
                    end
                end
                
                CMD_RESPONDING: begin
                    // UART 응답 전송 로직
                    if (!uart_tx_busy) begin
                        case (cmd_buffer[0])
                            8'hCC: begin  // 상태 응답
                                uart_tx_data <= total_updates[7:0];
                                uart_tx_start <= 1;
                            end
                            
                            8'hDD: begin  // 채널 값 응답
                                uart_tx_data <= channel_values[target_channel][11:4];
                                uart_tx_start <= 1;
                            end
                        endcase
                        cmd_state <= CMD_IDLE;
                    end
                end
                
                CMD_ERROR: begin
                    status_leds[9:8] <= 2'b11;  // Error indication
                    // 에러 상태에서 복구
                    if (uart_rx_valid && uart_rx_data == 8'h00) begin
                        cmd_state <= CMD_IDLE;
                        status_leds[9:8] <= 2'b00;
                    end
                end
            endcase
        end
    end

endmodule