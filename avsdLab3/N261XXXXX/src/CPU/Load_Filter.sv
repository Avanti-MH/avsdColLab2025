module Load_Filter (
    input  logic [ 1:0] byteOffset,
    input  logic [31:0] memData,
    input  logic [ 2:0] func3,
    output logic [31:0] loadData
);

    logic [31:0] dataShiftByte;
    logic [31:0] dataShiftHalf;

    // ============================================================
    // Load Data Filter
    // ============================================================
    always_comb begin
        dataShiftByte = memData >> (byteOffset * 8);
        dataShiftHalf = memData >> (byteOffset[1] * 16);

        case (func3)

            // ----------------------------------------------------
            // Signed Byte / Half / Word
            // ----------------------------------------------------
            `MEM_BYTE:   loadData = {{24{dataShiftByte[7]}},  dataShiftByte[7:0]};
            `MEM_HALF:   loadData = {{16{dataShiftHalf[15]}}, dataShiftHalf[15:0]};
            `MEM_WORD:   loadData = memData;

            // ----------------------------------------------------
            // Unsigned Byte / Half
            // ----------------------------------------------------
            `MEM_UBYTE:  loadData = {24'd0, dataShiftByte[7:0]};
            `MEM_UHALF:  loadData = {16'd0, dataShiftHalf[15:0]};

            // ----------------------------------------------------
            // Default
            // ----------------------------------------------------
            default:     loadData = 32'd0;

        endcase
    end
endmodule
