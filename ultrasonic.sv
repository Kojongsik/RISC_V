`timescale 1ns / 1ps


module Ultrasonic_Periph (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // export signals
    input logic echo,
    output logic trigger,
    output logic [3:0] led,
    output logic [15:0] distance
);

    logic start_trig;
    logic [15:0] w_distance;

    Ultrasonic_SlaveIntf U_US_intf(
        // global signal
        .PCLK(PCLK),
        .PRESET(PRESET),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PWRITE(PWRITE),
        .PENABLE(PENABLE),
        .PSEL(PSEL),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .start_trig(start_trig),
        .distance(w_distance)
    );

    US U_US_IP(
        .clk(PCLK),
        .rst(PRESET),
        .start_trig(start_trig),
        .echo(echo),
        .led(led),
        .trigger(trigger),
        .distance(w_distance)
    );

    assign distance = w_distance;

endmodule



module Ultrasonic_SlaveIntf (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    output logic        start_trig,
    input  logic [15:0] distance
);

    logic [31:0] slv_reg0, slv_reg1;


    assign start_trig = slv_reg0[0];

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            PRDATA <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        default: ;
                    endcase
                end else begin
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= {16'd0, distance};
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
                slv_reg0[0] <= 1'b0;
            end
        end
    end

endmodule





module US(
    input clk,
    input rst,
    input start_trig,
    input echo,
    output [3:0] led,
    output trigger,
    output [15:0] distance
    );

    wire w_tick;

    dist_calculator U_dist_cal(
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .echo_pulse(echo),
        .start_trig(start_trig),

        .led(led),
        .echo_trigger(trigger),
        .dist_cm(distance)
    );

    tick_gen_10us U_tick_gen(
        .clk(clk),
        .rst(rst),
        .tick_10us(w_tick)
    );


endmodule


module dist_calculator (
    input logic clk,
    input logic rst,
    input logic tick,
    input logic echo_pulse,
    input logic start_trig,
    output logic [3:0] led,
    output logic echo_trigger,
    output logic [15:0] dist_cm
);

    typedef enum logic [1:0] { IDLE, TRIGGER, WAIT_ECHO, ECHO_CAL } ultrasonic_enum;
    ultrasonic_enum state, state_next;
     
  
    logic [4:0] trigger_count;
    logic [19:0] echo_count;
    logic prev_echo; // 이전 echo_pulse 값 저장
    logic [15:0] dist_updata;  // 측정 값 유지지

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            prev_echo <= 0;
        end else begin
            state <= state_next;
            prev_echo <= echo_pulse; // 이전 echo 값 저장
        end
    end

    // 상태 변화 로직
    always @(*) begin
        state_next = state;
        case (state)
            IDLE: begin
                if (start_trig) state_next = TRIGGER;
                else state_next = IDLE;
            end 
            TRIGGER: begin
                if (trigger_count >= 2) state_next = WAIT_ECHO; // 20µs 유지 후 WAIT_ECHO로 이동
                else state_next = TRIGGER;
            end
            WAIT_ECHO: begin
                if (echo_pulse == 1'b1) state_next = ECHO_CAL;
                else state_next = WAIT_ECHO;
            end
            ECHO_CAL: begin
                if (echo_count >= 2900) state_next = IDLE;
                else if (echo_pulse == 1'b0 && prev_echo == 1) state_next = IDLE; // HIGH → LOW 변화 감지 후 IDLE로 이동
                else state_next = ECHO_CAL;
            end
        endcase
    end

    // 출력을 관리하는 블록 (trigger_count 증가 및 echo_count 증가)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            echo_trigger <= 0;
            trigger_count <= 0;
            echo_count <= 0;
            dist_cm <= 0;
            dist_updata <= 0;
        end else begin
            case (state)
                IDLE: begin
                    echo_trigger <= 0;
                    trigger_count <= 0;
                    echo_count <= 0;
                    dist_cm <= dist_updata;
                    led <= 4'b0001;
                end 
                TRIGGER: begin
                    echo_trigger <= 1;
                    led <= 4'b0010;
                    if (tick) trigger_count <= trigger_count + 1; // TRIGGER 유지 시간 증가
                end 
                WAIT_ECHO: begin
                    echo_trigger <= 0; // TRIGGER 종료
                    led <= 4'b0100;
                end 
                ECHO_CAL: begin
                    led <= 4'b1000;
                    if (tick && echo_pulse) begin
                        echo_count <= echo_count + 1; // echo가 HIGH일 때 카운트 증가
                    end

                    if(echo_count >= 2333) begin
                        dist_updata <= 16'hFFFF;
                        dist_cm <= dist_updata;
                        echo_count <= 0;
                    end else if (!echo_pulse && prev_echo) begin // HIGH → LOW 순간 거리 계산
                        dist_updata <= (echo_count * 343) / (2 * 1000);
                        dist_cm <= dist_updata;
                        echo_count <= 0;
                    end


                end
            endcase
        end
    end
endmodule




module tick_gen_10us (
    input logic clk,
    input logic rst,
    output logic tick_10us
);

    localparam FCOUNT = 1_000; // 100MHz 기준 10µs
    logic [$clog2(FCOUNT)-1:0] count_reg;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            tick_10us <= 0;
        end else begin
            if (count_reg == FCOUNT-1) begin
                count_reg <= 0;
                tick_10us <= 1; // 10µs마다 HIGH
            end else begin
                count_reg <= count_reg + 1;
                tick_10us <= 0; // 나머지 시간 동안 LOW 유지
            end
        end
    end
endmodule