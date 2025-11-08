module IDEX (
    // input
    input  logic        clk,
    input  logic        rst,
    input  logic        IM_stall,
    input  logic        DM_stall,
    input  logic        flush,
    input  logic [31:0] D_pc,
    input  logic [4:0]  D_op,
    input  logic [3:0]  D_func,
    input  logic [4:0]  D_rd,
    input  logic [4:0]  D_rs1,
    input  logic [4:0]  D_rs2,
    input  logic        D_is_mtype,
    input  logic        D_is_fsub,
    input  logic [1:0]  D_csrOp,
    input  logic [31:0] D_rs1_data,
    input  logic [31:0] D_rs2_data,
    input  logic [31:0] D_sext_imm,
    input  logic        D_PredictTaken,
    // output
    output logic [31:0] E_pc,
    output logic [4:0]  E_op,
    output logic [3:0]  E_func,
    output logic [4:0]  E_rd,
    output logic [4:0]  E_rs1,
    output logic [4:0]  E_rs2,
    output logic        E_is_mtype,
    output logic        E_is_fsub,
    output logic [1:0]  E_csrOp,
    output logic [31:0] E_rs1_data,
    output logic [31:0] E_rs2_data,
    output logic [31:0] E_sext_imm,
    output logic        E_PredictTaken
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
            E_op            <= 5'd0;
            E_func          <= 4'd0;
            E_rd            <= 5'd0;
            E_rs1           <= 5'd0;
            E_rs2           <= 5'd0;
            E_is_mtype      <= 1'b0;
            E_is_fsub       <= 1'b0;
            E_csrOp         <= 2'd0;
            E_pc            <= 32'd0;
            E_rs1_data      <= 32'd0;
            E_rs2_data      <= 32'd0;
            E_sext_imm      <= 32'd0;
            E_PredictTaken  <= 1'b0;
        end else begin
            if (IM_stall || DM_stall) begin
                E_op           <= E_op;
                E_func         <= E_func;
                E_rd           <= E_rd;
                E_rs1          <= E_rs1;
                E_rs2          <= E_rs2;
                E_is_mtype     <= E_is_mtype;
                E_is_fsub      <= E_is_fsub;
                E_csrOp        <= E_csrOp;
                E_pc           <= E_pc;
                E_rs1_data     <= E_rs1_data;
                E_rs2_data     <= E_rs2_data;
                E_sext_imm     <= E_sext_imm;
                E_PredictTaken <= E_PredictTaken;
            end else if (flush) begin
                // -----------------------------
                // Flush: insert bubble
                // -----------------------------
                E_op            <= `BUBBLE_OPCODE;
                E_func          <= 4'd0;
                E_rd            <= 5'd0;
                E_rs1           <= 5'd0;
                E_rs2           <= 5'd0;
                E_is_mtype      <= 1'b0;
                E_is_fsub       <= 1'b0;
                E_csrOp         <= 2'd0;
                E_pc            <= 32'd0;
                E_rs1_data      <= 32'd0;
                E_rs2_data      <= 32'd0;
                E_sext_imm      <= 32'd0;
                E_PredictTaken  <= 1'b0;
            end else begin
                // -----------------------------
                // Normal operation: pass D-stage values to E-stage
                // -----------------------------
                E_op            <= D_op;
                E_func          <= D_func;
                E_rd            <= D_rd;
                E_rs1           <= D_rs1;
                E_rs2           <= D_rs2;
                E_is_mtype      <= D_is_mtype;
                E_is_fsub       <= D_is_fsub;
                E_csrOp         <= D_csrOp;
                E_pc            <= D_pc;
                E_rs1_data      <= D_rs1_data;
                E_rs2_data      <= D_rs2_data;
                E_sext_imm      <= D_sext_imm;
                E_PredictTaken  <= D_PredictTaken;
            end
        end
    end

endmodule
