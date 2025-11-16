module MEMWB (
    // input
    input  logic        clk,
    input  logic        rst,
    input  logic        IF_DONE,
    input  logic        MEM_DONE,
    input  logic [4:0]  MEM_op,
    input  logic [4:0]  MEM_rd,
    input  logic [2:0]  MEM_func3,
    input  logic [31:0] MEM_aluOut,
    input  logic [31:0] MEM_ReadData,
    // output
    output logic [4:0]  WB_op,
    output logic [4:0]  WB_rd,
    output logic [2:0]  WB_func3,
    output logic [31:0] WB_aluOut,
    output logic [31:0] WB_ReadData
);

    // ============================================================
    // Locals Registers
    // ============================================================
    logic [31:0]        buffer;
    logic               valid;

    // ============================================================
    // Pipeline register
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // -----------------------------
            // Reset
            // -----------------------------
            WB_aluOut    <= 32'd0;
            WB_op        <= 5'd0;
            WB_func3     <= 3'd0;
            WB_rd        <= 5'd0;
            WB_ReadData  <= 32'd0;
        end else if (IF_DONE && MEM_DONE) begin
            // -----------------------------
            // Updata
            // -----------------------------
            WB_aluOut    <= MEM_aluOut;
            WB_op        <= MEM_op;
            WB_func3     <= MEM_func3;
            WB_rd        <= MEM_rd;
            WB_ReadData  <= (valid) ? buffer : MEM_ReadData;
        end
    end

    // ============================================================
    // Buffer for MEMEM_RdData
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid  <= 1'b0;
            buffer <= 32'd0;
        end else if (~IF_DONE && MEM_DONE && valid == 1'b0) begin
            buffer <= MEM_ReadData;
            valid  <= 1'b1;
        end else if (IF_DONE && MEM_DONE) begin
            valid  <= 1'b0;
            buffer <= 32'd0;
        end
    end

endmodule
