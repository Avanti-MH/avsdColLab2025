module controlWB (
    input  [4:0] W_op,
    output logic W_wbSel,
    output logic W_wbEnable,
    output logic W_fwbEnable
);

    // -----------------------------
    // Select data for writeback
    // -----------------------------
    assign W_wbSel = (W_op == `OP_I_LOAD || W_op == `OP_FLW);

    // -----------------------------
    // Enable integer register writeback
    // -----------------------------
    assign W_wbEnable = (W_op == `OP_LUI   || W_op == `OP_AUIPC || W_op == `OP_JAL || W_op == `OP_JALR  || W_op == `OP_I_LOAD || W_op == `OP_I_ARITH || W_op == `OP_RM_TYPE || W_op == `OP_CSR);

    // -----------------------------
    // Enable floating-point register writeback
    // -----------------------------
    assign W_fwbEnable = (W_op == `OP_FTYPE || W_op == `OP_FLW);

endmodule
