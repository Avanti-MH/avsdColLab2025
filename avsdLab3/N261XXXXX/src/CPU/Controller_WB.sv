module Controller_WB (
    input  logic [4:0] WB_op,
    output logic       WB_wbSel,
    output logic       WB_wbEnable,
    output logic       WB_fwbEnable
);

    // -----------------------------
    // Select data for writeback
    // -----------------------------
    assign WB_wbSel = (WB_op == `OP_I_LOAD || WB_op == `OP_FLW);

    // -----------------------------
    // Enable integer register writeback
    // -----------------------------
    assign WB_wbEnable = (WB_op == `OP_LUI || WB_op == `OP_AUIPC || WB_op == `OP_JAL || WB_op == `OP_JALR  || WB_op == `OP_I_LOAD || WB_op == `OP_I_ARITH || WB_op == `OP_RM_TYPE || WB_op == `OP_CSR);

    // -----------------------------
    // Enable floating-point register writeback
    // -----------------------------
    assign WB_fwbEnable = (WB_op == `OP_FTYPE || WB_op == `OP_FLW);

endmodule
