module Hazard_Detector (
    // input
    input logic [4:0]   ID_rs1,
    input logic [4:0]   ID_rs2,
    input logic         ID_use_rs1,
    input logic         ID_use_rs2,
    input logic         ID_use_frs1,
    input logic         ID_use_frs2,
    input logic [4:0]   EX_op,
    input logic [4:0]   EX_rd,
    input logic [4:0]   EX_rs1,
    input logic [4:0]   EX_rs2,
    input logic [4:0]   MEM_op,
    input logic [4:0]   MEM_rd,
    input logic [4:0]   WB_op,
    input logic [4:0]   WB_rd,

    output logic        ID_fwdA,
    output logic        ID_fwdB,
    output logic [1:0]  EX_fwdA,
    output logic [1:0]  EX_fwdB,
    output logic        loadStall
);

    // ============================================================
    // Local Signals
    // ============================================================
    logic EX_use_rs1,  EX_use_rs2;
    logic EX_use_frs1, EX_use_frs2;

    logic WB_use_rd,  MEM_use_rd;
    logic WB_use_frd, MEM_use_frd;

    logic EX_use_ld, EX_use_fld;
    logic ID_rs1_EX_rd, ID_rs2_EX_rd;

    // ============================================================
    // Forwarding Logic
    // ============================================================

    // -----------------------------
    // EX Stage Register Usage
    // -----------------------------
    assign EX_use_rs1  = (EX_op == `OP_RM_TYPE || EX_op == `OP_I_ARITH || EX_op == `OP_I_LOAD || EX_op == `OP_JALR || EX_op == `OP_S_TYPE || EX_op == `OP_B_TYPE || EX_op == `OP_FLW || EX_op == `OP_FSW || EX_op == `OP_CSR);
    assign EX_use_rs2  = (EX_op == `OP_RM_TYPE || EX_op == `OP_B_TYPE || EX_op == `OP_S_TYPE);
    assign EX_use_frs1 = (EX_op == `OP_FTYPE);
    assign EX_use_frs2 = (EX_op == `OP_FTYPE || EX_op == `OP_FSW);


    // -----------------------------
    // MEM / WB Stage Register Destination
    // -----------------------------
    assign MEM_use_rd   = (MEM_op == `OP_RM_TYPE || MEM_op == `OP_I_LOAD || MEM_op == `OP_I_ARITH || MEM_op == `OP_AUIPC || MEM_op == `OP_LUI || MEM_op == `OP_JALR || MEM_op == `OP_JAL || MEM_op == `OP_CSR);
    assign WB_use_rd    = (WB_op  == `OP_RM_TYPE || WB_op  == `OP_I_LOAD || WB_op  == `OP_I_ARITH || WB_op  == `OP_AUIPC || WB_op  == `OP_LUI || WB_op  == `OP_JALR || WB_op  == `OP_JAL || WB_op  == `OP_CSR);
    assign MEM_use_frd  = (MEM_op == `OP_FTYPE || MEM_op == `OP_FLW);
    assign WB_use_frd   = (WB_op  == `OP_FTYPE || WB_op  == `OP_FLW);

    // -----------------------------
    // Forwarding Logic
    // -----------------------------
    always_comb begin
        ID_fwdA = (  (WB_rd == ID_rs1) && WB_rd != 5'd0  ) && (  (ID_use_rs1 & WB_use_rd) || (ID_use_frs1 & WB_use_frd)  );
        ID_fwdB = (  (WB_rd == ID_rs2) && WB_rd != 5'd0  ) && (  (ID_use_rs2 & WB_use_rd) || (ID_use_frs2 & WB_use_frd)  );
    end

    always_comb begin
        if      ((  (EX_rs1 == MEM_rd) && MEM_rd != 5'd0  ) && (  (EX_use_rs1 && MEM_use_rd) || (EX_use_frs1 && MEM_use_frd)  )) EX_fwdA = 2'd1;
        else if ((  (EX_rs1 ==  WB_rd) && WB_rd  != 5'd0  ) && (  (EX_use_rs1 &&  WB_use_rd) || (EX_use_frs1 &&  WB_use_frd)  )) EX_fwdA = 2'd2;
        else                                                                                                                     EX_fwdA = 2'd0;

        if      ((  (EX_rs2 == MEM_rd) && MEM_rd != 5'd0  ) && (  (EX_use_rs2 && MEM_use_rd) || (EX_use_frs2 && MEM_use_frd)  )) EX_fwdB = 2'd1;
        else if ((  (EX_rs2 ==  WB_rd) &&  WB_rd != 5'd0  ) && (  (EX_use_rs2 &&  WB_use_rd) || (EX_use_frs2 &&  WB_use_frd)  )) EX_fwdB = 2'd2;
        else                                                                                                                     EX_fwdB = 2'd0;
    end
    // ============================================================
    // Load Stall Logic
    // ============================================================

    // -----------------------------
    // EX Stage Load Operations
    // -----------------------------
    assign EX_use_ld  = (EX_op == `OP_I_LOAD);
    assign EX_use_fld = (EX_op == `OP_FLW);

    // -----------------------------
    // ID rsx and EX rd Overlapping
    // -----------------------------
    assign ID_rs1_EX_rd   = (  (ID_rs1 == EX_rd) && EX_rd != 5'd0  ) && ((ID_use_rs1 && EX_use_ld) || (ID_use_frs1 && EX_use_fld));
    assign ID_rs2_EX_rd   = (  (ID_rs2 == EX_rd) && EX_rd != 5'd0  ) && ((ID_use_rs2 && EX_use_ld) || (ID_use_frs2 && EX_use_fld));

    // -----------------------------
    // Load Stall Logic
    // -----------------------------
    assign loadStall = ID_rs1_EX_rd || ID_rs2_EX_rd;

endmodule