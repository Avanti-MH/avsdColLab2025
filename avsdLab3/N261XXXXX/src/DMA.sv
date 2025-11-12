
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
    input  logic                        clk,
    input  logic                        rst,

    // =========================
    // Control / Descriptor I/F
    // =========================
    input logic                         DMAEN,
    input logic [`AXI_DATA_BITS-1:0]    DESC_input,
    input logic [3:0]                   sel,            // 0:DMASRC,1:DMADST,2:DMALEN,3:NEXT_DESC,4:EOC,7:BASEADDR
    input logic                         EOB,            // End of Burst
    input logic                         isTransferring, // is Transfer state

    output logic                        isDMA_en,
    // Convenience mirrors (same width as DMASRC/DMADST)
    output logic [`AXI_ADDR_BITS-1:0]   SrcAddr_perBurst,
    output logic [`AXI_ADDR_BITS-1:0]   DstAddr_perBurst,
    output logic [`AXI_LEN_BITS-1:0]    TransSize,
    output logic                        EOT,
    // Interrupt
    output logic                        DMA_interrupt
);
    //
    parameter DMA_BATCH_BITS = `AXI_DATA_BITS - `AXI_LEN_BITS;
    // ============================================================
    // Reg
    // ============================================================
    logic [`AXI_ADDR_BITS-1:0] DMASRC, DMADST, NEXT_DESC;
    logic [`AXI_DATA_BITS-1:0] DMALEN;
    logic EOC, EOBatch;
    // 
    logic [DMA_BATCH_BITS-1:0] n_batch;
    logic [`AXI_DATA_BITS-1:0] FinishCount;
    logic [`AXI_ADDR_BITS-1:0] DeltaAddr;

    // update isDMA_en if DMAEN 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            isDMA_en <= 1'd0;
        end else begin
            isDMA_en <= DMAEN ^ isDMA_en ? DMAEN : isDMA_en;
        end
    end
    
    // ============================================================
    // Sequential logic
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
                                    DMASRC    <=  '0;
                                    DMADST    <=  '0;
                                    DMALEN    <=  '0;
                                    NEXT_DESC <=  '0;
                                    EOC       <= 1'b0;;
        end else begin
            if (isDMA_en && !isTransferring) begin
                case (sel)
                    4'd1:           DMASRC    <= DESC_input[`AXI_ADDR_BITS-1:0];
                    4'd2:           DMADST    <= DESC_input[`AXI_ADDR_BITS-1:0];
                    4'd3:           DMALEN    <= DESC_input;
                    4'd4:           NEXT_DESC <= DESC_input[`AXI_ADDR_BITS-1:0];
                    4'd5:           EOC       <= DESC_input[0];
                endcase
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
                                    n_batch <= {(DMA_BATCH_BITS){1'd0}};
        end else begin
            if (isTransferring) begin
                                    n_batch <= EOB ? n_batch + DMA_BATCH_BITS'd1 : n_batch;
            end else begin
                                    n_batch <= {(DMA_BATCH_BITS){1'd0}};
            end
        end
    end

    assign FinishCount      = {(`AXI_DATA_BITS - `AXI_LEN_BITS){1'd0}, `AXI_LEN_BITS{1'd1}} * {(`AXI_ADDR_BITS - DMA_BATCH_BITS){1'd0}, n_batch};
    //*    AXI_ADDR_BITS   <= AXI_DATA_BITS !!!! NOTICE !!!!
    assign DeltaAddr        = DMALEN - FinishCount;

    // ============================================================
    // Combinational output DMA / simple wires
    // ============================================================
    always_comb begin
        if (isDMA_en) begin 
            if (isTransferring) begin
                SrcAddr_perBurst = DMASRC + FinishCount;
                DstAddr_perBurst = DMADST + FinishCount;
            end 
                SrcAddr_perBurst = NEXT_DESC;
                DstAddr_perBurst = `AXI_ADDR_BITS'd0;
        end else
            SrcAddr_perBurst = `AXI_ADDR_BITS'd0;
            DstAddr_perBurst = `AXI_ADDR_BITS'd0;
    end
    always_comb begin
        // DeltaAddr <= `AXI_LEN_BITS{1'd1} 
        if (DeltaAddr <= {(`AXI_DATA_BITS - `AXI_LEN_BITS){1'd0}, `AXI_LEN_BITS{1'd1}}) begin
            TransSize = DeltaAddr[`AXI_LEN_BITS-1:0];
        end else begin
            TransSize = {`AXI_LEN_BITS{1'd1}};
        end
    end
    assign EOBatch       = DeltaAddr <= {(`AXI_DATA_BITS - `AXI_LEN_BITS){1'd0}, `AXI_LEN_BITS{1'd1}};
    assign EOT           = EOBatch && EOB;
    assign DMA_interrupt = isDMA_en && EOC && EOT && isTransferring;

    // ============================================================
    // (Optional) Assertions – enable if you have SVA in flow
    // ============================================================
    // property p_desc_write_sel_valid;
    //   @(posedge clk) disable iff (rst)
    //     DESC_write_en |-> (DESC_sel <= 4'd4);
    // endproperty
    // assert property (p_desc_write_sel_valid);

endmodule
