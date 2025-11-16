module Controller_ID (
    input  logic [4:0] ID_op,
    input  logic [4:0] ID_rs1,
    input  logic [4:0] ID_rs2,
    output logic       ID_use_rs1,
    output logic       ID_use_rs2,
    output logic       ID_use_frs1,
    output logic       ID_use_frs2
);

    // ============================================================
    // ID Stage Register Usage
    // ============================================================
    assign ID_use_rs1  = (ID_op == `OP_RM_TYPE || ID_op == `OP_I_ARITH || ID_op == `OP_I_LOAD || ID_op == `OP_JALR || ID_op == `OP_S_TYPE || ID_op == `OP_B_TYPE || ID_op == `OP_FLW || ID_op == `OP_FSW || ID_op == `OP_CSR);
    assign ID_use_rs2  = (ID_op == `OP_RM_TYPE || ID_op == `OP_S_TYPE || ID_op == `OP_B_TYPE);

    assign ID_use_frs1 = (ID_op == `OP_FTYPE);
    assign ID_use_frs2 = (ID_op == `OP_FTYPE || ID_op == `OP_FSW);

endmodule
