module mcp4922_ldac_controller (
    input wire clk,
    input wire rst_n,
    
    // 제어 입력
    input wire [287:0] all_channel_data,
    input wire [4:0] target_channel,
    input wire [11:0] single_dac_value,
    input wire update_single_channel,
    input wire update_all_channels,
    
    // SPI 출력
    output reg spi_sck,
    output reg spi_sdi,
    output reg [11:0] dac_cs,
    output reg dac_ldac,
    
    // 상태 출력
    output reg busy,
    output reg update_complete,
    output reg [31:0] total_updates,
    output reg [15:0] last_update_time
);

    // =======================================================================
    // SPI 타이밍 생성 (1MHz SPI 클럭)
    // =======================================================================
    reg [5:0] spi_clk_div;
    reg spi_clk_en;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk_div <= 0;
            spi_clk_en <= 0;
        end else begin
            if (spi_clk_div == 24) begin  // 50MHz / 25 = 2MHz, /2 = 1MHz
                spi_clk_div <= 0;
                spi_clk_en <= 1;
            end else begin
                spi_clk_div <= spi_clk_div + 1;
                spi_clk_en <= 0;
            end
        end
    end

    // =======================================================================
    // 메인 컨트롤러 상태 머신
    // =======================================================================
    reg [4:0] main_state;
    reg [4:0] current_dac;        // 현재 처리중인 DAC (0-11)
    reg current_channel;          // 현재 채널 (0=A, 1=B)
    reg [4:0] spi_bit_count;      // SPI 비트 카운터
    reg [15:0] tx_data;           // 전송할 16비트 데이터
    reg [31:0] time_counter;      // 업데이트 시간 측정
    
    localparam STATE_IDLE = 0,
               STATE_PREPARE = 1,
               STATE_START_TRANSMISSION = 2,
               STATE_SPI_SETUP = 3,
               STATE_SPI_CLOCK_HIGH = 4,
               STATE_SPI_CLOCK_LOW = 5,
               STATE_SPI_COMPLETE = 6,
               STATE_NEXT_CHANNEL = 7,
               STATE_LDAC_PULSE = 8,
               STATE_COMPLETE = 9;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_state <= STATE_IDLE;
            busy <= 0;
            spi_sck <= 0;
            spi_sdi <= 0;
            dac_cs <= 12'hFFF;      // 모든 CS 비활성 (HIGH)
            dac_ldac <= 1'b1;       // LDAC 비활성 (HIGH)
            current_dac <= 0;
            current_channel <= 0;
            spi_bit_count <= 0;
            update_complete <= 0;
            total_updates <= 0;
            time_counter <= 0;
            last_update_time <= 0;
        end else begin
            
            // 기본값
            update_complete <= 0;
            
            case (main_state)
                STATE_IDLE: begin
                    busy <= 0;
                    time_counter <= 0;
                    
                    if (update_single_channel) begin
                        // 단일 채널 업데이트
                        current_dac <= target_channel / 2;      // DAC 번호 (0-11)
                        current_channel <= target_channel[0];   // 채널 A/B
                        main_state <= STATE_PREPARE;
                        busy <= 1;
                        dac_ldac <= 1'b1;  // 업데이트 방지
                    end else if (update_all_channels) begin
                        // 전체 채널 업데이트
                        current_dac <= 0;
                        current_channel <= 0;
                        main_state <= STATE_PREPARE;
                        busy <= 1;
                        dac_ldac <= 1'b1;  // 업데이트 방지
                    end
                end
                
                STATE_PREPARE: begin
                    time_counter <= time_counter + 1;
                    
                    // 전송할 데이터 준비
                    if (update_single_channel) begin
                        // 단일 채널 데이터
                        tx_data <= {
                            current_channel,    // A/B 선택 (bit 15)
                            1'b0,              // BUF (bit 14) - Unbuffered
                            1'b1,              // GA (bit 13) - 2x Gain  
                            1'b1,              // SHDN (bit 12) - Active
                            single_dac_value   // 12-bit 데이터
                        };
                    end else begin
                        // 전체 채널에서 현재 채널 데이터 추출
                        wire [4:0] channel_index = current_dac * 2 + current_channel;
                        tx_data <= {
                            current_channel,    // A/B 선택
                            1'b0,              // BUF - Unbuffered
                            1'b1,              // GA - 2x Gain
                            1'b1,              // SHDN - Active
                            all_channel_data[channel_index*12 +: 12]
                        };
                    end
                    
                    spi_bit_count <= 15;        // 16비트 전송 (15부터 0까지)
                    main_state <= STATE_START_TRANSMISSION;
                end
                
                STATE_START_TRANSMISSION: begin
                    dac_cs[current_dac] <= 0;   // 대상 DAC 선택
                    spi_sck <= 0;
                    main_state <= STATE_SPI_SETUP;
                end
                
                STATE_SPI_SETUP: begin
                    if (spi_clk_en) begin
                        spi_sdi <= tx_data[spi_bit_count];  // 데이터 출력
                        main_state <= STATE_SPI_CLOCK_HIGH;
                    end
                end
                
                STATE_SPI_CLOCK_HIGH: begin
                    if (spi_clk_en) begin
                        spi_sck <= 1;                       // 클럭 상승 에지
                        main_state <= STATE_SPI_CLOCK_LOW;
                    end
                end
                
                STATE_SPI_CLOCK_LOW: begin
                    if (spi_clk_en) begin
                        spi_sck <= 0;                       // 클럭 하강 에지
                        
                        if (spi_bit_count == 0) begin
                            main_state <= STATE_SPI_COMPLETE;
                        end else begin
                            spi_bit_count <= spi_bit_count - 1;
                            main_state <= STATE_SPI_SETUP;
                        end
                    end
                end
                
                STATE_SPI_COMPLETE: begin
                    dac_cs[current_dac] <= 1;   // CS 비활성화
                    main_state <= STATE_NEXT_CHANNEL;
                end
                
                STATE_NEXT_CHANNEL: begin
                    if (update_single_channel) begin
                        // 단일 채널 업데이트 완료
                        main_state <= STATE_LDAC_PULSE;
                    end else begin
                        // 다음 채널로 이동
                        if (current_channel == 1) begin
                            current_channel <= 0;
                            if (current_dac == 11) begin
                                // 모든 DAC 전송 완료
                                main_state <= STATE_LDAC_PULSE;
                            end else begin
                                current_dac <= current_dac + 1;
                                main_state <= STATE_PREPARE;
                            end
                        end else begin
                            current_channel <= 1;
                            main_state <= STATE_PREPARE;
                        end
                    end
                end
                
                STATE_LDAC_PULSE: begin
                    // 모든 DAC 동시 업데이트!
                    dac_ldac <= 1'b0;  // LDAC 활성화 (LOW)
                    main_state <= STATE_COMPLETE;
                end
                
                STATE_COMPLETE: begin
                    dac_ldac <= 1'b1;          // LDAC 비활성화
                    update_complete <= 1;      // 완료 신호
                    total_updates <= total_updates + 1;
                    last_update_time <= time_counter[31:16];  // μs 단위로 변환
                    main_state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule