module Read #(
    parameter int NUM_M     = 3,
    parameter int NUM_S     = 6,
    parameter int MIDX_BITS = 3,
    parameter int SIDX_BITS = 2
) (
    // From Arbiter
    input  logic [SIDX_BITS-1:0] SRIdx [NUM_S:0],
    input  logic [MIDX_BITS-1:0] MRIdx [NUM_M-1:0],

    // Master AR channels (inputs from masters, padded with dummy)
    input  logic [NUM_M:0][`AXI_ID_BITS-1:0]      ARID_M,
    input  logic [NUM_M:0][`AXI_ADDR_BITS-1:0]    ARADDR_M,
    input  logic [NUM_M:0][`AXI_LEN_BITS-1:0]     ARLEN_M,
    input  logic [NUM_M:0][`AXI_SIZE_BITS-1:0]    ARSIZE_M,
    input  logic [NUM_M:0][1:0]                   ARBURST_M,
    input  logic [NUM_M:0]                        ARVALID_M,
    output logic [NUM_M-1:0]                      ARREADY_M,

    // Slave AR channels (outputs to slaves)
    output logic [NUM_S:0][`AXI_IDS_BITS-1:0]     ARID_S,
    output logic [NUM_S:0][`AXI_ADDR_BITS-1:0]    ARADDR_S,
    output logic [NUM_S:0][`AXI_LEN_BITS-1:0]     ARLEN_S,
    output logic [NUM_S:0][`AXI_SIZE_BITS-1:0]    ARSIZE_S,
    output logic [NUM_S:0][1:0]                   ARBURST_S,
    output logic [NUM_S:0]                        ARVALID_S,
    input  logic [NUM_S+1:0]                      ARREADY_S,

    // Master R channels (outputs to masters)
    output logic [NUM_M-1:0][`AXI_ID_BITS-1:0]    RID_M,
    output logic [NUM_M-1:0][`AXI_DATA_BITS-1:0]  RDATA_M,
    output logic [NUM_M-1:0][1:0]                 RRESP_M,
    output logic [NUM_M-1:0]                      RLAST_M,
    output logic [NUM_M-1:0]                      RVALID_M,
    input  logic [NUM_M:0]                        RREADY_M,

    // Slave R channels (inputs from slaves)
    input  logic [NUM_S+1:0][`AXI_IDS_BITS-1:0]   RID_S,
    input  logic [NUM_S+1:0][`AXI_DATA_BITS-1:0]  RDATA_S,
    input  logic [NUM_S+1:0][1:0]                 RRESP_S,
    input  logic [NUM_S+1:0]                      RLAST_S,
    input  logic [NUM_S+1:0]                      RVALID_S,
    output logic [NUM_S:0]                        RREADY_S
);

    localparam logic [`AXI_ADDR_BITS-1:0] S_BEGIN [0:NUM_S+1] = '{
        32'h0000_0000, // XX: NONE
        32'h0000_0000, // S0: ROM
        32'h0001_0000, // S1: IM
        32'h0002_0000, // S2: DM
        32'h1002_0000, // S3: DMA
        32'h1001_0000, // S4: WDT
        32'h2000_0000, // S5: DRAM
        32'h0000_0000  // S6: DEFAULT
    };

    // Combinational multiplexing for AR and R channels
    always_comb begin
        // Assignments for slaves
        for (int s = 0; s < NUM_S+1; s++) begin
            ARID_S[s]    = {4'd0, ARID_M[SRIdx[s]]};
            ARADDR_S[s]  = ARADDR_M[SRIdx[s]] - S_BEGIN[s+1];
            ARLEN_S[s]   = ARLEN_M[SRIdx[s]];
            ARSIZE_S[s]  = ARSIZE_M[SRIdx[s]];
            ARBURST_S[s] = ARBURST_M[SRIdx[s]];
            ARVALID_S[s] = ARVALID_M[SRIdx[s]];
            RREADY_S[s]  = RREADY_M[SRIdx[s]];
        end

        // Assignments for masters
        for (int m = 0; m < NUM_M; m++) begin
            ARREADY_M[m] = ARREADY_S[MRIdx[m]];
            RID_M[m]     = RID_S[MRIdx[m]][`AXI_ID_BITS-1:0];
            RDATA_M[m]   = RDATA_S[MRIdx[m]];
            RRESP_M[m]   = RRESP_S[MRIdx[m]];
            RLAST_M[m]   = RLAST_S[MRIdx[m]];
            RVALID_M[m]  = RVALID_S[MRIdx[m]];
        end
    end

endmodule