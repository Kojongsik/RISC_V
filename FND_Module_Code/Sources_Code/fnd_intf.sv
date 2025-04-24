`timescale 1ns / 1ps

module FndController_Periph (
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
    // outport signals
    output logic [ 3:0] fndCom,
    output logic [ 7:0] fndFont
);

    logic        en;
    logic [13:0] fndData;
    logic [ 3:0] fndDp;
    /*
    logic       fcr;
    logic [3:0] fmr;
    logic [3:0] fdr;
    */
    APB_SlaveIntf_FndController U_APB_Intf_FndController (.*);
    FndController U_FndController (.*);

endmodule

module APB_SlaveIntf_FndController (
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
    output logic        en,
    output logic [13:0] fndData,
    output logic [ 3:0] fndDp
    //output logic [ 7:0] fcr,
    //output logic [ 7:0] fmr,
    //output logic [ 7:0] fdr
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;  //, slv_reg3;

    assign en = slv_reg0[0];
    assign fndData = slv_reg1[13:0];
    assign fndDp = slv_reg2[3:0];


    /*
    assign fcr = slv_reg0[0];
    assign fdr = slv_reg1[13:0];
    assign fpr = slv_reg2[3:0];
*/
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            // slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd1: slv_reg1 <= PWDATA;
                        2'd2: slv_reg2 <= PWDATA;
                        // 2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    PRDATA <= 32'bx;
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        2'd2: PRDATA <= slv_reg2;
                        // 2'd3: PRDATA <= slv_reg3;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
            end
        end
    end

endmodule
/*
module FndController (
    input  logic       fcr,
    input  logic [13:0] fdr,
    output logic [3:0] fndCom,
    output logic [7:0] fndFont
);

    assign fndCom = fcr ? ~fmr : 4'b1111;

    always_comb begin
        case (fdr)
            4'h0: fndFont = 8'hc0;
            4'h1: fndFont = 8'hf9;
            4'h2: fndFont = 8'ha4;
            4'h3: fndFont = 8'hb0;
            4'h4: fndFont = 8'h99;
            4'h5: fndFont = 8'h92;
            4'h6: fndFont = 8'h82;
            4'h7: fndFont = 8'hf8;
            4'h8: fndFont = 8'h80;
            4'h9: fndFont = 8'h90;
            4'ha: fndFont = 8'h88;
            4'hb: fndFont = 8'h83;
            4'hc: fndFont = 8'hc6;
            4'hd: fndFont = 8'ha1;
            4'he: fndFont = 8'h86;
            4'hf: fndFont = 8'h8e;
            default: fndFont = 8'hff;
        endcase
    end

endmodule
*/


module FndController (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic        en,
    input  logic [13:0] fndData,
    input  logic [ 3:0] fndDp,
    output logic [ 3:0] fndCom,
    output logic [ 7:0] fndFont
);

    logic tick, fndDot;
    logic [1:0] digit_sel;
    logic [3:0] digit_1, digit_10, digit_100, digit_1000, digit, o_fndCom;
    logic [7:0] fndSegData;

    assign fndFont = {~fndDot, fndSegData[6:0]
    };  // 제일 상위비트인 1bi는 빼고 출력시키고 port에 출력 시키겠다.
    assign fndCom = en ? o_fndCom : 4'bz;
    clk_div_1khz U_Clk_Div_1Khz (
        .clk  (PCLK),
        .reset(PRESET),
        .tick (tick)
    );

    counter_2bit U_Conter_2big (
        .clk  (PCLK),
        .reset(PRESET),
        .tick (tick),
        .count(digit_sel)
    );

    decoder_2x4 U_Dec_2x4 (
        .x(digit_sel),
        .y(o_fndCom)
    );

    digitSplitter U_Digit_Splitter (
        .fndData(fndData),
        .digit_1(digit_1),
        .digit_10(digit_10),
        .digit_100(digit_100),
        .digit_1000(digit_1000)
    );

    mux_4x1 U_Mux_4x1 (
        .sel(digit_sel),
        .x0 (digit_1),
        .x1 (digit_10),
        .x2 (digit_100),
        .x3 (digit_1000),
        .y  (digit)
    );

    BCDtoSEG_decoder U_BCDtoSEG (
        .bcd(digit),
        .seg(fndSegData)
    );

    mux_4X1_1bit U_Mux_4X1_1Bit (
        .sel(digit_sel),
        .x  (fndDp),
        .y  (fndDot)
    );

endmodule

module mux_4X1_1bit (
    input logic [1:0] sel,
    input logic [3:0] x,
    output logic y
);

    always @(*) begin
        y = 1'b0;
        case (sel)
            2'b00: y = x[0];
            2'b01: y = x[1];
            2'b10: y = x[2];
            2'b11: y = x[3];
        endcase
    end
endmodule

module clk_div_1khz (
    input  logic clk,
    input  logic reset,
    output logic tick
);
    reg [$clog2(100_000)-1 : 0] div_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            div_counter <= 0;
            tick <= 1'b0;
        end else begin
            if (div_counter == 100_000 - 1) begin
                div_counter <= 0;
                tick <= 1'b1;
            end else begin
                div_counter <= div_counter + 1;
                tick <= 1'b0;
            end
        end
    end
endmodule

module counter_2bit (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,
    output logic [1:0] count
);
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count <= 0;
        end else begin
            if (tick) begin
                count <= count + 1;
            end
        end
    end
endmodule

module decoder_2x4 (
    input  logic [1:0] x,
    output logic [3:0] y
);
    always @(*) begin
        y = 4'b1111;
        case (x)
            2'b00: y = 4'b1110;
            2'b01: y = 4'b1101;
            2'b10: y = 4'b1011;
            2'b11: y = 4'b0111;
        endcase
    end
endmodule

module digitSplitter (
    input  logic [13:0] fndData,
    output logic [ 3:0] digit_1,
    output logic [ 3:0] digit_10,
    output logic [ 3:0] digit_100,
    output logic [ 3:0] digit_1000
);
    assign digit_1    = fndData % 10;
    assign digit_10   = fndData / 10 % 10;
    assign digit_100  = fndData / 100 % 10;
    assign digit_1000 = fndData / 1000 % 10;
endmodule

module mux_4x1 (
    input  logic [1:0] sel,
    input  logic [3:0] x0,
    input  logic [3:0] x1,
    input  logic [3:0] x2,
    input  logic [3:0] x3,
    output logic [3:0] y
);
    always @(*) begin
        y = 4'b0000;
        case (sel)
            2'b00: y = x0;
            2'b01: y = x1;
            2'b10: y = x2;
            2'b11: y = x3;
        endcase
    end
endmodule

module BCDtoSEG_decoder (
    input  logic [3:0] bcd,
    output logic [7:0] seg
);
    always @(bcd) begin
        case (bcd)
            4'h0: seg = 8'hc0;
            4'h1: seg = 8'hf9;
            4'h2: seg = 8'ha4;
            4'h3: seg = 8'hb0;
            4'h4: seg = 8'h99;
            4'h5: seg = 8'h92;
            4'h6: seg = 8'h82;
            4'h7: seg = 8'hf8;
            4'h8: seg = 8'h80;
            4'h9: seg = 8'h90;
            4'ha: seg = 8'h88;
            4'hb: seg = 8'h83;
            4'hc: seg = 8'hc6;
            4'hd: seg = 8'ha1;
            4'he: seg = 8'h86;
            4'hf: seg = 8'h8e;
            default: seg = 8'hff;
        endcase
    end
endmodule
