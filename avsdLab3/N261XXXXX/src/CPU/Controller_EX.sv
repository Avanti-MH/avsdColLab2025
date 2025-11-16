module Controller_EX (
    input logic [4:0]   EX_op,
    input logic [4:0]   EX_rd,
    input logic [4:0]   EX_rs1,
    input logic [4:0]   EX_rs2,
    input logic [3:0]   EX_func,
    input logic         EX_bFlag,
    input logic         EX_pTaken,
    input logic         loadStall,
    input logic [31:0]  EX_cTarget,
    input logic [31:0]  EX_pc,
    input logic         EX_WFI,
    input logic         EX_MRET,
    input logic         EX_MIE,
    input logic         EX_MEIE,
    input logic         EX_MTIE,
    input logic         EX_MEIP,
    input logic         EX_MTIP,
    input logic [31:0]  EX_MTVEC,
    input logic [31:0]  EX_MEPC,

    output logic        EX_rTaken,
    output logic [1:0]  EX_bType,
    output logic        EX_cTargetSel,
    output logic        EX_aluSelA,
    output logic        EX_aluSelB,
    output logic        EX_jbSelA,
    output logic        EX_csrEn,
    output logic        EX_csrSelB,
    output logic        EX_interrupt_taken,
    output logic        EX_interrupt_return,
    output logic [31:0] EX_flush_pc,
    output logic [31:0] EX_mepc,
    output logic        EX_IF_VALIDn,

    output logic        stallIF,
    output logic        stallID,
    output logic        stallEX,
    output logic        stallCSR,
    output logic        flushIF,
    output logic        flushID,
    output logic        flushEX,
    output logic        flushCSR
);

    // ============================================================
    // ALU operand selection
    // ============================================================
    assign EX_aluSelA = (EX_op == `OP_AUIPC || EX_op == `OP_JAL || EX_op == `OP_JALR);
    assign EX_aluSelB = (EX_op == `OP_RM_TYPE || EX_op == `OP_B_TYPE) ? 1'b0 : 1'b1;

    // ============================================================
    // Branch Prediction
    // ============================================================
    // ------------------------------------------
    // Jump and Branch Control Signal
    // ------------------------------------------
    assign EX_rTaken     = (EX_op == `OP_B_TYPE) ? EX_bFlag : (EX_op == `OP_JAL || EX_op == `OP_JALR);
    assign EX_jbSelA     = (EX_op == `OP_JALR);
    assign EX_bType = (EX_op == `OP_B_TYPE) ? 2'b10 : (EX_op == `OP_JAL) ? 2'b01 : 2'b00;

    // ---------------------
    // Prediction Correction
    // ---------------------
    assign wrongBranch   = (EX_rTaken ^ EX_pTaken);
    assign EX_cTargetSel = !EX_rTaken & EX_pTaken;

    // ============================================================
    // CSR Enable
    // ============================================================
    assign EX_csrEn   = (EX_op == `OP_CSR);
    assign EX_csrSelB = EX_func[3];

    // ============================================================
    // Interrupt and Flush / Stall
    // ============================================================
    always_comb begin
        EX_interrupt_taken  = 1'b0;
        EX_interrupt_return = 1'b0;
        EX_flush_pc         = 32'd0;
        EX_mepc             = 32'd0;
        EX_IF_VALIDn        = 1'b0;

        stallIF  = 1'b0;
        flushIF  = 1'b0;
        stallID  = 1'b0;
        flushID  = 1'b0;
        stallEX  = 1'b0;
        flushEX  = 1'b0;
        stallCSR = 1'b0;
        flushCSR = 1'b0;
        // ---------------------
        // Interrupt Taken
        // ---------------------
        if (EX_MIE && ((EX_MEIP && EX_MEIE)||(EX_MTIP && EX_MTIE))) begin
            EX_interrupt_taken  = 1'b1;
            flushIF             = 1'b1;
            EX_flush_pc         = EX_MTVEC;
            flushID             = 1'b1;
            flushEX             = 1'b1;
            flushCSR            = 1'b1;
            if (EX_WFI) EX_mepc = EX_pc + 32'd4;
            else        EX_mepc = EX_pc;
        // ---------------------
        // Interrupt Return
        // ---------------------
        end else if (EX_MRET) begin
            EX_interrupt_return = 1'b1;
            flushIF             = 1'b1;
            EX_flush_pc         = EX_MEPC;
            flushID             = 1'b1;
            flushEX             = 1'b1;
            flushCSR            = 1'b1;
        // ---------------------
        // No Interrupt
        // ---------------------
        end else begin
            // ---------------------
            // 1. Wait For Interrupt
            // ---------------------
            if (EX_WFI) begin
                flushIF      = 1'b1;
                EX_IF_VALIDn = 1'b1;
                flushID      = 1'b1;
                stallEX      = 1'b1;
                stallCSR     = 1'b1;
            // ---------------------
            // 2. Load Stall
            // ---------------------
            end else if (loadStall) begin
                stallIF      = 1'b1;
                stallID      = 1'b1;
                flushEX      = 1'b1;
                stallCSR     = 1'b1;
            // ---------------------
            // 3. MisPrediction
            // ---------------------
            end else if (wrongBranch) begin
                flushIF      = 1'b1;
                EX_flush_pc  = EX_cTarget;
                flushID      = 1'b1;
                flushEX      = 1'b1;
                flushCSR     = 1'b1;
                end
            end
    end

endmodule
