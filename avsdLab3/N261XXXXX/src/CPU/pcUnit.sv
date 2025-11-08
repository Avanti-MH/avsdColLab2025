module pcUnit (
    input  logic        clk,
    input  logic        rst,
    input  logic        stall,
    input  logic        IM_stall,
    input  logic        DM_stall,
    input  logic        mispredict,
    input  logic        predictTaken,
    input  logic [15:0] predictedTarget,
    input  logic [31:0] correctTarget,
    output logic [31:0] pc
);

    logic [31:0] nextPc;
    logic [31:0] pcPlus4;

    assign pcPlus4 = pc + 32'd4;

    // ============================================================
    // Next PC computation
    // ============================================================
    always_comb begin
        case ({mispredict, predictTaken})
            2'b10, 2'b11: nextPc = correctTarget;     // misprediction → jump to correct target
            2'b01:        nextPc = {16'd0, predictedTarget};   // predicted taken → BTB target
            default:      nextPc = pcPlus4;           // otherwise sequential PC
        endcase
    end

    // ============================================================
    // PC register update
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else if (~(stall || IM_stall || DM_stall))
            pc <= nextPc;
    end

endmodule
