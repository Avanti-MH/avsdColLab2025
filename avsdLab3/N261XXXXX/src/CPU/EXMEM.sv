module EXMEM (
    // input
    input  logic        clk,
    input  logic        rst,
    input  logic        IF_DONE,
    input  logic        MEM_DONE,
    input  logic [4:0]  EX_op,
    input  logic [3:0]  EX_func,
    input  logic [4:0]  EX_rd,
    input  logic [31:0] EX_aluOut,
    input  logic [31:0] EX_rs2_data,
    // output
    output logic [4:0]  MEM_op,
    output logic [2:0]  MEM_func3,
    output logic [4:0]  MEM_rd,
    output logic [31:0] MEM_aluOut,
    output logic [31:0] MEM_rs2_data
);


    // ============================================================
    // Pipeline register: transfer signals from E-stage to M-stage
    // Handles reset condition by inserting a bubble
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // -----------------------------
            // Reset: insert bubble
            // -----------------------------
            MEM_aluOut    <= 32'd0;
            MEM_rs2_data  <= 32'd0;
            MEM_op        <= 5'd0;
            MEM_func3     <= 3'd0;
            MEM_rd        <= 5'd0;
        end else if (IF_DONE && MEM_DONE)begin
            // -----------------------------
            // Normal operation: pass E-stage values to M-stage
            // -----------------------------
            MEM_aluOut    <= EX_aluOut;
            MEM_rs2_data  <= EX_rs2_data;
            MEM_op        <= EX_op;
            MEM_func3     <= EX_func[3:1];
            MEM_rd        <= EX_rd;
        end
    end

endmodule
