
/*------------------------------------------------------------------------------
 * File        : DMA.sv
 * Brief       : Simple descriptor-based DMA register block
 * Description : Latches DMA descriptor fields written via DESC_* interface
 *               and exposes mirrors to the rest of the system.
 * Interfaces  :
 *   - DESC_* : descriptor data/sel/write_en (write one field at a time)
 *   - Done   : external DMA engine done pulse -> raises DMA_interrupt
 * Parameters  : Uses `AXI_ADDR_BITS and `AXI_DATA_BITS from AXI_define.svh
 * Reset       : async, active-high
 *----------------------------------------------------------------------------*/

module DMA (
    // =========================
    // Clocks & Reset
    // =========================
    input  logic                      clk,
    input  logic                      rst,

    // =========================
    // Control / Descriptor I/F
    // =========================
    input  logic                      DMAEN,
    input  logic [`AXI_ADDR_BITS-1:0] DESC_BASE,      // NOTE: currently unused
    input  logic [`AXI_DATA_BITS-1:0] DESC_input,
    input  logic                      DESC_write_en,
    input  logic [3:0]                DESC_sel,       // 0:DMASRC,1:DMADST,2:DMALEN,3:NEXT_DESC,4:EOC

    // =========================
    // Status from DMA engine
    // =========================
    input  logic                      Done,

    // =========================
    // Outputs (mirrors)
    // =========================
    output logic                      DMAEN_output,
    output logic [`AXI_ADDR_BITS-1:0] DMASRC,
    output logic [`AXI_ADDR_BITS-1:0] DMADST,
    output logic [`AXI_DATA_BITS-1:0] DMALEN,
    output logic [`AXI_ADDR_BITS-1:0] NEXT_DESC,
    output logic                      EOC,

    // Convenience mirrors (same width as DMASRC/DMADST)
    output logic [`AXI_ADDR_BITS-1:0] SRC_ADDR,
    output logic [`AXI_ADDR_BITS-1:0] DST_ADDR,

    // Interrupt
    output logic                      DMA_interrupt
);

    // ============================================================
    // Sequential logic
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            DMAEN_output <= 1'b0;
            DMASRC       <= '0;
            DMADST       <= '0;
            DMALEN       <= '0;
            NEXT_DESC    <= '0;
            EOC          <= 1'b0;
        end else begin
            // Pass-through enable
            DMAEN_output <= DMAEN;

            // Latch descriptor writes
            if (DESC_write_en) begin
                unique case (DESC_sel)
                    4'd0: DMASRC    <= DESC_input[`AXI_ADDR_BITS-1:0]; // explicit slice to addr width
                    4'd1: DMADST    <= DESC_input[`AXI_ADDR_BITS-1:0];
                    4'd2: DMALEN    <= DESC_input;
                    4'd3: NEXT_DESC <= DESC_input[`AXI_ADDR_BITS-1:0];
                    4'd4: EOC       <= DESC_input[0];
                    default: /* no write */;
                endcase
            end
        end
    end

    // ============================================================
    // Combinational mirrors / simple wires
    // ============================================================
    assign SRC_ADDR      = DMASRC;
    assign DST_ADDR      = DMADST;
    assign DMA_interrupt = Done;

    // ============================================================
    // (Optional) Assertions – enable if you have SVA in flow
    // ============================================================
    // property p_desc_write_sel_valid;
    //   @(posedge clk) disable iff (rst)
    //     DESC_write_en |-> (DESC_sel <= 4'd4);
    // endproperty
    // assert property (p_desc_write_sel_valid);

endmodule
