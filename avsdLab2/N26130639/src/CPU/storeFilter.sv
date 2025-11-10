module storeFilter (
    input  logic [1:0]  byteOffset,
    input  logic [4:0]  opcode,
    input  logic [2:0]  func3,
    input  logic [31:0] storeData,
    output logic [31:0] memData,
    output logic [3:0]  memWriteMask
);

    // ============================================================
    // Store Data Filter
    // ============================================================
    always_comb begin
        // ----------------------------------------------------
        // Default: zero outputs to avoid latch
        // ----------------------------------------------------
        memData      = `AXI_DATA_BITS'b0;
        memWriteMask = `AXI_STRB_BITS'b0000;

        // ----------------------------------------------------
        // S-type Store
        // ----------------------------------------------------
        if (opcode == `OP_S_TYPE) begin
            // Word
            if (func3 == `MEM_WORD) begin
                memWriteMask = `AXI_STRB_WORD;
                memData      = storeData;
            end

            // Half-word
            else if (func3 == `MEM_HALF) begin
                case (byteOffset)
                    2'b00: begin memWriteMask = `AXI_STRB_HWORD;      memData = {16'd0, storeData[15:0]}; end
                    2'b01: begin memWriteMask = `AXI_STRB_HWORD << 1; memData = {8'd0, storeData[15:0], 8'd0}; end
                    2'b10: begin memWriteMask = `AXI_STRB_HWORD << 2; memData = {storeData[15:0], 16'd0}; end
                    default: begin
                        memWriteMask = `AXI_STRB_BITS'b0000;
                        memData      = `AXI_DATA_BITS'b0;
                    end
                endcase
            end

            // Byte
            else if (func3 == `MEM_BYTE) begin
                case (byteOffset)
                    2'b00: begin memWriteMask = `AXI_STRB_BYTE;      memData = {24'd0, storeData[7:0]}; end
                    2'b01: begin memWriteMask = `AXI_STRB_BYTE << 1; memData = {16'd0, storeData[7:0], 8'd0}; end
                    2'b10: begin memWriteMask = `AXI_STRB_BYTE << 2; memData = {8'd0, storeData[7:0], 16'd0}; end
                    2'b11: begin memWriteMask = `AXI_STRB_BYTE << 3; memData = {storeData[7:0], 24'd0}; end
                endcase
            end
        end

        // ----------------------------------------------------
        // FSW (Floating store)
        // ----------------------------------------------------
        else if (opcode == `OP_FSW) begin
            memWriteMask = `AXI_STRB_WORD;
            memData      = storeData;
        end
    end

endmodule
