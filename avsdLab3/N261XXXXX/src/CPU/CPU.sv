`include "../include/AXI_define.svh"
`include "../include/CPU_define.svh"

`include "../src/CPU/Controller_ID.sv"
`include "../src/CPU/Controller_EX.sv"
`include "../src/CPU/Controller_WB.sv"

`include "../src/CPU/IFID.sv"
`include "../src/CPU/IDEX.sv"
`include "../src/CPU/EXMEM.sv"
`include "../src/CPU/MEMWB.sv"

`include "../src/CPU/Hazard_Detector.sv"
`include "../src/CPU/Branch_Predictor.sv"
`include "../src/CPU/Program_Counter.sv"
`include "../src/CPU/Decoder.sv"
`include "../src/CPU/Register_File.sv"
`include "../src/CPU/Immediate_Generator.sv"
`include "../src/CPU/ALU.sv"
`include "../src/CPU/FPU.sv"
`include "../src/CPU/CSR_File.sv"
`include "../src/CPU/Load_Filter.sv"
`include "../src/CPU/Store_Filter.sv"

module CPU (
    input  logic        clk,
    input  logic        rst,

    input  logic        DMA_interrupt,
    input  logic        WTO_interrupt,

    input  logic [31:0] IF_RdData,
    input  logic        IF_DONE,
    input  logic [31:0] MEM_RdData,
    input  logic        MEM_DONE,

    output logic        IF_VALID,
    output logic [31:0] IF_ADDR,
    output logic        MEM_VALID,
    output logic [31:0] MEM_ADDR,
    output logic [31:0] MEM_WrData,
    output logic        MEM_WEB,
    output logic [ 3:0] MEM_STRB
);
    // ============================================================
    // Local Signals
    // ============================================================
    // -------------------------------------
    // IF Stage
    // -------------------------------------
    logic [31:0]    IF_pc;
    logic           IF_pTaken;
    logic [31:0]    IF_pTarget;

    // -------------------------------------
    // ID Stage
    // -------------------------------------
    logic [31:0]    ID_pc;
    logic [31:0]    ID_inst;
    logic           ID_pTaken;
    logic [ 4:0]    ID_rs1, ID_rs2, ID_rd;
    logic [ 4:0]    ID_op;
    logic [ 3:0]    ID_func;
    logic           ID_is_mtype, ID_is_fsub;
    logic           ID_WFI, ID_MRET;
    logic [11:0]    ID_csrIdx;
    logic [31:0]    ID_Forward_rs1data, ID_Forward_rs2data;
    logic [31:0]    ID_rs1_data,ID_rs2_data;
    logic [31:0]    ID_Imm;
    logic           ID_use_rs1, ID_use_rs2;
    logic           ID_use_frs1, ID_use_frs2;

    // -------------------------------------
    // EX Stage
    // -------------------------------------
    logic [31:0]    EX_pc;
    logic           EX_pTaken, EX_rTaken;
    logic [ 4:0]    EX_rs1, EX_rs2, EX_rd;
    logic [ 4:0]    EX_op;
    logic [ 3:0]    EX_func;
    logic           EX_is_mtype, EX_is_fsub;
    logic           EX_WFI, EX_MRET;
    logic [11:0]    EX_csrIdx;
    logic [31:0]    EX_rs1_data, EX_rs2_data;
    logic [31:0]    EX_Imm;
    logic [ 1:0]    EX_bType;
    logic           EX_aluSelA, EX_aluSelB, EX_jbSelA, EX_csrSelB;
    logic           EX_csrEnable, EX_cTargetSel;
    logic [31:0]    EX_ALU_src1, EX_ALU_src2, EX_CSR_src2;
    logic [31:0]    EX_JB_src1;
    logic [31:0]    EX_Forward_rs1data, EX_Forward_rs2data;
    logic [31:0]    aluOut, fpuOut, csrOut;
    logic [31:0]    EX_aluOut;
    logic [31:0]    EX_cTarget;
    logic [31:0]    EX_bTarget;
    logic           EX_interrupt_taken, EX_interrupt_return, EX_IF_VALIDn;
    logic           EX_MIE, EX_MEIE, EX_MTIE, EX_MEIP, EX_MTIP;
    logic [31:0]    EX_MTVEC, EX_MEPC, EX_mepc, EX_fTarget;

    // -------------------------------------
    // MEM Stage
    // -------------------------------------
    logic [ 4:0]    MEM_rd;
    logic [ 4:0]    MEM_op;
    logic [ 2:0]    MEM_func3;
    logic [31:0]    MEM_aluOut;
    logic [31:0]    MEM_rs2_data;

    // -------------------------------------
    // WB Stage
    // -------------------------------------
    logic [ 4:0]    WB_rd;
    logic [ 4:0]    WB_op;
    logic [ 2:0]    WB_func3;
    logic [31:0]    WB_aluOut;
    logic [31:0]    WB_ReadData;
    logic           WB_wbSel;
    logic           WB_wbEnable;
    logic           WB_fwbEnable;
    logic [31:0]    WB_wbData;
    logic [31:0]    WB_loadData;

    // -------------------------------------
    // Hazard
    // -------------------------------------
    logic           ID_fwdA, ID_fwdB;
    logic [ 1:0]    EX_fwdA, EX_fwdB;
    logic           loadStall;
    // -------------------------------------
    // Interface
    // -------------------------------------
    logic          IF_VALIDn;

    // -------------------------------------
    // Stall / Flush
    // -------------------------------------
    logic           stallIF, stallID, stallEX, stallCSR;
    logic           flushIF, flushID, flushEX, flushCSR;




    // ============================================================
    // Hazard Detection
    // ============================================================
    Hazard_Detector hazard (
        .ID_rs1              (ID_rs1              ),
        .ID_rs2              (ID_rs2              ),
        .ID_use_rs1          (ID_use_rs1          ),
        .ID_use_rs2          (ID_use_rs2          ),
        .ID_use_frs1         (ID_use_frs1         ),
        .ID_use_frs2         (ID_use_frs2         ),
        .EX_op               (EX_op               ),
        .EX_rd               (EX_rd               ),
        .EX_rs1              (EX_rs1              ),
        .EX_rs2              (EX_rs2              ),
        .MEM_op              (MEM_op              ),
        .MEM_rd              (MEM_rd              ),
        .WB_op               (WB_op               ),
        .WB_rd               (WB_rd               ),

        .ID_fwdA             (ID_fwdA             ),
        .ID_fwdB             (ID_fwdB             ),
        .EX_fwdA             (EX_fwdA             ),
        .EX_fwdB             (EX_fwdB             ),
        .loadStall           (loadStall           )
    );

    // ============================================================
    // Instruction Fetch (IF)
    // ============================================================

    // ------------------------------------------------------------
    // Branch Predictor
    // ------------------------------------------------------------
    Branch_Predictor branchPredictor (
        .clk                (clk                ),
        .rst                (rst                ),
        .IF_DONE            (IF_DONE            ),
        .MEM_DONE           (MEM_DONE           ),
        .DMA_interrupt      (DMA_interrupt      ),
	    .WTO_interrupt      (WTO_interrupt      ),

        .IF_PC              (IF_pc              ),
        .EX_PC              (EX_pc              ),
        .EX_bType           (EX_bType           ),
        .EX_rTaken          (EX_rTaken          ),
        .EX_bTarget         (EX_bTarget         ),

        .IF_pTaken          (IF_pTaken          ),
        .IF_pTarget         (IF_pTarget         )
    );


    // ------------------------------------------------------------
    // Program Counter
    // ------------------------------------------------------------
    Program_Counter pcu (
        .clk                (clk                ),
        .rst                (rst                ),
        .IF_DONE            (IF_DONE            ),
        .MEM_DONE           (MEM_DONE           ),

        .stall              (stallIF            ),
        .flush              (flushIF            ),
        .pTaken             (IF_pTaken          ),
        .pTarget            (IF_pTarget         ),
        .fTarget            (EX_fTarget         ),

        .pc                 (IF_pc              )
    );

    // ------------------------------------------------------------
    // Instruction Memory (IM) Interface
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            IF_VALIDn <= 1'b0;
        end else if (IF_DONE && ~MEM_DONE) begin
            IF_VALIDn <= 1'b1;
        end else if (IF_DONE && MEM_DONE)begin
            IF_VALIDn <= EX_IF_VALIDn;
        end
    end

    always_comb begin
        IF_VALID = ~IF_VALIDn;
        IF_ADDR = IF_pc;
    end

    // ------------------------------------------------------------
    // IF-ID Pipeline Register
    // ------------------------------------------------------------
    IFID ifid (
        .clk                (clk                ),
        .rst                (rst                ),
        .IF_DONE            (IF_DONE            ),
        .MEM_DONE           (MEM_DONE           ),

        .stall              (stallID            ),
        .flush              (flushID            ),

        .IF_pc              (IF_pc              ),
        .IF_inst            (IF_RdData          ),
        .IF_pTaken          (IF_pTaken          ),

        .ID_pc              (ID_pc              ),
        .ID_inst            (ID_inst            ),
        .ID_pTaken          (ID_pTaken          )
    );


    // ============================================================
    // Instruction Decode (ID)
    // ============================================================

    // ------------------------------------------------------------
    // ID Controller
    // ------------------------------------------------------------
    Controller_ID ctrid (
        // input
        .ID_op               (ID_op               ),
        .ID_rs1              (ID_rs1              ),
        .ID_rs2              (ID_rs2              ),

        .ID_use_rs1          (ID_use_rs1          ),
        .ID_use_rs2          (ID_use_rs2          ),
        .ID_use_frs1         (ID_use_frs1         ),
        .ID_use_frs2         (ID_use_frs2         )
    );


    // ------------------------------------------------------------
    // Instruction Decoder
    // ------------------------------------------------------------
    Decoder Decoder (
        .inst               (ID_inst             ),

        .rs1_index          (ID_rs1              ),
        .rs2_index          (ID_rs2              ),
        .rd_index           (ID_rd               ),
        .opcode             (ID_op               ),
        .func               (ID_func             ),
        .is_mtype           (ID_is_mtype         ),
        .is_fsub            (ID_is_fsub          ),
        .csrIdx             (ID_csrIdx           ),
        .WFI                (ID_WFI              ),
        .MRET               (ID_MRET             )
    );

    // ------------------------------------------------------------
    // Immediate Generator
    // ------------------------------------------------------------
    Immediate_Generator immGenerator (
        .inst               (ID_inst             ),
        .imm                (ID_Imm              )
    );


    // ------------------------------------------------------------
    // Register File (Integer and Float)
    // ------------------------------------------------------------
    Register_File regFile (
        .clk                (clk                 ),
        .rst                (rst                 ),
        .int_wen            (WB_wbEnable         ),
        .fp_wen             (WB_fwbEnable        ),
        .fpA_ren            (ID_use_frs1         ),
        .fpB_ren            (ID_use_frs2         ),
        .rs1_idx            (ID_rs1              ),
        .rs2_idx            (ID_rs2              ),
        .rd_idx             (WB_rd               ),
        .wr_data            (WB_wbData           ),

        .rs1_data           (ID_rs1_data         ),
        .rs2_data           (ID_rs2_data         )
    );


    // ------------------------------------------------------------
    // Forwarding
    // ------------------------------------------------------------
    always_comb begin
        ID_Forward_rs1data = ID_fwdA ? WB_wbData : ID_rs1_data;
        ID_Forward_rs2data = ID_fwdB ? WB_wbData : ID_rs2_data;
    end

    // ------------------------------------------------------------
    // ID-EX Pipeline Register
    // ------------------------------------------------------------
    IDEX idex (
        // input
        .clk                (clk                 ),
        .rst                (rst                 ),
        .IF_DONE            (IF_DONE             ),
        .MEM_DONE           (MEM_DONE            ),
        .stall              (stallEX             ),
        .flush              (flushEX             ),

        .ID_pc              (ID_pc               ),
        .ID_op              (ID_op               ),
        .ID_func            (ID_func             ),
        .ID_rd              (ID_rd               ),
        .ID_rs1             (ID_rs1              ),
        .ID_rs2             (ID_rs2              ),
        .ID_is_mtype        (ID_is_mtype         ),
        .ID_is_fsub         (ID_is_fsub          ),
        .ID_csrIdx          (ID_csrIdx           ),
        .ID_rs1_data        (ID_Forward_rs1data  ),
        .ID_rs2_data        (ID_Forward_rs2data  ),
        .ID_Imm             (ID_Imm              ),
        .ID_pTaken          (ID_pTaken           ),
        .ID_WFI             (ID_WFI              ),
        .ID_MRET            (ID_MRET             ),

        .EX_pc              (EX_pc               ),
        .EX_op              (EX_op               ),
        .EX_func            (EX_func             ),
        .EX_rd              (EX_rd               ),
        .EX_rs1             (EX_rs1              ),
        .EX_rs2             (EX_rs2              ),
        .EX_is_mtype        (EX_is_mtype         ),
        .EX_is_fsub         (EX_is_fsub          ),
        .EX_csrIdx          (EX_csrIdx           ),
        .EX_rs1_data        (EX_rs1_data         ),
        .EX_rs2_data        (EX_rs2_data         ),
        .EX_Imm             (EX_Imm              ),
        .EX_pTaken          (EX_pTaken           ),
        .EX_WFI             (EX_WFI              ),
        .EX_MRET            (EX_MRET             )

    );


    // ============================================================
    // Execute (EX)
    // ============================================================

    // ------------------------------------------------------------
    // EX Controller
    // ------------------------------------------------------------
    Controller_EX ctrex (
        .EX_op               (EX_op               ),
        .EX_rd               (EX_rd               ),
        .EX_rs1              (EX_rs1              ),
        .EX_rs2              (EX_rs2              ),
        .EX_func             (EX_func             ),
        .EX_bFlag            (EX_aluOut[0]        ),
        .EX_pTaken           (EX_pTaken           ),
        .loadStall           (loadStall           ),
        .EX_cTarget          (EX_cTarget          ),
        .EX_pc               (EX_pc               ),
        .EX_WFI              (EX_WFI              ),
        .EX_MRET             (EX_MRET             ),
        .EX_MIE              (EX_MIE              ),
        .EX_MEIE             (EX_MEIE             ),
        .EX_MTIE             (EX_MTIE             ),
        .EX_MEIP             (EX_MEIP             ),
        .EX_MTIP             (EX_MTIP             ),
        .EX_MTVEC            (EX_MTVEC            ),
        .EX_MEPC             (EX_MEPC             ),

        .EX_rTaken           (EX_rTaken           ),
        .EX_cTargetSel       (EX_cTargetSel       ),
        .EX_bType            (EX_bType            ),
        .EX_aluSelA          (EX_aluSelA          ),
        .EX_aluSelB          (EX_aluSelB          ),
        .EX_jbSelA           (EX_jbSelA           ),
        .EX_csrEn            (EX_csrEn            ),
        .EX_csrSelB          (EX_csrSelB          ),
        .EX_interrupt_taken  (EX_interrupt_taken  ),
        .EX_interrupt_return (EX_interrupt_return ),
        .EX_flush_pc         (EX_fTarget          ),
        .EX_mepc             (EX_mepc             ),
        .EX_IF_VALIDn        (EX_IF_VALIDn        ),

        .stallIF             (stallIF             ),
        .stallID             (stallID             ),
        .stallEX             (stallEX             ),
        .stallCSR            (stallCSR            ),
        .flushIF             (flushIF             ),
        .flushID             (flushID             ),
        .flushEX             (flushEX             ),
        .flushCSR            (flushCSR            )
    );


    // ------------------------------------------------------------
    // Forwarding
    // ------------------------------------------------------------
    always_comb begin
        case (EX_fwdA)
            2'd0: EX_Forward_rs1data = EX_rs1_data;
            2'd1: EX_Forward_rs1data = MEM_aluOut;
            2'd2: EX_Forward_rs1data = WB_wbData;
            default: EX_Forward_rs1data = 32'd0;
        endcase

        case (EX_fwdB)
            2'd0: EX_Forward_rs2data = EX_rs2_data;
            2'd1: EX_Forward_rs2data = MEM_aluOut;
            2'd2: EX_Forward_rs2data = WB_wbData;
            default: EX_Forward_rs2data = 32'd0;
        endcase
    end


    // ------------------------------------------------------------
    // ALU Source Selection
    // ------------------------------------------------------------
    always_comb begin
        EX_ALU_src1 = EX_aluSelA ? EX_pc  : EX_Forward_rs1data;
        EX_ALU_src2 = EX_aluSelB ? EX_Imm : EX_Forward_rs2data;
    end

    // ------------------------------------------------------------
    // CSR Source Selection
    // ------------------------------------------------------------
    always_comb begin
        EX_CSR_src2 = EX_csrSelB ? EX_Imm : EX_Forward_rs1data;
    end
    // ------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------
    ALU ALU (
        .src1               (EX_ALU_src1         ),
        .src2               (EX_ALU_src2         ),
        .opcode             (EX_op               ),
        .func               (EX_func             ),
        .is_mtype           (EX_is_mtype         ),

        .aluOut             (aluOut              )
    );


    // ------------------------------------------------------------
    // Floating-Point Unit
    // ------------------------------------------------------------
    FPU FPU (
        .src1               (EX_Forward_rs1data  ),
        .src2               (EX_Forward_rs2data  ),
        .sub                (EX_is_fsub          ),

        .fpuOut             (fpuOut              )
    );


    // ------------------------------------------------------------
    // CSR Register File
    // ------------------------------------------------------------
    CSR_File CSR_File (
        .clk                (clk                ),
        .rst                (rst                ),
        .IF_DONE            (IF_DONE            ),
        .MEM_DONE           (MEM_DONE           ),

        .DMA_interrupt      (DMA_interrupt      ),
	    .WTO_interrupt      (WTO_interrupt      ),
        .interrupt_taken    (EX_interrupt_taken ),
        .interrupt_return   (EX_interrupt_return),
        .EX_mepc            (EX_mepc            ),

        .enable             (EX_csrEn           ),
        .stall              (stallCSR           ),
        .flush              (flushCSR           ),
        .func3              (EX_func[3:1]       ),
        .csrIdx             (EX_csrIdx          ),
        .src2               (EX_CSR_src2        ),

        .csrOut             (csrOut             ),
        .MIE                (EX_MIE             ),
        .MEIE               (EX_MEIE            ),
        .MTIE               (EX_MTIE            ),
        .MEIP               (EX_MEIP            ),
        .MTIP               (EX_MTIP            ),
        .MTVEC              (EX_MTVEC           ),
        .MEPC               (EX_MEPC            )
    );


    // ------------------------------------------------------------
    // Execute Stage Output Selection
    // ------------------------------------------------------------
    always_comb begin
        EX_aluOut = (EX_op == `OP_FTYPE) ? fpuOut :
                    (EX_op == `OP_CSR    ? csrOut : aluOut);
    end


    // ------------------------------------------------------------
    // Next PC Logic
    // ------------------------------------------------------------
    assign EX_JB_src1 = (EX_jbSelA) ? EX_Forward_rs1data : EX_pc;
    assign EX_bTarget = (EX_JB_src1 + EX_Imm) & (~32'd3);
    assign EX_cTarget = (EX_cTargetSel) ? (EX_pc + 32'd4) : EX_bTarget;


    // ------------------------------------------------------------
    // EX-MEM Pipeline Register
    // ------------------------------------------------------------
    EXMEM exmem (
        .clk                (clk                 ),
        .rst                (rst                 ),
        .IF_DONE            (IF_DONE             ),
        .MEM_DONE           (MEM_DONE            ),

        .EX_op              (EX_op               ),
        .EX_func            (EX_func             ),
        .EX_rd              (EX_rd               ),
        .EX_aluOut          (EX_aluOut           ),
        .EX_rs2_data        (EX_Forward_rs2data  ),

        .MEM_op             (MEM_op              ),
        .MEM_func3          (MEM_func3           ),
        .MEM_rd             (MEM_rd              ),
        .MEM_aluOut         (MEM_aluOut          ),
        .MEM_rs2_data       (MEM_rs2_data        )
    );


    // ============================================================
    // Memory Access(MEM)
    // ============================================================

    // ------------------------------------------------------------
    // Data Memory Interface
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_VALID <= 1'b0;
        end else if (~IF_DONE && MEM_DONE) begin
            MEM_VALID <= 1'b0;
        end else if (IF_DONE && MEM_DONE)begin
            MEM_VALID <= (  ((EX_op == `OP_I_LOAD) || (EX_op == `OP_FLW)) && (EX_rd != 5'd0)  ) || (EX_op == `OP_S_TYPE) || (EX_op == `OP_FSW);
        end
    end

    always_comb begin
        MEM_ADDR = MEM_aluOut;
        MEM_WEB  = (MEM_op == `OP_S_TYPE || MEM_op == `OP_FSW);
    end

    // ------------------------------------------------------------
    // Store Data Filter
    // ------------------------------------------------------------
    Store_Filter storeFilter (
        .byteOffset         (MEM_aluOut[1:0]      ),
        .opcode             (MEM_op               ),
        .func3              (MEM_func3            ),
        .storeData          (MEM_rs2_data         ),

        .memData            (MEM_WrData           ),
        .memWriteMask       (MEM_STRB             )
    );


    // ------------------------------------------------------------
    // MEM-WB Pipeline Register
    // ------------------------------------------------------------
    MEMWB memwb (
        .clk                (clk                ),
        .rst                (rst                ),
        .IF_DONE            (IF_DONE            ),
        .MEM_DONE           (MEM_DONE           ),

        .MEM_op             (MEM_op             ),
        .MEM_rd             (MEM_rd             ),
        .MEM_func3          (MEM_func3          ),
        .MEM_aluOut         (MEM_aluOut         ),
        .MEM_ReadData       (MEM_RdData         ),

        .WB_op              (WB_op              ),
        .WB_rd              (WB_rd              ),
        .WB_func3           (WB_func3           ),
        .WB_aluOut          (WB_aluOut          ),
        .WB_ReadData        (WB_ReadData        )
    );


    // ============================================================
    // Writeback (WB)
    // ============================================================

    // ------------------------------------------------------------
    // WB Controller
    // ------------------------------------------------------------
    Controller_WB ctrwb (
        .WB_op               (WB_op               ),

        .WB_wbSel            (WB_wbSel            ),
        .WB_wbEnable         (WB_wbEnable         ),
        .WB_fwbEnable        (WB_fwbEnable        )
    );

    // ------------------------------------------------------------
    // Load Data Filter
    // ------------------------------------------------------------
    Load_Filter loadFilter (
        .byteOffset         (WB_aluOut[1:0]      ),
        .memData            (WB_ReadData         ),
        .func3              (WB_func3            ),

        .loadData           (WB_loadData         )
    );

    // ------------------------------------------------------------
    // Writeback Data Selection
    // ------------------------------------------------------------
    always_comb begin
        WB_wbData = WB_wbSel ? WB_loadData : WB_aluOut;
    end


endmodule