module Load_Filter (
    input  logic [31:0] memData,
    input  logic [ 2:0] func3,
    output logic [31:0] loadData
);
    // ============================================================
    // Load Data Filter
    // ============================================================
    always_comb begin
        case (func3)

            // ----------------------------------------------------
            // Signed Byte / Half / Word
            // ----------------------------------------------------
            `MEM_BYTE:   loadData = {{24{memData[7]}}, memData[7:0]};
            `MEM_HALF:   loadData = {{16{memData[15]}}, memData[15:0]};
            `MEM_WORD:   loadData = memData;

            // ----------------------------------------------------
            // Unsigned Byte / Half
            // ----------------------------------------------------
            `MEM_UBYTE:  loadData = {24'd0, memData[7:0]};
            `MEM_UHALF:  loadData = {16'd0, memData[15:0]};

            // ----------------------------------------------------
            // Default
            // ----------------------------------------------------
            default:     loadData = 32'd0;

        endcase
    end
endmodule
