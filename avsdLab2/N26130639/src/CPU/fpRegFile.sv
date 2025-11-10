module fpRegFile (
    input clk,
    input rst,
    input [4:0] rs1_index,
    input [4:0] rs2_index,
    input [4:0] w_index,
    input [31:0] w_data,
    input w_en,
    output logic [31:0] data1,
    output logic [31:0] data2
);

    integer i;
    logic [31:0] fpRegs [0:31];

    // ============================================================
    // Write logic with reset
    // ============================================================
    always_ff @( posedge clk or posedge rst ) begin
        if (rst)
            for (i = 0; i < 32; i++)
                fpRegs[i] <= 32'd0;
        else begin
            if (w_en && w_index != 5'd0)
                fpRegs[w_index] <= w_data;
        end
    end

    // ============================================================
    // Read logic (combinational)
    // ============================================================
    always_comb begin
        data1 = fpRegs[rs1_index];
        data2 = fpRegs[rs2_index];
    end

endmodule
