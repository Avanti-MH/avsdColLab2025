module Program_Counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        IF_DONE,
    input  logic        MEM_DONE,

    input  logic        stall,
    input  logic        flush,
    input  logic        pTaken,

    input  logic [31:0] pTarget,
    input  logic [31:0] fTarget,
    output logic [31:0] pc
);

    // ============================================================
    // PC Register update
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
    if (rst)             pc <= 32'd0;
    else if (IF_DONE && MEM_DONE) begin
        if      (flush)  pc <= fTarget;
        else if (stall)  pc <= pc;
        else if (pTaken) pc <= {pTarget};
        else             pc <= pc + 32'd4;
    end
end


endmodule
