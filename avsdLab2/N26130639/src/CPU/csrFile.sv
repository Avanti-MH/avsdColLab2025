module csrFile (
    input clk,
    input rst,
    input enable,
    input IM_stall,
    input DM_stall,
    input stall,
    input wrongBranch,
    input [1:0] csrOp,
    output logic [31:0] csrOut
);
    // ============================================================
    // CSR Registers
    // ============================================================
    logic [63:0] cycle;
    logic [63:0] instret;
    logic [63:0] instret_out;

    // ----------------------------------------------------
    // Instruction Retired Counter
    // ----------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            instret <= 64'd0;
        else begin
            // stall: EX instruction invalid, do not count.
            if (stall || IM_stall || DM_stall)
                instret <= instret;
            // wrongBranch: current instruction valid, next two cycles are bubbles; subtract 1.
            else if (wrongBranch)
                instret <= instret - 64'd1;
            else
                instret <= instret + 64'd1;
        end
    end

    // ----------------------------------------------------
    // Instruction Retired Output
    // ----------------------------------------------------
    /**
    * The first instruction reaches EX in the third cycle.
    * Subtract 2 to remove the preceding two pipeline bubbles.
    */
    assign instret_out = instret - 64'd2;

    // ----------------------------------------------------
    // Cycle Counter
    // ----------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            cycle <= 64'd0;
        else
            cycle <= cycle + 64'd1;
    end

    // ----------------------------------------------------
    // CSR Output Selection
    // ----------------------------------------------------
    always_comb begin
        if (enable) begin
            case (csrOp)
                `CSR_INSTRET_HIGH: csrOut = instret_out[63:32];
                `CSR_INSTRET_LOW:  csrOut = instret_out[31:0];
                `CSR_CYCLE_HIGH:   csrOut = cycle[63:32];
                `CSR_CYCLE_LOW:    csrOut = cycle[31:0];
            endcase
        end else
            csrOut = 32'd0;
    end

endmodule
