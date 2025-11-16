`include "../../include/AXI_define.svh"

module Write #(
    parameter int NUM_M     = 3,
    parameter int NUM_S     = 6,
    parameter int MIDX_BITS = 3,
    parameter int SIDX_BITS = 2
) (
    // From Arbiter
    input  logic [SIDX_BITS-1:0] SWIdx [NUM_S:0],
    input  logic [MIDX_BITS-1:0] MWIdx [NUM_M-1:0],

    // Master AW channels (inputs from masters, padded with dummy)
    input  logic [NUM_M:0][`AXI_ID_BITS-1:0]      AWID_M,
    input  logic [NUM_M:0][`AXI_ADDR_BITS-1:0]    AWADDR_M,
    input  logic [NUM_M:0][`AXI_LEN_BITS-1:0]     AWLEN_M,
    input  logic [NUM_M:0][`AXI_SIZE_BITS-1:0]    AWSIZE_M,
    input  logic [NUM_M:0][1:0]                   AWBURST_M,
    input  logic [NUM_M:0]                        AWVALID_M,
    output logic [NUM_M-1:0]                      AWREADY_M,

    // Slave AW channels (outputs to slaves)
    output logic [NUM_S:0][`AXI_IDS_BITS-1:0]     AWID_S,
    output logic [NUM_S:0][`AXI_ADDR_BITS-1:0]    AWADDR_S,
    output logic [NUM_S:0][`AXI_LEN_BITS-1:0]     AWLEN_S,
    output logic [NUM_S:0][`AXI_SIZE_BITS-1:0]    AWSIZE_S,
    output logic [NUM_S:0][1:0]                   AWBURST_S,
    output logic [NUM_S:0]                        AWVALID_S,
    input  logic [NUM_S+1:0]                      AWREADY_S,

    // Master W channels (inputs from masters, padded with dummy)
    input  logic [NUM_M:0][`AXI_DATA_BITS-1:0]    WDATA_M,
    input  logic [NUM_M:0][`AXI_STRB_BITS-1:0]    WSTRB_M,
    input  logic [NUM_M:0]                        WLAST_M,
    input  logic [NUM_M:0]                        WVALID_M,
    output logic [NUM_M-1:0]                      WREADY_M,

    // Slave W channels (outputs to slaves)
    output logic [NUM_S:0][`AXI_DATA_BITS-1:0]    WDATA_S,
    output logic [NUM_S:0][`AXI_STRB_BITS-1:0]    WSTRB_S,
    output logic [NUM_S:0]                        WLAST_S,
    output logic [NUM_S:0]                        WVALID_S,
    input  logic [NUM_S+1:0]                      WREADY_S,

    // Master B channels (outputs to masters)
    output logic [NUM_M-1:0][`AXI_ID_BITS-1:0]    BID_M,
    output logic [NUM_M-1:0][1:0]                 BRESP_M,
    output logic [NUM_M-1:0]                      BVALID_M,
    input  logic [NUM_M:0]                        BREADY_M,

    // Slave B channels (inputs from slaves)
    input  logic [NUM_S+1:0][`AXI_IDS_BITS-1:0]   BID_S,
    input  logic [NUM_S+1:0][1:0]                 BRESP_S,
    input  logic [NUM_S+1:0]                      BVALID_S,
    output logic [NUM_S:0]                        BREADY_S
);

    localparam logic [`AXI_ADDR_BITS-1:0] S_BEGIN [0:NUM_S+1] = '{
        32'h0000_0000, // XX: NONE
        32'h0000_0000, // S0: ROM
        32'h0001_0000, // S1: IM
        32'h0002_0000, // S2: DM
        32'h1002_0000, // S3: DMA 32'h1002_0000
        32'h1001_0000, // S4: WDT 32'h1001_0000
        32'h2000_0000, // S5: DRAM
        32'h0000_0000  // S6: DEFAULT
    };


    // Combinational multiplexing for AW, W, and B channels
    always_comb begin
        // Assignments for slaves
        for (int s = 0; s < NUM_S+1; s++) begin
            AWID_S[s]    = {4'd0, AWID_M[SWIdx[s]]};
            AWADDR_S[s]  = AWADDR_M[SWIdx[s]] - S_BEGIN[s+1];
            AWLEN_S[s]   = AWLEN_M[SWIdx[s]];
            AWSIZE_S[s]  = AWSIZE_M[SWIdx[s]];
            AWBURST_S[s] = AWBURST_M[SWIdx[s]];
            AWVALID_S[s] = AWVALID_M[SWIdx[s]];
            WDATA_S[s]   = WDATA_M[SWIdx[s]];
            WSTRB_S[s]   = WSTRB_M[SWIdx[s]];
            WLAST_S[s]   = WLAST_M[SWIdx[s]];
            WVALID_S[s]  = WVALID_M[SWIdx[s]];
            BREADY_S[s]  = BREADY_M[SWIdx[s]];
        end

        // Assignments for masters
        for (int m = 0; m < NUM_M; m++) begin
            AWREADY_M[m] = AWREADY_S[MWIdx[m]];
            WREADY_M[m]  = WREADY_S[MWIdx[m]];
            BID_M[m]     = BID_S[MWIdx[m]][`AXI_ID_BITS-1:0];
            BRESP_M[m]   = BRESP_S[MWIdx[m]];
            BVALID_M[m]  = BVALID_S[MWIdx[m]];
        end
    end

endmodule