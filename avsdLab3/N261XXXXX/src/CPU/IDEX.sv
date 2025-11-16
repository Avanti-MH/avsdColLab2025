module IDEX (
    input  logic        clk,
    input  logic        rst,
    input  logic        IF_DONE,
    input  logic        MEM_DONE,

    input  logic        flush,
    input  logic        stall,

    input  logic [31:0] ID_pc,
    input  logic [4:0]  ID_op,
    input  logic [3:0]  ID_func,
    input  logic [4:0]  ID_rd,
    input  logic [4:0]  ID_rs1,
    input  logic [4:0]  ID_rs2,
    input  logic        ID_is_mtype,
    input  logic        ID_is_fsub,
    input  logic [11:0] ID_csrIdx,
    input  logic [31:0] ID_rs1_data,
    input  logic [31:0] ID_rs2_data,
    input  logic [31:0] ID_Imm,
    input  logic        ID_pTaken,
    input  logic        ID_WFI,
    input  logic        ID_MRET,


    output logic [31:0] EX_pc,
    output logic [4:0]  EX_op,
    output logic [3:0]  EX_func,
    output logic [4:0]  EX_rd,
    output logic [4:0]  EX_rs1,
    output logic [4:0]  EX_rs2,
    output logic        EX_is_mtype,
    output logic        EX_is_fsub,
    output logic [11:0] EX_csrIdx,
    output logic [31:0] EX_rs1_data,
    output logic [31:0] EX_rs2_data,
    output logic [31:0] EX_Imm,
    output logic        EX_pTaken,
    output logic        EX_WFI,
    output logic        EX_MRET
);

    // ============================================================
    // Pipeline register: transfer signals from D-stage to E-stage
    // Handles reset and flush conditions by inserting a bubble
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // -----------------------------
            // Reset: insert bubble
            // -----------------------------
            EX_op         <= 5'd0;
            EX_func       <= 4'd0;
            EX_rd         <= 5'd0;
            EX_rs1        <= 5'd0;
            EX_rs2        <= 5'd0;
            EX_is_mtype   <= 1'b0;
            EX_is_fsub    <= 1'b0;
            EX_csrIdx     <= 12'd0;
            EX_pc         <= 32'd0;
            EX_rs1_data   <= 32'd0;
            EX_rs2_data   <= 32'd0;
            EX_Imm        <= 32'd0;
            EX_pTaken     <= 1'b0;
            EX_WFI        <= 1'b0;
            EX_MRET       <= 1'b0;
        end else if (IF_DONE && MEM_DONE)begin
            if (flush) begin
                // -----------------------------
                // Flush: insert bubble
                // -----------------------------
                EX_op         <= `BUBBLE_OPCODE;
                EX_func       <= 4'd0;
                EX_rd         <= 5'd0;
                EX_rs1        <= 5'd0;
                EX_rs2        <= 5'd0;
                EX_is_mtype   <= 1'b0;
                EX_is_fsub    <= 1'b0;
                EX_csrIdx     <= 12'd0;
                EX_pc         <= 32'd0;
                EX_rs1_data   <= 32'd0;
                EX_rs2_data   <= 32'd0;
                EX_Imm        <= 32'd0;
                EX_pTaken     <= 1'b0;
                EX_WFI        <= 1'b0;
                EX_MRET       <= 1'b0;
            end else if (~stall) begin
                // -----------------------------
                // Normal operation: pass D-stage values to E-stage
                // -----------------------------
                EX_op         <= ID_op;
                EX_func       <= ID_func;
                EX_rd         <= ID_rd;
                EX_rs1        <= ID_rs1;
                EX_rs2        <= ID_rs2;
                EX_is_mtype   <= ID_is_mtype;
                EX_is_fsub    <= ID_is_fsub;
                EX_csrIdx     <= ID_csrIdx;
                EX_pc         <= ID_pc;
                EX_rs1_data   <= ID_rs1_data;
                EX_rs2_data   <= ID_rs2_data;
                EX_Imm        <= ID_Imm;
                EX_pTaken     <= ID_pTaken;
                EX_WFI        <= ID_WFI;
                EX_MRET       <= ID_MRET;
            end
        end
    end

endmodule
