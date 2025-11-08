module branchPredictorGshare#(
    parameter int BTB_ENTRIES = 16,
    parameter int PHT_ENTRIES = 16
  ) (
    input  logic         clk,
    input  logic         rst,
    input  logic         IM_stall,
    input  logic         DM_stall,
    input  logic [15:0]  fetchPc,
    output logic         fetchHit,
    output logic [15:0]  fetchTarget,
    input  logic [1:0]   exBranchType,  // 00: others, 01: JAL, 10: Btype
    input  logic         exTaken,
    input  logic [15:0]  exPc,
    input  logic [15:0]  exTarget
  );

  // ============================================================
  // Local parameters and types
  // ============================================================
  localparam int PC_WIDTH        = 16;
  localparam int LOW_IGNORED     = 2;
  localparam int GHR_WIDTH       = (PHT_ENTRIES > 1) ? $clog2(PHT_ENTRIES) : 1;
  localparam int BTB_INDEX_WIDTH = (BTB_ENTRIES > 1) ? $clog2(BTB_ENTRIES) : 1;
  localparam int BTB_TAG_WIDTH   = PC_WIDTH - BTB_INDEX_WIDTH - LOW_IGNORED;

  typedef struct packed {
            logic valid;
            logic [BTB_TAG_WIDTH-1:0] tag;
            logic [15:0] target;
            logic isJAL;
          } btb_entry;

  // ============================================================
  // Memory and signal declarations
  // ============================================================
  btb_entry btb_mem [BTB_ENTRIES-1:0];
  logic [1:0] pht_mem [PHT_ENTRIES-1:0];

  logic [GHR_WIDTH-1:0] ghr,pcBitsGhrFetch,pcBitsGhrEx,phtIndexEx,phtIndexFetch;
  logic [BTB_INDEX_WIDTH-1:0] fetchIndex;
  logic [BTB_TAG_WIDTH-1:0]   fetchTag;
  logic [BTB_INDEX_WIDTH-1:0] exIndex;
  logic [BTB_TAG_WIDTH-1:0]   exTag;
  logic exHit;
  logic isJAL_fetch;

  logic [1:0] nextCount,count,countF;
  localparam [1:0]
             sTaken = 2'b10,
             wTaken = 2'b00, //default taken
             wNtaken = 2'b01,
             sNtaken = 2'b11;

  // ============================================================
  // Combinational logic for indices, tags, and predictions
  // ============================================================
  assign exIndex        = exPc[BTB_INDEX_WIDTH + 1 : 2];
  assign exTag          = exPc[15 : BTB_INDEX_WIDTH + 2];
  assign pcBitsGhrFetch = fetchPc[GHR_WIDTH + 1 : 2];
  assign pcBitsGhrEx    = exPc[GHR_WIDTH + 1 : 2];
  assign phtIndexFetch  = pcBitsGhrFetch ^ ghr;
  assign phtIndexEx     = pcBitsGhrEx ^ ghr;
  assign count          = pht_mem[phtIndexEx];
  assign countF         = pht_mem[phtIndexFetch];
  assign fetchIndex     = fetchPc[BTB_INDEX_WIDTH + 1 : 2];
  assign fetchTag       = fetchPc[15 : BTB_INDEX_WIDTH + 2];
  assign exHit          = btb_mem[exIndex].valid && (btb_mem[exIndex].tag == exTag);
  assign isJAL_fetch    = btb_mem[fetchIndex].isJAL;
  assign fetchHit       = btb_mem[fetchIndex].valid && (btb_mem[fetchIndex].tag == fetchTag) && (isJAL_fetch || !countF[0]);
  assign fetchTarget    = btb_mem[fetchIndex].target;

  // ============================================================
  // Sequential logic for reset and updates
  // ============================================================
  integer i;
  always_ff@(posedge clk or posedge rst)
  begin
    if (rst) begin
      ghr <= {GHR_WIDTH{1'b0}};  // Reset GHR to all zeros
      for (i = 0; i < BTB_ENTRIES; i=i+1) begin
          btb_mem[i].valid  <= 1'b0;
          btb_mem[i].tag    <= {BTB_TAG_WIDTH{1'b0}};
          btb_mem[i].target <= 16'b0;
          btb_mem[i].isJAL  <= 1'b0;
      end
      for (i = 0; i < PHT_ENTRIES; i=i+1) begin
          pht_mem[i] <= wTaken; // Initialize PHT to weakly taken
      end
    end else if (~(IM_stall || DM_stall)) begin
      if (exBranchType == 2'b10) begin  // Handle btype branches
        ghr <= {ghr[GHR_WIDTH-1:1], exTaken}; // Update GHR with taken bit
        if (exHit) begin
          pht_mem[phtIndexEx] <= nextCount; // Update existing PHT entry
        end else begin
          // Allocate new BTB entry for btype
          btb_mem[exIndex].valid  <= 1'b1;
          btb_mem[exIndex].tag    <= exTag;
          btb_mem[exIndex].target <= exTarget;
          btb_mem[exIndex].isJAL  <= 1'b0;
          pht_mem[phtIndexEx] <= exTaken ? wTaken : wNtaken; // Initialize PHT for new entry
        end
      end else if (exBranchType == 2'b01) begin  // Handle JAL
        if (!exHit) begin
          // Allocate new BTB entry for JAL
          btb_mem[exIndex].valid  <= 1'b1;
          btb_mem[exIndex].tag    <= exTag;
          btb_mem[exIndex].target <= exTarget;
          btb_mem[exIndex].isJAL  <= 1'b1;
        end
      end
    end
  end

  // ============================================================
  // Combinational logic for next PHT count
  // ============================================================
  always_comb
  begin
    case (count)
      wTaken:
        nextCount = exTaken?sTaken:wNtaken;
      sTaken:
        nextCount = exTaken?count:wTaken;
      wNtaken:
        nextCount = exTaken?wTaken:sNtaken;
      sNtaken:
        nextCount = exTaken?wNtaken:count;
    endcase
  end

endmodule