module Decoder #(
    parameter int NUM_M    = 3,
    parameter int NUM_S    = 6
) (
    // Master Inputs
    input  logic [NUM_M-1:0]                      ARVALID_M,
    input  logic [NUM_M-1:0]                      AWVALID_M,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0]  ARADDR_M,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0]  AWADDR_M,

    // Output: Read/Write Requests per Slave
    output logic [NUM_S:0][NUM_M-1:0]             R_REQ,
    output logic [NUM_S:0][NUM_M-1:0]             W_REQ
);

    // ============================================================
    // Slave Address Ranges (Local Parameters)
    // Default slave is the last one (NUM_S-1)
    // ============================================================
            // S0_BEGIN	= 32'h0000_0000,
			// S0_END 		= 32'h0000_FFFF,
			// S1_BEGIN 	= 32'h0001_0000,
			// S1_END 		= 32'h0001_FFFF;

    // IM
    localparam logic [`AXI_ADDR_BITS-1:0] S1_BEGIN = 32'h0000_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S1_END   = 32'h0000_FFFF;

    // DM
    localparam logic [`AXI_ADDR_BITS-1:0] S2_BEGIN = 32'h0001_0000;
    localparam logic [`AXI_ADDR_BITS-1:0] S2_END   = 32'h0001_FFFF;




    // ============================================================
    // Read Request Decode
    // Map each Master read request to corresponding Slave
    // ============================================================
    always_comb begin
        for (int m = 0; m < NUM_M; m++) begin
            // Clear all R_REQ for this master first
            for (int s = 0; s < NUM_S+1; s++)
                R_REQ[s][m] = 1'b0;

            if (ARVALID_M[m]) begin
                if (ARADDR_M[m] >= S1_BEGIN && ARADDR_M[m] <= S1_END) R_REQ[0][m] = 1'b1;
                else if (ARADDR_M[m] >= S2_BEGIN && ARADDR_M[m] <= S2_END) R_REQ[1][m] = 1'b1;
                else                                                   R_REQ[2][m] = 1'b1;
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

            if (AWVALID_M[m]) begin
                if (AWADDR_M[m] >= S1_BEGIN && AWADDR_M[m] <= S1_END) W_REQ[0][m] = 1'b1;
                else if (AWADDR_M[m] >= S2_BEGIN && AWADDR_M[m] <= S2_END) W_REQ[1][m] = 1'b1;
                else                                                   W_REQ[2][m] = 1'b1;
            end
        end
    end

endmodule
