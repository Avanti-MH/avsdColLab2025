module IFID (
    input  logic        clk,
    input  logic        rst,
    input  logic        IF_DONE,
    input  logic        MEM_DONE,
    input  logic        stall,
    input  logic        flush,
    input  logic [31:0] IF_pc,
    input  logic [31:0] IF_inst,
    input  logic        IF_pTaken,
    output logic [31:0] ID_pc,
    output logic [31:0] ID_inst,
    output logic        ID_pTaken
);

    // ============================================================
    // Locals Registers
    // ============================================================
    logic [31:0]        buffer;
    logic               valid;

    // ============================================================
    // Reset and Update
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ID_pc     <= 32'd0;
            ID_pTaken <= 1'b0;
            ID_inst   <= 32'd0;
        end else if (IF_DONE && MEM_DONE) begin
            if (flush) begin
                ID_pc     <= 32'd0;
                ID_pTaken <= 1'b0;
                ID_inst   <= `BUBBLE_INST;
            end else if (~stall) begin
                ID_pc     <= IF_pc;
                ID_pTaken <= IF_pTaken;
                ID_inst   <= (valid) ? buffer : IF_inst;
            end
        end
    end

    // ============================================================
    // Buffer for IF_RdData
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid  <= 1'b0;
            buffer <= 32'd0;
        end else if (IF_DONE && ~MEM_DONE && valid == 1'b0) begin
            buffer <= IF_inst;
            valid  <= 1'b1;
        end else if (IF_DONE && MEM_DONE) begin
            valid  <= 1'b0;
            buffer <= 32'd0;
        end
    end

endmodule
