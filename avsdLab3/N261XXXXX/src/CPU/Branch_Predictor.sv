module Branch_Predictor#(
    parameter int BTB_ENTRIES = 16,
    parameter int PHT_ENTRIES = 16
) (
    input  logic         clk,
    input  logic         rst,
    input  logic         IF_DONE,
    input  logic         MEM_DONE,
    input  logic [31:0]  IF_PC,
    output logic         IF_pTaken,
    output logic [31:0]  IF_pTarget,
    input  logic [1:0]   EX_bType,  // 00: others, 01: JAL, 10: Btype
    input  logic         EX_rTaken,
    input  logic [31:0]  EX_PC,
    input  logic [31:0]  EX_bTarget
);

    // ============================================================
    // Local Parameters
    // ============================================================
    localparam int PC_WIDTH        = 32;
    localparam int LOW_IGNORED     = 2;
    localparam int GHR_WIDTH       = (PHT_ENTRIES > 1) ? $clog2(PHT_ENTRIES) : 1;
    localparam int BTB_INDEX_WIDTH = (BTB_ENTRIES > 1) ? $clog2(BTB_ENTRIES) : 1;
    localparam int BTB_TAG_WIDTH   = PC_WIDTH - BTB_INDEX_WIDTH - LOW_IGNORED;

    localparam [1:0] sTaken  = 2'b10;
    localparam [1:0] wTaken  = 2'b10;
    localparam [1:0] wNtaken = 2'b01;
    localparam [1:0] sNtaken = 2'b11;

    // ============================================================
    // BTB Memory
    // ============================================================
    typedef struct packed {
        logic                     valid;
        logic [BTB_TAG_WIDTH-1:0] tag;
        logic [31:0]              target;
        logic                     isJAL;
    } btb_entry;

    btb_entry btb_mem [BTB_ENTRIES-1:0];

    // ============================================================
    // PHT Memory and Global History Register
    // ============================================================
    logic [1:0]                 pht_mem [PHT_ENTRIES-1:0];
    logic [GHR_WIDTH-1:0]       ghr;

    // ============================================================
    // Local Signals
    // ============================================================
    logic [GHR_WIDTH-1:0]       IF_LPC, IF_PHTIdx;
    logic [GHR_WIDTH-1:0]       EX_LPC, EX_PHTIdx;
    logic [BTB_INDEX_WIDTH-1:0] IF_BTBIdx, EX_BTBIdx;
    logic [BTB_TAG_WIDTH-1:0]   IF_tag, EX_tag;
    logic                       IF_JAL, BTB_hit;

    logic [1:0]                 EX_count,IF_count;
    logic [1:0]                 nextCount;

    // ============================================================
    // BTB Index & Tag
    // ============================================================
    assign EX_BTBIdx  = EX_PC[BTB_INDEX_WIDTH + 1 : 2];
    assign EX_tag     = EX_PC[31 : BTB_INDEX_WIDTH + 2];
    assign IF_BTBIdx  = IF_PC[BTB_INDEX_WIDTH + 1 : 2];
    assign IF_tag     = IF_PC[31 : BTB_INDEX_WIDTH + 2];

    // ============================================================
    // PHT Index (GHR XOR PC bits)
    // ============================================================
    assign IF_LPC     = IF_PC[GHR_WIDTH + 1 : 2];
    assign EX_LPC     = EX_PC[GHR_WIDTH + 1 : 2];
    assign IF_PHTIdx  = IF_LPC ^ ghr;
    assign EX_PHTIdx  = EX_LPC ^ ghr;

    // ============================================================
    // BTB & PHT Read / IF Prediction
    // ============================================================
    assign EX_count   = pht_mem[EX_PHTIdx];
    assign IF_count   = pht_mem[IF_PHTIdx];
    assign BTB_hit    = btb_mem[EX_BTBIdx].valid && (btb_mem[EX_BTBIdx].tag == EX_tag);

    assign IF_JAL     = btb_mem[IF_BTBIdx].isJAL;
    assign IF_pTaken  = btb_mem[IF_BTBIdx].valid && (btb_mem[IF_BTBIdx].tag == IF_tag) && (IF_JAL || !IF_count[0]);
    assign IF_pTarget = btb_mem[IF_BTBIdx].target;


    // ============================================================
    // Reset and Update
    // ============================================================
    integer i;
    always_ff@(posedge clk or posedge rst) begin
        // ---------------------------------------
        // Reset
        // ---------------------------------------
        if (rst) begin
            ghr <= {GHR_WIDTH{1'b0}};
            for (i = 0; i < BTB_ENTRIES; i=i+1) begin
            btb_mem[i].valid  <= 1'b0;
            btb_mem[i].tag    <= {BTB_TAG_WIDTH{1'b0}};
            btb_mem[i].target <= 32'b0;
            btb_mem[i].isJAL  <= 1'b0;
            end
            for (i = 0; i < PHT_ENTRIES; i=i+1)
                pht_mem[i] <= wTaken;
        // ---------------------------------------
        // Update
        // ---------------------------------------
        end else if (IF_DONE && MEM_DONE) begin
            // Branch
            if (EX_bType == 2'b10) begin
                ghr <= {ghr[GHR_WIDTH-1:1], EX_rTaken};
                if (BTB_hit) begin
                    pht_mem[EX_PHTIdx]        <= nextCount;
                end else begin
                    pht_mem[EX_PHTIdx]        <= EX_rTaken ? wTaken : wNtaken;

                    btb_mem[EX_BTBIdx].valid  <= 1'b1;
                    btb_mem[EX_BTBIdx].tag    <= EX_tag;
                    btb_mem[EX_BTBIdx].target <= EX_bTarget;
                    btb_mem[EX_BTBIdx].isJAL  <= 1'b0;
                end
            // JAL
            end else if (EX_bType == 2'b01) begin
                if (!BTB_hit) begin
                    btb_mem[EX_BTBIdx].valid  <= 1'b1;
                    btb_mem[EX_BTBIdx].tag    <= EX_tag;
                    btb_mem[EX_BTBIdx].target <= EX_bTarget;
                    btb_mem[EX_BTBIdx].isJAL  <= 1'b1;
                end
            end
        end
    end

    // ============================================================
    // Bimodal Predictor
    // ============================================================
    always_comb begin
        case (EX_count)
            wTaken:  nextCount = EX_rTaken ? sTaken  : wNtaken;
            sTaken:  nextCount = EX_rTaken ? EX_count   : wTaken;
            wNtaken: nextCount = EX_rTaken ? wTaken  : sNtaken;
            sNtaken: nextCount = EX_rTaken ? wNtaken : EX_count;
        endcase
    end

endmodule