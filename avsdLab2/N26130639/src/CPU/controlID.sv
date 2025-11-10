module controlID (
    input  logic [4:0] W_op,
    input  logic [4:0] W_rd,
    input  logic [4:0] D_op,
    input  logic [4:0] D_rs1,
    input  logic [4:0] D_rs2,
    output logic D_fwdA,
    output logic D_fwdB,
    output logic D_use_rs1,
    output logic D_use_rs2,
    output logic D_use_frs1,
    output logic D_use_frs2
);

    // ============================================================
    // Internal signals: W-stage destination register usage
    // ============================================================
    logic W_use_rd;
    logic W_use_frd;

    assign W_use_rd  = (W_op == `OP_RM_TYPE || W_op == `OP_I_LOAD || W_op == `OP_I_ARITH || W_op == `OP_AUIPC || W_op == `OP_LUI || W_op == `OP_JALR || W_op == `OP_JAL || W_op == `OP_CSR);
    assign W_use_frd = (W_op == `OP_FLW || W_op == `OP_FTYPE);

    // ============================================================
    // D-stage source register usage
    // ============================================================
    assign D_use_rs1  = (D_op == `OP_RM_TYPE || D_op == `OP_I_ARITH || D_op == `OP_I_LOAD || D_op == `OP_JALR || D_op == `OP_S_TYPE || D_op == `OP_B_TYPE || D_op == `OP_FLW || D_op == `OP_FSW || D_op == `OP_CSR);
    assign D_use_rs2  = (D_op == `OP_RM_TYPE || D_op == `OP_S_TYPE || D_op == `OP_B_TYPE);

    assign D_use_frs1 = (D_op == `OP_FTYPE);
    assign D_use_frs2 = (D_op == `OP_FTYPE || D_op == `OP_FSW);

    // ============================================================
    // Forwarding selection logic
    // ============================================================
    always_comb begin
        D_fwdA = (W_rd == D_rs1) & ((D_use_rs1 & W_use_rd & W_rd != 5'd0) | (D_use_frs1 & W_use_frd));
        D_fwdB = (W_rd == D_rs2) & ((D_use_rs2 & W_use_rd & W_rd != 5'd0) | (D_use_frs2 & W_use_frd));
    end

endmodule
