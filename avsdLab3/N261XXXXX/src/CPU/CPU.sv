module CPU (
    // input
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] Instr,
    input  logic [31:0] ReadData,
    input  logic        IM_stall,
    input  logic        DM_stall,
    // output
    output logic [31:0] PC,
    output logic [31:0] DM_A,
    output logic [31:0] WriteData,
    output logic        DM_CEB,
    output logic        IM_CEB,
    output logic        DM_WEB,
    output logic [ 3:0] DM_BWEB
);
    // ============================================================
    // Internal signals
    // ============================================================

    // -------------------------------------
    // Global / Cross-Stage Signals
    // -------------------------------------
    logic           stall,        jb,            wrongBranch;

    // -------------------------------------
    // IF Stage
    // -------------------------------------
    logic [31:0]    F_pc;
    logic           F_predictTaken;
    logic [15:0]    F_predictedTarget;
    logic           IMEnable;

    // -------------------------------------
    // IF-ID Pipeline Register
    // -------------------------------------
    logic [31:0]    D_pc;
    logic [31:0]    D_inst;
    logic           D_PredictTaken;

    // -------------------------------------
    // ID Stage
    // -------------------------------------
    logic [ 4:0]    D_rs1,        D_rs2,        D_rd;
    logic [ 4:0]    D_op;
    logic [ 3:0]    D_func;
    logic           D_is_mtype,   D_is_fsub;
    logic [ 1:0]    D_csrOp;

    logic [31:0]    D_rs1_data,   D_rs2_data,   data1,        data2,        fdata1,       fdata2,       D_rs1_regData,D_rs2_regData;
    logic [31:0]    D_sext_imm;
    logic           D_fwdA,       D_fwdB;
    logic           D_use_rs1,    D_use_rs2;
    logic           D_use_frs1,   D_use_frs2;

    // -------------------------------------
    // ID-EX Pipeline Register
    // -------------------------------------
    logic [ 4:0]    E_rs1,        E_rs2,        E_rd;
    logic [ 4:0]    E_op;
    logic [ 3:0]    E_func;
    logic           E_is_mtype,   E_is_fsub;
    logic [ 1:0]    E_csrOp;
    logic [31:0]    E_pc;
    logic [31:0]    E_rs1_data,   E_rs2_data;
    logic [31:0]    E_sext_imm;
    logic           E_PredictTaken;

    // -------------------------------------
    // EX Stage
    // -------------------------------------
    logic [ 1:0]    E_fwdA,       E_fwdB,       E_updateEnable;
    logic           E_aluSelA,    E_aluSelB,    E_jbSelA;
    logic           E_csrEnable,  E_correctTargetSel;
    logic [31:0]    ALU_src1,     ALU_src2;
    logic [31:0]    jbSrcA;
    logic [31:0]    rs1Data,      rs2Data;
    logic [31:0]    aluOut,       fpuOut,       csrOut;
    logic [31:0]    E_aluOut;
    logic [31:0]    E_correctTarget;
    logic [31:0]    jbTarget;

    // -------------------------------------
    // EX-MEM Pipeline Register
    // -------------------------------------
    logic [ 4:0]    M_rd;
    logic [ 4:0]    M_op;
    logic [ 2:0]    M_func3;
    logic [31:0]    M_aluOut;
    logic [31:0]    M_rs2_data;
    logic           DMEnable;

    // -------------------------------------
    // MEM-WB Pipeline Register
    // -------------------------------------
    logic [ 4:0]    W_rd;
    logic [ 4:0]    W_op;
    logic [ 2:0]    W_func3;
    logic [31:0]    W_aluOut;
    logic [31:0]    W_ReadData;

    // -------------------------------------
    // WB Stage
    // -------------------------------------
    logic           W_wbSel;
    logic           W_wbEnable;
    logic           W_fwbEnable;
    logic [31:0]    W_wbData;
    logic [31:0]    loadData;

    // ============================================================
    // Instruction Fetch (IF)
    // ============================================================

    // ------------------------------------------------------------
    // Unit: Branch Predictor (Gshare)
    // Description: Provides branch prediction for the IF stage
    // ------------------------------------------------------------
    branchPredictorGshare branchPredictorGshare (
        // input
        .clk                (clk),
        .rst                (rst),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .fetchPc            (F_pc[15:0]),
        .exBranchType       (E_updateEnable),
        .exTaken            (jb),
        .exTarget           (jbTarget[15:0]),
        .exPc               (E_pc[15:0]),
        // output
        .fetchHit           (F_predictTaken),
        .fetchTarget        (F_predictedTarget)
    );


    // ------------------------------------------------------------
    // Unit: Program Counter (PC)
    // Description: Handles branch prediction and correction
    // ------------------------------------------------------------
    pcUnit pcu (
        // input
        .clk                (clk),
        .rst                (rst),
        .stall              (stall),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .mispredict         (wrongBranch),
        .predictTaken       (F_predictTaken),
        .predictedTarget    (F_predictedTarget),
        .correctTarget      (E_correctTarget),
        // output
        .pc                 (F_pc)
    );

    // ------------------------------------------------------------
    // Unit: Instruction Memory (IM) Interface
    // Description: Extracts instruction memory address from PC
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            IMEnable    <= 1'b0;
        end else if (~IM_stall && DM_stall) begin
            IMEnable    <= 1'b0;
        end else if (~(IM_stall || DM_stall))begin
            IMEnable    <= 1'b1;
        end
    end

    always_comb begin
        IM_CEB = ~IMEnable;
        PC = F_pc;
    end


    // ------------------------------------------------------------
    // Unit: IF-ID Pipeline Register
    // Description: Stores fetched instruction and PC for Decode stage
    // ------------------------------------------------------------
    IFID ifid (
        // input
        .clk                (clk),
        .rst                (rst),
        .stall              (stall),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .flush              (wrongBranch),
        .F_pc               (F_pc),
        .F_inst             (Instr),
        .F_PredictTaken     (F_predictTaken),
        // output
        .D_pc               (D_pc),
        .D_inst             (D_inst),
        .D_PredictTaken     (D_PredictTaken)
    );


    // ============================================================
    // Instruction Decode (ID)
    // ============================================================

    // ------------------------------------------------------------
    // Unit: Control Signal Generator
    // Description: Generates control signals for data hazards and forwarding
    // ------------------------------------------------------------
    controlID ctrid (
        // input
        .W_op               (W_op),
        .W_rd               (W_rd),
        .D_op               (D_op),
        .D_rs1              (D_rs1),
        .D_rs2              (D_rs2),
        // output
        .D_fwdA             (D_fwdA),
        .D_fwdB             (D_fwdB),
        // passing to EXE
        .D_use_rs1          (D_use_rs1),
        .D_use_rs2          (D_use_rs2),
        .D_use_frs1         (D_use_frs1),
        .D_use_frs2         (D_use_frs2)
    );


    // ------------------------------------------------------------
    // Unit: Instruction Decoder
    // Decodes instruction to generate operands and control signals
    // ------------------------------------------------------------
    decoder decoder (
        // input
        .inst               (D_inst),
        // output
        .rs1_index          (D_rs1),
        .rs2_index          (D_rs2),
        .rd_index           (D_rd),
        .opcode             (D_op),
        .func               (D_func),
        .is_mtype           (D_is_mtype),
        .is_fsub            (D_is_fsub),
        .csrOp              (D_csrOp)
    );

    // ------------------------------------------------------------
    // Unit: Immediate Extension
    // Extends immediate field from instruction
    // ------------------------------------------------------------
    immGenerator immGenerator (
        // input
        .opcode             (D_op),
        .inst               (D_inst),
        // output
        .imm                (D_sext_imm)
    );


    // ------------------------------------------------------------
    // Unit: General Register File
    // Reads data from integer register file
    // ------------------------------------------------------------
    regFile regFile (
        // input
        .clk                (clk),
        .rst                (rst),
        .rs1_index          (D_rs1),
        .rs2_index          (D_rs2),
        .w_index            (W_rd),
        .w_data             (W_wbData),
        .w_en               (W_wbEnable),
        // output
        .data1              (data1),
        .data2              (data2)
    );

    // ------------------------------------------------------------
    // Unit: Floating-Point Register File
    // Reads data from floating-point register file
    // ------------------------------------------------------------
    fpRegFile fpRegFile (
        // input
        .clk                (clk),
        .rst                (rst),
        .rs1_index          (D_rs1),
        .rs2_index          (D_rs2),
        .w_index            (W_rd),
        .w_data             (W_wbData),
        .w_en               (W_fwbEnable),
        // output
        .data1              (fdata1),
        .data2              (fdata2)
    );

    // ------------------------------------------------------------
    // Unit: Register Selection & Forwarding
    // Selects register source and applies forwarding from Writeback
    // ------------------------------------------------------------
    always_comb begin
        // Register selection (integer vs floating-point)
        D_rs1_regData = D_use_frs1 ? fdata1 : data1;
        D_rs2_regData = D_use_frs2 ? fdata2 : data2;

        // Forwarding from Writeback stage if needed
        D_rs1_data = D_fwdA ? W_wbData : D_rs1_regData;
        D_rs2_data = D_fwdB ? W_wbData : D_rs2_regData;
    end


    // ------------------------------------------------------------
    // Unit: ID-EX Pipeline Register
    // Stores decoded instruction and operands for Execute stage
    // ------------------------------------------------------------
    IDEX idex (
        // input
        .clk                (clk),
        .rst                (rst),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .flush              (wrongBranch | stall),
        .D_pc               (D_pc),
        .D_op               (D_op),
        .D_func             (D_func),
        .D_rd               (D_rd),
        .D_rs1              (D_rs1),
        .D_rs2              (D_rs2),
        .D_is_mtype         (D_is_mtype),
        .D_is_fsub          (D_is_fsub),
        .D_csrOp            (D_csrOp),
        .D_rs1_data         (D_rs1_data),
        .D_rs2_data         (D_rs2_data),
        .D_sext_imm         (D_sext_imm),
        .D_PredictTaken     (D_PredictTaken),
        // output
        .E_pc               (E_pc),
        .E_op               (E_op),
        .E_func             (E_func),
        .E_rd               (E_rd),
        .E_rs1              (E_rs1),
        .E_rs2              (E_rs2),
        .E_is_mtype         (E_is_mtype),
        .E_is_fsub          (E_is_fsub),
        .E_csrOp            (E_csrOp),
        .E_rs1_data         (E_rs1_data),
        .E_rs2_data         (E_rs2_data),
        .E_sext_imm         (E_sext_imm),
        .E_PredictTaken     (E_PredictTaken)
    );


    // ============================================================
    // Execute (EX)
    // ============================================================

    // ------------------------------------------------------------
    // Unit: Control Signal Generator
    // Generates control signals for ALU, branch, and forwarding
    // ------------------------------------------------------------
    controlEX ctrex (
        // input
        .D_rs1              (D_rs1),
        .D_rs2              (D_rs2),
        .E_op               (E_op),
        .E_rd               (E_rd),
        .E_rs1              (E_rs1),
        .E_rs2              (E_rs2),
        .E_func             (E_func),
        .M_op               (M_op),
        .M_rd               (M_rd),
        .W_op               (W_op),
        .W_rd               (W_rd),
        .D_use_rs1          (D_use_rs1),
        .D_use_rs2          (D_use_rs2),
        .D_use_frs1         (D_use_frs1),
        .D_use_frs2         (D_use_frs2),
        .branchFlag         (E_aluOut[0]),
        .E_PredictTaken     (E_PredictTaken),
        // output
        .jb                 (jb),
        .stall              (stall),
        .csrEnable          (E_csrEnable),
        .wrongBranch        (wrongBranch),
        .E_correctTargetSel (E_correctTargetSel),
        .E_updateEnable     (E_updateEnable),
        .E_fwdA             (E_fwdA),
        .E_fwdB             (E_fwdB),
        .E_aluSelA          (E_aluSelA),
        .E_aluSelB          (E_aluSelB),
        .E_jbSelA           (E_jbSelA)
    );


    // ------------------------------------------------------------
    // Unit: Forwarding Multiplexers (rs1 & rs2)
    // Selects operand data from EX, MEM, or WB stages
    // ------------------------------------------------------------
    always_comb begin
        // Forward rs1
        case (E_fwdA)
            2'd0: rs1Data = E_rs1_data;
            2'd1: rs1Data = M_aluOut;
            2'd2: rs1Data = W_wbData;
            default: rs1Data = 32'd0;
        endcase

        // Forward rs2
        case (E_fwdB)
            2'd0: rs2Data = E_rs2_data;
            2'd1: rs2Data = M_aluOut;
            2'd2: rs2Data = W_wbData;
            default: rs2Data = 32'd0;
        endcase
    end


    // ------------------------------------------------------------
    // Unit: ALU Source Selection
    // Chooses ALU operands based on opcode
    // ------------------------------------------------------------
    always_comb begin
        // Operand 1 selection
        ALU_src1 = E_aluSelA ? E_pc : rs1Data;

        // Operand 2 selection
        ALU_src2 = E_aluSelB ? E_sext_imm : rs2Data;
    end


    // ------------------------------------------------------------
    // Unit: ALU
    // Executes integer arithmetic and logical operations
    // ------------------------------------------------------------
    alu alu (
        .src1               (ALU_src1),
        .src2               (ALU_src2),
        .opcode             (E_op),
        .func               (E_func),
        .is_mtype           (E_is_mtype),
        .aluOut             (aluOut)
    );


    // ------------------------------------------------------------
    // Unit: Floating-Point Unit
    // Performs floating-point operations
    // ------------------------------------------------------------
    fpu fpu (
        .src1               (rs1Data),
        .src2               (rs2Data),
        .sub                (E_is_fsub),
        .fpuOut             (fpuOut)
    );


    // ------------------------------------------------------------
    // Unit: CSR Register File
    // Handles CSR read/write operations in Execute stage
    // ------------------------------------------------------------
    csrFile csrFile (
        // input
        .clk                (clk),
        .rst                (rst),
        .enable             (E_csrEnable),
        .stall              (stall),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .wrongBranch        (wrongBranch),
        .csrOp              (E_csrOp),
        // output
        .csrOut             (csrOut)
    );


    // ------------------------------------------------------------
    // Unit: Execute Stage Output Selection
    // Selects ALU, FPU, or CSR output depending on opcode
    // ------------------------------------------------------------
    always_comb begin
        E_aluOut = (E_op == `OP_FTYPE) ? fpuOut :
                   (E_csrEnable ? csrOut : aluOut); // FADD/FSUB or CSR or integer ALU
    end


    // ------------------------------------------------------------
    // Unit: Jump/Branch Unit
    // Computes jump or branch target address
    // ------------------------------------------------------------
    assign jbSrcA = (E_jbSelA) ? rs1Data : E_pc;
    jbUnit jbu (
        // input
        .src1               (jbSrcA),
        .src2               (E_sext_imm),
        // output
        .jbTarget           (jbTarget)
    );

    assign E_correctTarget = (E_correctTargetSel) ? (E_pc + 32'd4) :jbTarget;


    // ------------------------------------------------------------
    // Unit: EX-MEM Pipeline Register
    // Stores execution stage results for the Memory stage
    // ------------------------------------------------------------
    EXMEM exmem (
        // input
        .clk                (clk),
        .rst                (rst),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .E_op               (E_op),
        .E_func             (E_func),
        .E_rd               (E_rd),
        .E_aluOut           (E_aluOut),
        .E_rs2_data         (rs2Data),
        // output
        .M_op               (M_op),
        .M_func3            (M_func3),
        .M_rd               (M_rd),
        .M_aluOut           (M_aluOut),
        .M_rs2_data         (M_rs2_data)
    );


    // ============================================================
    // Memory Access(MEM)
    // ============================================================

    // ------------------------------------------------------------
    // Unit: Data Memory Interface
    // Generates memory address and control signals for load/store
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            DMEnable    <= 1'b0;
        end else if (IM_stall && ~DM_stall) begin
            DMEnable    <= 1'b0;
        end else if (~(IM_stall || DM_stall))begin
            DMEnable    <= (((E_op == `OP_I_LOAD) || (E_op == `OP_FLW)) && (E_rd != 5'd0)) || (E_op == `OP_S_TYPE) || (E_op == `OP_FSW);
        end
    end

    always_comb begin
        DM_A = M_aluOut;
        DM_CEB = ~DMEnable;
        DM_WEB = ~(M_op == `OP_S_TYPE || M_op == `OP_FSW);
    end

    // ------------------------------------------------------------
    // Unit: Store Data Filter
    // Prepares store data and byte-enable signals for memory
    // ------------------------------------------------------------
    storeFilter storeFilter (
        // input
        .byteOffset         (M_aluOut[1:0]),
        .opcode             (M_op),
        .func3              (M_func3),
        .storeData          (M_rs2_data),
        // output
        .memData            (WriteData),
        .memWriteMask       (DM_BWEB)
    );


    // ------------------------------------------------------------
    // Unit: MEM-WB Register
    // Stores memory and ALU results for Writeback stage
    // ------------------------------------------------------------
    MEMWB memwb (
        // input
        .clk                (clk),
        .rst                (rst),
        .IM_stall           (IM_stall),
        .DM_stall           (DM_stall),
        .M_op               (M_op),
        .M_rd               (M_rd),
        .M_func3            (M_func3),
        .M_aluOut           (M_aluOut),
        .M_ReadData         (ReadData),
        // output
        .W_op               (W_op),
        .W_rd               (W_rd),
        .W_func3            (W_func3),
        .W_aluOut           (W_aluOut),
        .W_ReadData         (W_ReadData)
    );


    // ============================================================
    // Writeback (WB)
    // ============================================================

    // ------------------------------------------------------------
    // Unit: Control Signal Generator (Writeback)
    // Generates control signals for register writeback
    // ------------------------------------------------------------
    controlWB ctrwb (
        // input
        .W_op               (W_op),
        // output
        .W_wbSel            (W_wbSel),
        .W_wbEnable         (W_wbEnable),
        .W_fwbEnable        (W_fwbEnable)
    );


    // ------------------------------------------------------------
    // Unit: Load Data Filter
    // Processes loaded memory data for floating-point instructions
    // ------------------------------------------------------------
    loadFilter loadFilter (
        // input
        .memData            (W_ReadData),
        .func3              (W_func3),
        // output
        .loadData           (loadData)
    );


    // ------------------------------------------------------------
    // Unit: Writeback Data Selection
    // Chooses writeback data from ALU output or memory load
    // ------------------------------------------------------------
    always_comb begin
        W_wbData = W_wbSel ? loadData : W_aluOut;
    end


endmodule