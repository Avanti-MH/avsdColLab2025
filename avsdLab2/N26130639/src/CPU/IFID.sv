module IFID (
    input  logic        clk,
    input  logic        rst,
    input  logic        stall,
    input  logic        IM_stall,
    input  logic        DM_stall,
    input  logic        flush,
    input  logic [31:0] F_pc,
    input  logic [31:0] F_inst,
    input  logic        F_PredictTaken,
    output logic [31:0] D_pc,
    output logic [31:0] D_inst,
    output logic        D_PredictTaken
);

    logic [31:0]        buffer;
    logic               valid;
    // ============================================================
    // Update D_pc and D_PredictTaken
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            D_pc <= 32'd0;
            D_PredictTaken <= 1'b0;
            D_inst <= 32'd0;
            buffer <= 32'd0;
            valid  <= 1'b0;
        end else if (~IM_stall && DM_stall && valid == 1'b0) begin
            buffer <= F_inst;
            valid  <= 1'b1;
        end else if (IM_stall || DM_stall) begin
            D_pc <= D_pc;
            D_PredictTaken <= D_PredictTaken;
            D_inst <= D_inst;
        end else if (flush) begin
            D_pc <= 32'd0;
            D_PredictTaken <= 1'b0;
            D_inst <= `BUBBLE_INST;
            buffer <= 32'd0;
            valid <= 1'b0;
        end else if (~stall) begin
            D_pc <= F_pc;
            D_PredictTaken <= F_PredictTaken;
            D_inst <= (valid) ? buffer :F_inst;
            buffer <= 32'd0;
            valid <= 1'b0;
        end
    end

endmodule
