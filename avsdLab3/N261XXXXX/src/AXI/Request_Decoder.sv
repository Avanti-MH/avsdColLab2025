module Request_Decoder #(
    parameter int NUM_M = 3,
    parameter int NUM_S = 6
) (
    input  logic [NUM_M-1:0]                      ARVALID_M,
    input  logic [NUM_M-1:0]                      AWVALID_M,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0]  ARADDR_M,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0]  AWADDR_M,

    output logic [NUM_S:0][NUM_M-1:0]             R_REQ,
    output logic [NUM_S:0][NUM_M-1:0]             W_REQ
);

    // ============================================================
    // Slave Address Range Arrays
    // ============================================================
    localparam logic [`AXI_ADDR_BITS-1:0] S_BEGIN [0:NUM_S-1] = '{
        32'h0000_0000, // ROM
        32'h0001_0000, // IM
        32'h0002_0000, // DM
        32'h1002_0000, // DMA
        32'h1001_0000, // WDT
        32'h2000_0000  // DRAM
    };

    localparam logic [`AXI_ADDR_BITS-1:0] S_END [0:NUM_S-1] = '{
        32'h0000_1FFF, // ROM
        32'h0001_FFFF, // IM
        32'h0002_FFFF, // DM
        32'h1002_0200, // DMA
        32'h1001_03FF, // WDT
        32'h201F_FFFF  // DRAM
    };

    // ============================================================
    // Read Request Decode
    // ============================================================
    logic matched_r;
    always_comb begin
        for (int m = 0; m < NUM_M; m++) begin
            for (int s = 0; s < NUM_S + 1; s++)
                R_REQ[s][m] = 1'b0;

            if (ARVALID_M[m]) begin
                matched_r = 1'b0;
                for (int s = 0; s < NUM_S; s++) begin
                    if (ARADDR_M[m] >= S_BEGIN[s] && ARADDR_M[m] <= S_END[s]) begin
                        R_REQ[s][m] = 1'b1;
                        matched_r = 1'b1;
                    end
                end
                if (!matched_r)
                    R_REQ[NUM_S][m] = 1'b1; // Default slave
            end
        end
    end

    // ============================================================
    // Write Request Decode
    // ============================================================
    logic matched_w;
    always_comb begin
        for (int m = 0; m < NUM_M; m++) begin
            for (int s = 0; s < NUM_S + 1; s++)
                W_REQ[s][m] = 1'b0;

            if (AWVALID_M[m]) begin
                matched_w = 1'b0;
                for (int s = 0; s < NUM_S; s++) begin
                    if (AWADDR_M[m] >= S_BEGIN[s] && AWADDR_M[m] <= S_END[s]) begin
                        W_REQ[s][m] = 1'b1;
                        matched_w = 1'b1;
                    end
                end
                if (!matched_w)
                    W_REQ[NUM_S][m] = 1'b1; // Default slave
            end
        end
    end

endmodule