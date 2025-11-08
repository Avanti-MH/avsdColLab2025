module controlEX (
    input logic [4:0] D_rs1,
    input logic [4:0] D_rs2,
    input logic [4:0] E_op,
    input logic [4:0] E_rd,
    input logic [4:0] E_rs1,
    input logic [4:0] E_rs2,
    input logic [3:0] E_func,
    input logic [4:0] M_op,
    input logic [4:0] M_rd,
    input logic [4:0] W_op,
    input logic [4:0] W_rd,
    input logic D_use_rs1,
    input logic D_use_rs2,
    input logic D_use_frs1,
    input logic D_use_frs2,
    input logic branchFlag,
    input logic E_PredictTaken,
    output logic jb,
    output logic stall,
    output logic csrEnable,
    output logic wrongBranch,
    output logic E_correctTargetSel,
    output logic [1:0] E_updateEnable,
    output logic [1:0] E_fwdA,
    output logic [1:0] E_fwdB,
    output logic E_aluSelA,
    output logic E_aluSelB,
    output logic E_jbSelA
);

    // ------------------------------------------------------------
    // Internal signals: EX, MEM, WB stage register usage
    // ------------------------------------------------------------
    logic E_use_rs1;
    logic E_use_rs2;
    logic E_use_frs1;
    logic E_use_frs2;
    logic M_use_rd;
    logic M_use_frd;
    logic W_use_rd;
    logic W_use_frd;
    logic D_rs1_E_rd_hazard;
    logic D_rs2_E_rd_hazard;
    logic D_rs1_E_rd_hazardF;
    logic D_rs2_E_rd_hazardF;

    // ------------------------------------------------------------
    // EX stage operand usage
    // ------------------------------------------------------------
    assign E_use_rs1  = (E_op == `OP_RM_TYPE || E_op == `OP_I_ARITH || E_op == `OP_I_LOAD || E_op == `OP_JALR || E_op == `OP_S_TYPE || E_op == `OP_B_TYPE || E_op == `OP_FLW || E_op == `OP_FSW);
    assign E_use_rs2  = (E_op == `OP_RM_TYPE || E_op == `OP_B_TYPE || E_op == `OP_S_TYPE);
    assign E_use_frs1 = (E_op == `OP_FTYPE);
    assign E_use_frs2 = (E_op == `OP_FTYPE || E_op == `OP_FSW);

    assign M_use_rd   = (M_op == `OP_RM_TYPE || M_op == `OP_I_LOAD || M_op == `OP_I_ARITH || M_op == `OP_AUIPC || M_op == `OP_LUI || M_op == `OP_JALR || M_op == `OP_JAL || M_op == `OP_CSR);
    assign M_use_frd  = (M_op == `OP_FTYPE || M_op == `OP_FLW);

    assign W_use_rd   = (W_op == `OP_RM_TYPE || W_op == `OP_I_LOAD || W_op == `OP_I_ARITH || W_op == `OP_AUIPC || W_op == `OP_LUI || W_op == `OP_JALR || W_op == `OP_JAL || W_op == `OP_CSR);
    assign W_use_frd  = (W_op == `OP_FTYPE || W_op == `OP_FLW);


    // ------------------------------------------------------------
    // Forwarding logic
    // ------------------------------------------------------------
    always_comb begin
        // rs1 forwarding: MEM -> EX or WB -> EX
        if (E_rs1 == M_rd && M_rd != 5'd0 &&
           ((E_use_rs1 && M_use_rd) || (E_use_frs1 && M_use_frd)))
            E_fwdA = 2'd1;
        else if (E_rs1 == W_rd && W_rd != 5'd0 &&
           ((E_use_rs1 && W_use_rd) || (E_use_frs1 && W_use_frd)))
            E_fwdA = 2'd2;
        else
            E_fwdA = 2'd0;
    end

    always_comb begin
        // rs2 forwarding: MEM -> EX or WB -> EX
        if (E_rs2 == M_rd && M_rd != 5'd0 &&
           ((E_use_rs2 && M_use_rd) || (E_use_frs2 && M_use_frd)))
            E_fwdB = 2'd1;
        else if (E_rs2 == W_rd && W_rd != 5'd0 &&
           ((E_use_rs2 && W_use_rd) || (E_use_frs2 && W_use_frd)))
            E_fwdB = 2'd2;
        else
            E_fwdB = 2'd0;
    end


    // ------------------------------------------------------------
    // Hazard detection
    // ------------------------------------------------------------
    assign D_rs1_E_rd_hazard   = D_use_rs1 && E_rd != 5'd0 && D_rs1 == E_rd;
    assign D_rs2_E_rd_hazard   = D_use_rs2 && E_rd != 5'd0 && D_rs2 == E_rd;
    assign D_rs1_E_rd_hazardF  = D_use_frs1 && E_rd != 5'd0 && D_rs1 == E_rd;
    assign D_rs2_E_rd_hazardF  = D_use_frs2 && E_rd != 5'd0 && D_rs2 == E_rd;

    assign stall = ((E_op == `OP_I_LOAD) && (D_rs1_E_rd_hazard || D_rs2_E_rd_hazard)) ||
                   ((E_op == `OP_FLW) && (D_rs1_E_rd_hazardF || D_rs2_E_rd_hazardF));

    // ------------------------------------------------------------
    // ALU operand selection
    // ------------------------------------------------------------
    assign E_aluSelA = (E_op == `OP_AUIPC || E_op == `OP_JAL || E_op == `OP_JALR);
    assign E_aluSelB = (E_op == `OP_RM_TYPE || E_op == `OP_B_TYPE) ? 1'b0 : 1'b1;

    // ------------------------------------------------------------
    // Jump / Branch
    // ------------------------------------------------------------
    assign jb                 = (E_op == `OP_B_TYPE) ? branchFlag : (E_op == `OP_JAL || E_op == `OP_JALR);
    assign E_jbSelA           = (E_op == `OP_JALR);
    assign wrongBranch        = jb ^ E_PredictTaken;
    assign E_correctTargetSel = !jb & E_PredictTaken;
    always_comb begin
        case (E_op)
            `OP_B_TYPE: E_updateEnable = 2'b10;  // Btype
            `OP_JAL:    E_updateEnable = 2'b01;  // JAL
            default:    E_updateEnable = 2'b00;  // Others
        endcase
        end

    // ------------------------------------------------------------
    // CSR enable
    // ------------------------------------------------------------
    assign csrEnable = ((E_op == `OP_CSR) && (E_rs1 == 5'd0) && (E_func[3:1] == 3'b010));



endmodule
