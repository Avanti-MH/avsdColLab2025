module MEMWB (
    // input
    input  logic        clk,
    input  logic        rst,
    input  logic        IM_stall,
    input  logic        DM_stall,
    input  logic [4:0]  M_op,
    input  logic [4:0]  M_rd,
    input  logic [2:0]  M_func3,
    input  logic [31:0] M_aluOut,
    input  logic [31:0] M_ReadData,
    // output
    output logic [4:0]  W_op,
    output logic [4:0]  W_rd,
    output logic [2:0]  W_func3,
    output logic [31:0] W_aluOut,
    output logic [31:0] W_ReadData
);

    logic [31:0]        buffer;
    logic               valid;
    // ============================================================
    // Pipeline register: transfer signals from M-stage to W-stage
    // Handles reset condition by inserting a bubble
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // -----------------------------
            // Reset: insert bubble
            // -----------------------------
            W_aluOut    <= 32'd0;
            W_op        <= 5'd0;
            W_func3     <= 3'd0;
            W_rd        <= 5'd0;
            W_ReadData  <= 32'd0;
            buffer      <= 32'd0;
            valid       <= 1'b0;
        end else if (IM_stall && ~DM_stall && valid == 1'b0) begin
            buffer      <= M_ReadData;
            valid       <= 1'b1;
        end else if (~(IM_stall || DM_stall))begin
            // -----------------------------
            // Normal operation: pass M-stage values to W-stage
            // -----------------------------
            W_aluOut    <= M_aluOut;
            W_op        <= M_op;
            W_func3     <= M_func3;
            W_rd        <= M_rd;
            W_ReadData  <= (valid) ? buffer : M_ReadData;
            buffer      <= 32'd0;
            valid       <= 1'b0;
        end
    end

endmodule
