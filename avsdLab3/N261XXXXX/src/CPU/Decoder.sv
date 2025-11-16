module Decoder (
    input  logic [31:0] inst,
    output logic [4:0]  rs1_index,
    output logic [4:0]  rs2_index,
    output logic [4:0]  rd_index,
    output logic [4:0]  opcode,
    output logic [3:0]  func,
    output logic        is_mtype,
    output logic        is_fsub,
    output logic [11:0] csrIdx,
    output logic        WFI,
    output logic        MRET
);

    // ============================================================
    // Decode fields from instruction
    // ============================================================
    always_comb begin
        rs1_index  = inst[19:15];
        rs2_index  = inst[24:20];
        rd_index   = inst[11:7];
        opcode     = inst[6:2];
        func       = {inst[14:12], inst[30]};
        is_mtype   = inst[25];
        is_fsub    = inst[27];
        csrIdx     = inst[31:20];
        WFI        = (inst == 32'h1050_0073);
        MRET       = (inst == 32'h3020_0073);
    end

endmodule
