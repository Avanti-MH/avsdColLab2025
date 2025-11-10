module EXMEM (
    // input
    input  logic        clk,
    input  logic        rst,
    input  logic        IM_stall,
    input  logic        DM_stall,
    input  logic [4:0]  E_op,
    input  logic [3:0]  E_func,
    input  logic [4:0]  E_rd,
    input  logic [31:0] E_aluOut,
    input  logic [31:0] E_rs2_data,
    // output
    output logic [4:0]  M_op,
    output logic [2:0]  M_func3,
    output logic [4:0]  M_rd,
    output logic [31:0] M_aluOut,
    output logic [31:0] M_rs2_data
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
            M_aluOut    <= 32'd0;
            M_rs2_data  <= 32'd0;
            M_op        <= 5'd0;
            M_func3     <= 3'd0;
            M_rd        <= 5'd0;
        end else if (~(IM_stall || DM_stall))begin
            // -----------------------------
            // Normal operation: pass E-stage values to M-stage
            // -----------------------------
            M_aluOut    <= E_aluOut;
            M_rs2_data  <= E_rs2_data;
            M_op        <= E_op;
            M_func3     <= E_func[3:1];
            M_rd        <= E_rd;
        end
    end

endmodule
