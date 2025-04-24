`timescale 1ns / 1ps

`include "defines.sv"

module ControlUnit (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instrCode,
    output logic        regFileWe,
    output logic [ 3:0] aluControl,
    output logic        aluSrcMuxSel,
    output logic        dataWe,
    output logic [ 2:0] RFWDSrcMuxSel,
    output logic        branch,
    output logic        jal,
    output logic        jalr,
    output logic        PCEn,
    output logic        transfer,
    input  logic        ready
);
    wire [6:0] opcode = instrCode[6:0];
    wire [3:0] operators = {
        instrCode[30], instrCode[14:12]
    };  // {func7[5], func3}

    logic [10:0] signals;
    assign {PCEn, regFileWe, aluSrcMuxSel, dataWe, RFWDSrcMuxSel, branch, jal, jalr,transfer} = signals;

    typedef enum {
        FETCH,
        DECODE,
        R_EXE,
        I_EXE,
        B_EXE,
        LU_EXE,
        AU_EXE,
        J_EXE,
        JL_EXE,
        S_EXE,
        S_MEM,
        L_EXE,
        L_MEM,
        L_WB
    } state_e;

    state_e state, state_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) state <= FETCH;
        else state <= state_next;
    end

    always_comb begin
        state_next = state;
        case (state)
            FETCH:  state_next = DECODE;
            DECODE: begin
                case (opcode)
                    `OP_TYPE_R:  state_next = R_EXE;
                    `OP_TYPE_S:  state_next = S_EXE;
                    `OP_TYPE_L:  state_next = L_EXE;
                    `OP_TYPE_I:  state_next = I_EXE;
                    `OP_TYPE_B:  state_next = B_EXE;
                    `OP_TYPE_LU: state_next = LU_EXE;
                    `OP_TYPE_AU: state_next = AU_EXE;
                    `OP_TYPE_J:  state_next = J_EXE;
                    `OP_TYPE_JL: state_next = JL_EXE;
                endcase
            end
            R_EXE:  state_next = FETCH;
            S_EXE:  state_next = S_MEM;
            S_MEM:  if (ready) state_next = FETCH;
            L_EXE:  state_next = L_MEM;
            L_MEM:  if (ready) state_next = L_WB;
            L_WB:   state_next = FETCH;
            I_EXE:  state_next = FETCH;
            B_EXE:  state_next = FETCH;
            LU_EXE: state_next = FETCH;
            AU_EXE: state_next = FETCH;
            J_EXE:  state_next = FETCH;
            JL_EXE: state_next = FETCH;
        endcase
    end

    always_comb begin
        signals = 11'b0_0_0_0_000_0_0_0_0;
        aluControl = operators;
        case (state)
            // {PCEn, regFileWe, aluSrcMuxSel, dataWe, RFWDSrcMuxSel(3), branch, jal, jalr,transfer} = signals
            FETCH:  signals = 11'b1_0_0_0_000_0_0_0_0;
            DECODE: signals = 11'b0_0_0_0_000_0_0_0_0;
            R_EXE:  signals = 11'b0_1_0_0_000_0_0_0_0;
            S_EXE: begin
                signals    = 11'b0_0_1_0_000_0_0_0_0;
                aluControl = `ADD;
            end
            S_MEM:  signals = 11'b0_0_1_1_000_0_0_0_1;
            L_EXE: begin
                signals = 11'b0_0_1_0_001_0_0_0_0;
                aluControl = `ADD;
            end
            L_MEM:  signals = 11'b0_0_1_0_001_0_0_0_1;
            L_WB:   signals = 11'b0_1_1_0_001_0_0_0_0;
            I_EXE: begin
                signals = 11'b0_1_1_0_000_0_0_0_0;
                if (operators == 4'b1101)
                    aluControl = operators;  // {1'b1, func3}
                else aluControl = {1'b0, operators[2:0]};  // {1'b0, func3}
            end
            B_EXE:  signals = 11'b0_0_0_0_000_1_0_0_0;
            LU_EXE: signals = 11'b0_1_0_0_010_0_0_0_0;
            AU_EXE: signals = 11'b0_1_0_0_011_0_0_0_0;
            J_EXE:  signals = 11'b0_1_0_0_100_0_1_0_0;
            JL_EXE: begin
                signals    = 11'b0_1_0_0_100_0_1_1_0;
                aluControl = `ADD;
            end
        endcase
    end

    /*
    always_comb begin
        signals = 10'b0;
        case (opcode)
            // {PCEn, regFileWe, aluSrcMuxSel, dataWe, RFWDSrcMuxSel(3), branch, jal, jalr} = signals
            `OP_TYPE_R:  signals = 9'b1_0_0_000_0_0_0;
            `OP_TYPE_S:  signals = 9'b0_1_1_000_0_0_0;
            `OP_TYPE_L:  signals = 9'b1_1_0_001_0_0_0;
            `OP_TYPE_I:  signals = 9'b1_1_0_000_0_0_0;
            `OP_TYPE_B:  signals = 9'b0_0_0_000_1_0_0;
            `OP_TYPE_LU: signals = 9'b1_0_0_010_0_0_0;
            `OP_TYPE_AU: signals = 9'b1_0_0_011_0_0_0;
            `OP_TYPE_J:  signals = 9'b1_0_0_100_0_1_0;
            `OP_TYPE_JL: signals = 9'b1_0_0_100_0_1_1;
        endcase
    end

    always_comb begin
        aluControl = 4'bx;
        case (opcode)
            `OP_TYPE_S: aluControl = `ADD;
            `OP_TYPE_L: aluControl = `ADD;
            `OP_TYPE_JL: aluControl = `ADD;  // {func7[5], func3}
            `OP_TYPE_I: begin
                if (operators == 4'b1101)
                    aluControl = operators;  // {1'b1, func3}
                else aluControl = {1'b0, operators[2:0]};  // {1'b0, func3}
            end
            default: aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_R:  aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_B:  aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_LU: aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_AU: aluControl = operators;  // {func7[5], func3}
            // `OP_TYPE_J:  aluControl = operators;  // {func7[5], func3}
        endcase
    end
    */
endmodule
