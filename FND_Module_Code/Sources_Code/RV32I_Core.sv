`timescale 1ns / 1ps

module RV32I_Core (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instrCode,
    output logic [31:0] instrMemAddr,
    output logic        dataWe,
    output logic [31:0] dataAddr,
    output logic [31:0] dataWData,
    input  logic [31:0] dataRData,
    output logic        transfer,
    input  logic        ready
);
    logic        regFileWe;
    logic [ 3:0] aluControl;
    logic        aluSrcMuxSel;
    logic [ 2:0] RFWDSrcMuxSel;
    logic        branch;
    logic        jal;
    logic        jalr;
    logic        PCEn;

    ControlUnit U_ControlUnit (.*);
    DataPath U_DataPath (.*);

endmodule
