module Decoder #(
    parameter int NUM_M    = 3,
    parameter int NUM_S    = 6
) (
    // Master Inputs
    input  logic [NUM_M-1:0]                      ARVALID,
    input  logic [NUM_M-1:0]                      AWVALID,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0]  ARADDR,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0]  AWADDR,

    // Output: Read/Write Requests per Slave
    output logic [NUM_S:0][NUM_M-1:0]             R_REQ,
    output logic [NUM_S:0][NUM_M-1:0]             W_REQ
);

    // ============================================================
    // Slave Address Ranges (Local Parameters)
    // Default slave is the last one (NUM_S-1)
    // ============================================================

    // ROM
    localparam logic [`AXI_ADDR_BITS-1:0] S0_BEGIN = 32'h0000_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S0_END   = 32'h0000_1FFF;

    // IM
    localparam logic [`AXI_ADDR_BITS-1:0] S1_BEGIN = 32'h0001_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S1_END   = 32'h0001_FFFF;

    // DM
    localparam logic [`AXI_ADDR_BITS-1:0] S2_BEGIN = 32'h0002_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S2_END   = 32'h0002_FFFF;

    // DMA
    localparam logic [`AXI_ADDR_BITS-1:0] S3_BEGIN = 32'h1002_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S3_END   = 32'h1002_0200;

    // WDT
    localparam logic [`AXI_ADDR_BITS-1:0] S4_BEGIN = 32'h1001_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S4_END   = 32'h1001_03FF;

    // DRAM
    localparam logic [`AXI_ADDR_BITS-1:0] S5_BEGIN = 32'h2000_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S5_END   = 32'h201F_FFFF;


    // ============================================================
    // Read Request Decode
    // Map each Master read request to corresponding Slave
    // ============================================================
    always_comb begin
        for (int m = 0; m < NUM_M; m++) begin
            // Clear all R_REQ for this master first
            for (int s = 0; s < NUM_S+1; s++)
                R_REQ[s][m] = 1'b0;

            if (ARVALID[m]) begin
                if      (ARADDR[m] >= S0_BEGIN && ARADDR[m] <= S0_END) R_REQ[0][m] = 1'b1;
                else if (ARADDR[m] >= S1_BEGIN && ARADDR[m] <= S1_END) R_REQ[1][m] = 1'b1;
                else if (ARADDR[m] >= S2_BEGIN && ARADDR[m] <= S2_END) R_REQ[2][m] = 1'b1;
                else if (ARADDR[m] >= S3_BEGIN && ARADDR[m] <= S3_END) R_REQ[3][m] = 1'b1;
                else if (ARADDR[m] >= S4_BEGIN && ARADDR[m] <= S4_END) R_REQ[4][m] = 1'b1;
                else if (ARADDR[m] >= S5_BEGIN && ARADDR[m] <= S5_END) R_REQ[5][m] = 1'b1;
                else                                                   R_REQ[6][m] = 1'b1;
            end
        end
    end

    // ============================================================
    // Write Request Decode
    // Map each Master write request to corresponding Slave
    // ============================================================
    always_comb begin
        for (int m = 0; m < NUM_M; m++) begin
            // Clear all W_REQ for this master first
            for (int s = 0; s < NUM_S+1; s++)
                W_REQ[s][m] = 1'b0;

            if (AWVALID[m]) begin
                if      (AWADDR[m] >= S0_BEGIN && AWADDR[m] <= S0_END) W_REQ[0][m] = 1'b1;
                else if (AWADDR[m] >= S1_BEGIN && AWADDR[m] <= S1_END) W_REQ[1][m] = 1'b1;
                else if (AWADDR[m] >= S2_BEGIN && AWADDR[m] <= S2_END) W_REQ[2][m] = 1'b1;
                else if (AWADDR[m] >= S3_BEGIN && AWADDR[m] <= S3_END) W_REQ[3][m] = 1'b1;
                else if (AWADDR[m] >= S4_BEGIN && AWADDR[m] <= S4_END) W_REQ[4][m] = 1'b1;
                else if (AWADDR[m] >= S5_BEGIN && AWADDR[m] <= S5_END) W_REQ[5][m] = 1'b1;
                else                                                   W_REQ[6][m] = 1'b1;
            end
        end
    end

endmodule
