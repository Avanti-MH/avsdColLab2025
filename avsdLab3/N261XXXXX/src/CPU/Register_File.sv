module Register_File (
    input  logic        clk,
    input  logic        rst,

    // Write Enables
    input  logic        int_wen,
    input  logic        fp_wen,

    // Read Enables
    input  logic        fpA_ren,
    input  logic        fpB_ren,

    // Register Indices
    input  logic [4:0]  rs1_idx,
    input  logic [4:0]  rs2_idx,
    input  logic [4:0]  rd_idx,

    // Write Data
    input  logic [31:0] wr_data,

    // Read Data
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

    // ============================================================
    // Register Arrays
    // ============================================================
    logic [31:0] int_regs [0:31];
    logic [31:0] fp_regs  [0:31];
    integer i;

    // ============================================================
    // Write Logic with Reset
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i++) begin
                int_regs[i] <= 32'd0;
                fp_regs[i]  <= 32'd0;
            end
        end else begin
            if (int_wen && rd_idx != 5'd0)
                int_regs[rd_idx] <= wr_data;
            if (fp_wen && rd_idx != 5'd0)
                fp_regs[rd_idx]  <= wr_data;
        end
    end

    // ============================================================
    // Read Logic (Combinational)
    // ============================================================
    always_comb begin
        rs1_data = fpA_ren ? fp_regs[rs1_idx] : int_regs[rs1_idx];
        rs2_data = fpB_ren ? fp_regs[rs2_idx] : int_regs[rs2_idx];
    end

endmodule
