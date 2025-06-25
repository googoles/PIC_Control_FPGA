module mcp4922_24ch_controller_top (
    // FPGA 기본 신호
    input wire CLOCK_50,           // 50MHz 시스템 클럭
    input wire KEY0,               // 리셋 버튼 (active low)
    
    // UART 통신
    input wire GPIO_0_RX_DATA,     // UART 수신
    output wire GPIO_0_TX_DATA,    // UART 송신 (상태 피드백용)
    
    // MCP4922 SPI 인터페이스
    output wire DAC_SCK,           // 공통 SPI 클럭
    output wire DAC_SDI,           // 공통 SPI 데이터
    output wire [11:0] DAC_CS,     // 개별 칩 선택 (12개)
    output wire DAC_LDAC,          // 공통 LDAC (동기화용)
    
    // 상태 표시 LED
    output wire [9:0] LEDR,        // 상태 LED
    
    // 추가 제어 신호
    output wire DAC_RESET,         // DAC 리셋 (옵션)
    input wire [3:0] SW            // 스위치 입력 (모드 선택)
);

    // 내부 신호 정의
    wire rst_n = ~KEY0;
    
    // UART 관련 신호
    wire [7:0] uart_rx_data;
    wire uart_rx_valid;
    wire [7:0] uart_tx_data;
    wire uart_tx_start;
    wire uart_tx_busy;
    
    // DAC 제어 신호
    wire [287:0] all_channel_data;  // 24ch × 12bit = 288bit
    wire [4:0] target_channel;      // 0-23 채널 선택
    wire [11:0] single_dac_value;   // 단일 채널 값
    wire update_single_channel;     // 단일 채널 업데이트
    wire update_all_channels;       // 전체 채널 업데이트
    wire dac_controller_busy;       // DAC 컨트롤러 상태
    wire update_complete;           // 업데이트 완료 신호
    
    // 시스템 상태
    wire [31:0] total_updates;      // 총 업데이트 횟수
    wire [15:0] last_update_time;   // 마지막 업데이트 시간 (μs)

    // =======================================================================
    // 모듈 인스턴스화
    // =======================================================================

    // UART 수신기
    uart_rx u_uart_rx (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .uart_rx_in(GPIO_0_RX_DATA),
        .received_byte(uart_rx_data),
        .rx_data_valid(uart_rx_valid)
    );

    // UART 송신기 (상태 피드백용)
    uart_tx u_uart_tx (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start),
        .uart_tx_out(GPIO_0_TX_DATA),
        .tx_busy(uart_tx_busy)
    );

    // 명령 파서 및 데이터 관리
    dac_command_manager u_cmd_manager (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        
        // UART 인터페이스
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(uart_tx_data),
        .uart_tx_start(uart_tx_start),
        .uart_tx_busy(uart_tx_busy),
        
        // DAC 제어 인터페이스
        .all_channel_data(all_channel_data),
        .target_channel(target_channel),
        .single_dac_value(single_dac_value),
        .update_single_channel(update_single_channel),
        .update_all_channels(update_all_channels),
        .dac_busy(dac_controller_busy),
        .update_complete(update_complete),
        
        // 상태 정보
        .total_updates(total_updates),
        .last_update_time(last_update_time),
        .mode_switches(SW),
        .status_leds(LEDR)
    );

    // DAC SPI 컨트롤러 (LDAC 동기화)
    mcp4922_ldac_controller u_dac_controller (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        
        // 제어 입력
        .all_channel_data(all_channel_data),
        .target_channel(target_channel),
        .single_dac_value(single_dac_value),
        .update_single_channel(update_single_channel),
        .update_all_channels(update_all_channels),
        
        // SPI 출력
        .spi_sck(DAC_SCK),
        .spi_sdi(DAC_SDI),
        .dac_cs(DAC_CS),
        .dac_ldac(DAC_LDAC),
        
        // 상태 출력
        .busy(dac_controller_busy),
        .update_complete(update_complete),
        .total_updates(total_updates),
        .last_update_time(last_update_time)
    );

    // DAC 리셋 제어 (파워온 시퀀스)
    assign DAC_RESET = rst_n;  // 간단한 리셋 연결

endmodule