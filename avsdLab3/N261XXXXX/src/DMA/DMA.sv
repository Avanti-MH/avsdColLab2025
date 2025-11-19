module DMA (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      En_VALID,
    input  logic                      En,

    input  logic                      WEn,
    input  logic [2:0]                A,
    input  logic [`AXI_DATA_BITS-1:0] DI,
    input  logic                      BURST_DONE,
    input  logic                      FIRST_BURST,

    output logic [`AXI_ADDR_BITS-1:0] DESC_ADDR,
    output logic [`AXI_ADDR_BITS-1:0] BURST_SRC,
    output logic [`AXI_ADDR_BITS-1:0] BURST_DST,
    output logic [`AXI_LEN_BITS-1:0]  BURST_LEN,
    output logic                      BLOCK_DONE,
    output logic                      EOC,
    output logic                      DMA_interrupt
);
    // ============================================================
    // Local Registers and Signals
    // ============================================================
    logic [`AXI_DATA_BITS-1:0] DMALEN;
    logic [`AXI_ADDR_BITS-1:0] NEXT_DESC;

    // ============================================================
    // Register Write and Block Initialization
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            DESC_ADDR <= `AXI_ADDR_BITS'd0;
            BURST_SRC <= `AXI_ADDR_BITS'd0;
            BURST_DST <= `AXI_ADDR_BITS'd0;
            DMALEN    <= `AXI_ADDR_BITS'd0;
            NEXT_DESC <= `AXI_ADDR_BITS'd0;
            EOC       <= 1'b0;
            BURST_LEN <= `AXI_LEN_BITS'd0;
            DMA_interrupt <= 1'b0;
        end else begin
            // ---------------------------------------
            // Descriptor Fields Update
            // ---------------------------------------
            if (WEn) begin
                case (A)
                    3'd0: BURST_SRC <= DI;
                    3'd1: BURST_DST <= DI;
                    3'd2: DMALEN    <= DI;
                    3'd3: NEXT_DESC <= DI;
                    3'd4: EOC       <= DI[0];
                    3'd5: DESC_ADDR <= DI;
                    default: ;
                endcase
            end
            // ---------------------------------------
            // Transfer Request Update
            // ---------------------------------------
            if (FIRST_BURST) begin
                if (DMALEN < 32'd16) begin
                    BURST_SRC <= BURST_SRC;
                    BURST_DST <= BURST_DST;
                    BURST_LEN <= DMALEN[3:0] - `AXI_LEN_BITS'd1;
                    DMALEN    <= 32'd0;
                // ---------------------------------------
                // 3. Normal Burst : Burst Length = 16
                // ---------------------------------------
                end else begin
                    BURST_SRC <= BURST_SRC;
                    BURST_DST <= BURST_DST;
                    if (BURST_SRC[5:0] != 6'd0) begin
                        //BURST_LEN <= {{`AXI_LEN_BITS{1'b0}}, (32'd64 - {26'd0, BURST_SRC[5:0]}) >> 2}[`AXI_LEN_BITS-1:0];
                        BURST_LEN <= (4'd15 - BURST_SRC[5:2] + 4'd1);
                        DMALEN    <= DMALEN - ((32'd64 - {26'd0, BURST_SRC[5:0]}) >> 2);
                    end else begin
                        BURST_LEN <= `AXI_LEN_BITS'd15;
                        DMALEN    <= DMALEN - `AXI_DATA_BITS'd16;
                    end
                end
            end
            if (BURST_DONE) begin
                // ---------------------------------------
                // 1. Block Done : New Descriptor Request
                // ---------------------------------------
                if (DMALEN == 32'd0) begin
                    DESC_ADDR     <= NEXT_DESC;
                    DMA_interrupt <= EOC;

                // ---------------------------------------
                // 2. The Last Burst : Burst Length might less than 16
                // ---------------------------------------
                end else if (DMALEN < 32'd16) begin
                    BURST_SRC <= {BURST_SRC[31:6], 6'd0} + 32'd64;
                    BURST_DST <= {BURST_DST[31:6], 6'd0} + 32'd64;
                    BURST_LEN <= DMALEN[3:0] - `AXI_LEN_BITS'd1;
                    DMALEN    <= 32'd0;
                // ---------------------------------------
                // 3. Normal Burst : Burst Length = 16
                // ---------------------------------------
                end else begin
                    BURST_SRC <= {BURST_SRC[31:6], 6'd0} + 32'd64;
                    BURST_DST <= {BURST_DST[31:6], 6'd0} + 32'd64;
                    BURST_LEN <= `AXI_LEN_BITS'd15;
                    DMALEN    <= DMALEN - `AXI_DATA_BITS'd16;
                end
            end

            // ---------------------------------------
            // DMA Disable
            // ---------------------------------------
            if(En_VALID && ~En)
                DMA_interrupt <= 1'b0;
        end
    end

    // ============================================================
    // Block Done Output (COmbinational)
    // ============================================================
    assign BLOCK_DONE =  (BURST_DONE && (DMALEN == 32'd0));

endmodule
