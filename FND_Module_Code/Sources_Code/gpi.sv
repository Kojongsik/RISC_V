`timescale 1ns / 1ps

module GPI_Periph (
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
    // inport signals
    input logic [ 7:0] inPort
);

    logic [7:0] moder;
    logic [7:0] idr;

    APB_SlaveIntf_GPI U_APB_Intf (.*);
    GPI U_GPO_IP (.*);
endmodule

module APB_SlaveIntf_GPI (
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
    output logic [ 7:0] moder,
    input  logic [ 7:0] idr
);
    logic [31:0] slv_reg0, slv_reg1;  //, slv_reg2, slv_reg3;

    assign moder = slv_reg0[7:0];
    assign slv_reg1[7:0] = idr;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            //slv_reg1 <= 0;
            // slv_reg2 <= 0;
            // slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd1: ;
                        // 2'd2: slv_reg2 <= PWDATA;
                        // 2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    PRDATA <= 32'bx;
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        // 2'd2: PRDATA <= slv_reg2;
                        // 2'd3: PRDATA <= slv_reg3;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
            end
        end
    end

endmodule

module GPI (
    input  logic [7:0] moder,
    output logic [7:0] idr,
    input  logic [7:0] inPort
);

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign idr[i] = ~moder[i] ? inPort[i] : 1'bz;
        end
    endgenerate
endmodule
