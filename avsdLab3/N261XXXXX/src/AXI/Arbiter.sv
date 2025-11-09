module Arbiter #(
    parameter int NUM_M     = 3,
    parameter int NUM_S     = 6,
    parameter int MIDX_BITS = 2,
    parameter int SIDX_BITS = 3
) (
    input  logic                      clk,
    input  logic                      rst,

    input  logic [NUM_S:0][NUM_M-1:0] R_REQ,
    input  logic [NUM_S:0][NUM_M-1:0] W_REQ,

    input  logic [NUM_S:0]            ARREADY_S,
    input  logic [NUM_S:0]            AWREADY_S,

    input  logic [NUM_M-1:0]          RREADY_M,
    input  logic [NUM_M-1:0]          BREADY_M,
    input  logic [NUM_S:0]            RVALID_S,
    input  logic [NUM_S:0]            RLAST_S,
    input  logic [NUM_S:0]            BVALID_S,

    output logic [MIDX_BITS-1:0]      SRIdx [NUM_S:0],
    output logic [MIDX_BITS-1:0]      SWIdx [NUM_S:0],

    output logic [SIDX_BITS-1:0]      MRIdx [NUM_M-1:0],
    output logic [SIDX_BITS-1:0]      MWIdx [NUM_M-1:0]
);

    // ============================================================
    // Enum Definition
    // ============================================================
    localparam int READ_BASE  = 1;
    localparam int WRITE_BASE = READ_BASE + NUM_M;

    typedef logic [$clog2(READ_BASE + NUM_M + NUM_M)-1:0] connect_state_t;

    localparam connect_state_t NONE = 0;

    // ============================================================
    // Connect Signal
    // ============================================================
    connect_state_t connect_comb [NUM_S:0];
    connect_state_t connect_reg  [NUM_S:0];
    connect_state_t connect_case [NUM_S:0];
    logic           SlaveIdle    [NUM_S:0];

    // ============================================================
    // Combinational arbitration
    // ============================================================
    always_comb begin
        for (int s = 0; s < NUM_S+1; s++) begin
            connect_comb[s] = NONE;
            connect_case[s] = NONE;

            for (int m = 0; m < NUM_M; m++) begin
                if (ARREADY_S[s] && R_REQ[s][m])
                    connect_comb[s] = connect_state_t'(READ_BASE + m);
                else if (AWREADY_S[s] && W_REQ[s][m])
                    connect_comb[s] = connect_state_t'(WRITE_BASE + m);
            end

            connect_case[s] = (connect_reg[s] == NONE) ? connect_comb[s] : connect_reg[s];
        end
    end

    // ============================================================
    // Slave Done / Idle
    // ============================================================
    always_comb begin
        for (int s = 0; s < NUM_S+1; s++) begin
            SlaveIdle[s] = 1'b0;

            for (int m = 0; m < NUM_M; m++) begin
                if (connect_reg[s] == connect_state_t'(READ_BASE + m))
                    SlaveIdle[s] = RVALID_S[s] && RREADY_M[m] && RLAST_S[s];
                else if (connect_reg[s] == connect_state_t'(WRITE_BASE + m))
                    SlaveIdle[s] = BVALID_S[s] && BREADY_M[m];
            end
            if (connect_reg[s] == NONE) SlaveIdle[s] = 1'b1;
        end
    end

    // ============================================================
    // Connect Register Update
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int s = 0; s < NUM_S+1; s++)
                connect_reg[s] <= NONE;
        end else begin
            for (int s = 0; s < NUM_S+1; s++)
                if (SlaveIdle[s]) connect_reg[s] <= connect_comb[s];
        end
    end

    // ============================================================
    // Index mapping
    // ============================================================
    always_comb begin
        for (int s = 0; s < NUM_S+1; s++) begin
            SRIdx[s] = SIDX_BITS'(0);
            SWIdx[s] = SIDX_BITS'(0);
        end
        for (int m = 0; m < NUM_M; m++) begin
            MRIdx[m] = MIDX_BITS'(0);
            MWIdx[m] = MIDX_BITS'(0);
        end

        for (int s = 0; s < NUM_S+1; s++) begin
            for (int m = 0; m < NUM_M; m++) begin
                if (connect_case[s] == connect_state_t'(READ_BASE + m)) begin
                    SRIdx[s]  = SIDX_BITS'(m+1);
                    MRIdx[m]  = MIDX_BITS'(s+1);
                end
                else if (connect_case[s] == connect_state_t'(WRITE_BASE + m)) begin
                    SWIdx[s]  = SIDX_BITS'(m+1);
                    MWIdx[m]  = MIDX_BITS'(s+1);
                end
            end
        end
    end

endmodule
