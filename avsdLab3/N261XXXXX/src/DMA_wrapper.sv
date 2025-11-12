/*------------------------------------------------------------------------------
 * File        : DMA_wrapper.sv
 * Brief       : AXI-based DMA wrapper (Master M2 + Slave S3 sideband control)
 * Description :
 *   - Slave S3 提供簡易 CSR 介面（以 AWADDR=DMA_EN_ADDR 寫入 DMAEN）
 *   - Master M2 先讀 5 筆 Descriptor（含 EOC），再做 SRC->DST 的搬運
 * Reset       : ARESETn (active-low). Internally converted to rst = ~ARESETn.
 * Notes       : 依 `AXI_*` 巨集定義寬度；注意 `AXI_ID_BITS` vs `AXI_IDS_BITS`
 *----------------------------------------------------------------------------*/

module DMA_wrapper (
    // =========================
    // Clocks & Reset
    // =========================
    input  logic                        ACLK,
    input  logic                        ARESETn,
    output logic                        Interrupt,
    // =========================
    // AXI Master M2 (to system bus)
    // =========================
    // Write Address
    output logic [`AXI_ID_BITS-1:0]     AWID_M2,
    output logic [`AXI_ADDR_BITS-1:0]   AWADDR_M2,
    output logic [`AXI_LEN_BITS-1:0]    AWLEN_M2,
    output logic [`AXI_SIZE_BITS-1:0]   AWSIZE_M2,
    output logic [1:0]                  AWBURST_M2,
    output logic                        AWVALID_M2,
    input  logic                        AWREADY_M2,
    // Write Data
    output logic [`AXI_DATA_BITS-1:0]   WDATA_M2,
    output logic [`AXI_STRB_BITS-1:0]   WSTRB_M2,
    output logic                        WLAST_M2,
    output logic                        WVALID_M2,
    input  logic                        WREADY_M2,
    // Write Response
    input  logic [`AXI_ID_BITS-1:0]     BID_M2,
    input  logic [1:0]                  BRESP_M2,
    input  logic                        BVALID_M2,
    output logic                        BREADY_M2,
    // Read Address
    output logic [`AXI_ID_BITS-1:0]     ARID_M2,
    output logic [`AXI_ADDR_BITS-1:0]   ARADDR_M2,
    output logic [`AXI_LEN_BITS-1:0]    ARLEN_M2,
    output logic [`AXI_SIZE_BITS-1:0]   ARSIZE_M2,
    output logic [1:0]                  ARBURST_M2,
    output logic                        ARVALID_M2,
    input  logic                        ARREADY_M2,
    // Read Data
    input  logic [`AXI_ID_BITS-1:0]     RID_M2,
    input  logic [`AXI_DATA_BITS-1:0]   RDATA_M2,
    input  logic [1:0]                  RRESP_M2,
    input  logic                        RLAST_M2,
    input  logic                        RVALID_M2,
    output logic                        RREADY_M2,

    // =========================
    // AXI Slave S3 (from CPU side)
    // =========================
    // Write Address
    input  logic [`AXI_IDS_BITS-1:0]    AWID_S3,
    input  logic [`AXI_ADDR_BITS-1:0]   AWADDR_S3,
    input  logic [`AXI_LEN_BITS-1:0]    AWLEN_S3,
    input  logic [`AXI_SIZE_BITS-1:0]   AWSIZE_S3,
    input  logic [1:0]                  AWBURST_S3,
    input  logic                        AWVALID_S3,
    output logic                        AWREADY_S3,
    // Write Data
    input  logic [`AXI_DATA_BITS-1:0]   WDATA_S3,
    input  logic [`AXI_STRB_BITS-1:0]   WSTRB_S3,
    input  logic                        WLAST_S3,
    input  logic                        WVALID_S3,
    output logic                        WREADY_S3,
    // Write Response
    output logic [`AXI_IDS_BITS-1:0]    BID_S3,
    output logic [1:0]                  BRESP_S3,
    output logic                        BVALID_S3,
    input  logic                        BREADY_S3,
    // Read Address
    input  logic [`AXI_IDS_BITS-1:0]    ARID_S3,
    input  logic [`AXI_ADDR_BITS-1:0]   ARADDR_S3,
    input  logic [`AXI_LEN_BITS-1:0]    ARLEN_S3,
    input  logic [`AXI_SIZE_BITS-1:0]   ARSIZE_S3,
    input  logic [1:0]                  ARBURST_S3,
    input  logic                        ARVALID_S3,
    output logic                        ARREADY_S3,
    // Read Data (dummy response to complete handshake)
    output logic [`AXI_IDS_BITS-1:0]    RID_S3,
    output logic [`AXI_DATA_BITS-1:0]   RDATA_S3,
    output logic [1:0]                  RRESP_S3,
    output logic                        RLAST_S3,
    output logic                        RVALID_S3,
    input  logic                        RREADY_S3
);

    // =========================
    // Parameters
    // =========================
    localparam logic [`AXI_ADDR_BITS-1:0] DMA_EN_ADDR   = 32'h1002_0100; // CSR: write DMAEN here
    localparam logic [`AXI_ADDR_BITS-1:0] DESC_BASE_ADDR= 32'h1002_0200; // descriptor base
    localparam logic [`AXI_IDS_BITS-1:0]  DESC_ID       = '0;
    localparam logic [`AXI_IDS_BITS-1:0]  SRC_ID        = '0;

    typedef enum logic [1:0] {
        ACCEPT        = 2'd0,
        ReadData      = 2'd1,
        WriteData     = 2'd2,
        WriteResponse = 2'd3
    } trans_state_t;

    typedef enum logic [2:0] {
        IDLE                  = 3'd0,
        DESCAddressPhase      = 3'd1,
        ReadDESCData          = 3'd2,
        TransferAdressPhase   = 3'd3,
        TransferData          = 3'd4
    } m2_state_t;

    // ============================================================
    // DMA side wires/regs
    // ============================================================

    // =========================
    // Control / Descriptor I/F
    // =========================
    logic                         DMAEN;
    logic [`AXI_DATA_BITS-1:0]    DESC_input;
    logic [3:0]                   sel;            // 0:DMASRC,1:DMADST,2:DMALEN,3:NEXT_DESC,4:EOC,7:BASEADDR
    logic                         EOB;            // End of Burst
    logic                         isTransferring; // is Transfer state

    logic                        isDMA_en;
    // Convenience mirrors (same width as DMASRC/DMADST)
    logic [`AXI_ADDR_BITS-1:0]   SrcAddr_perBurst;
    logic [`AXI_ADDR_BITS-1:0]   DstAddr_perBurst;
    logic [`AXI_LEN_BITS-1:0]    TransSize;
    logic                        EOT;
    // Interrupt
    logic                        DMA_interrupt;


    // ============================================================
    // Slave S3 FSM
    // ============================================================
    trans_state_t                       CurrentState_S3, NextState_S3;
    logic [`AXI_IDS_BITS-1:0]           SlaveAWID_reg;
    logic [`AXI_ADDR_BITS-1:0]          SlaveRWAddr_reg;
    logic [`AXI_LEN_BITS-1:0]           SlaveRWLen_reg;
    logic [`AXI_SIZE_BITS-1:0]          SlaveRWSize_reg;
    logic [1:0]                         SlaveRWBurst_reg;


    // State reg
    always_ff @(posedge ACLK or posedge ARESETn) begin
        if (ARESETn)  CurrentState_S3   <= ACCEPT;
        else          CurrentState_S3   <= NextState_S3;
    end

    // Next state
    always_comb begin
        unique case (CurrentState_S3)
            ACCEPT: begin
                if (AWREADY_S3 && AWVALID_S3 && ((AWADDR_S3 == DMA_EN_ADDR) || (AWADDR_S3 == DESC_BASE_ADDR))) 
                                                                NextState_S3 = WriteData;
                else if (RVALID_S3)                             NextState_S3 = ReadData;
                else                                            NextState_S3 = ACCEPT;
            end
            ReadData: begin
                // 立即回一拍 dummy read（RVALID/RLAST=1），即可返回 ACCEPT
                if (RVALID_S3 && RREADY_S3 && RLAST_S3)         NextState_S3 = ACCEPT;
                else                                            NextState_S3 = ReadData;
            end
            WriteData: begin
                if (WVALID_S3 && WREADY_S3 && WLAST_S3)         NextState_S3 = WriteResponse;
                else                                            NextState_S3 = WriteData;
            end
            WriteResponse: begin
                if (BVALID_S3 && BREADY_S3)                     NextState_S3 = ACCEPT;
                else                                            NextState_S3 = WriteResponse;
            end
            default:                                            NextState_S3 = ACCEPT;
        endcase
    end

    // Latch AW*（只在需寫 DMAEN 的情境）
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (ARESETn) begin
            SlaveAWID_reg    <= '0;
            SlaveRWAddr_reg  <= '0;
            SlaveRWLen_reg   <= '0;
            SlaveRWSize_reg  <= '0;
            SlaveRWBurst_reg <= 2'd0;
        end else if ((CurrentState_S3 == ACCEPT) && AWVALID_S3 && ((AWADDR_S3 == DMA_EN_ADDR) || (AWADDR_S3 == DESC_BASE_ADDR))) begin
            SlaveAWID_reg    <= AWID_S3;
            SlaveRWAddr_reg  <= AWADDR_S3;
            SlaveRWLen_reg   <= AWLEN_S3;
            SlaveRWSize_reg  <= AWSIZE_S3;
            SlaveRWBurst_reg <= AWBURST_S3;
        end else if (DMA_interrupt) begin
            SlaveAWID_reg    <= '0;
            SlaveRWAddr_reg  <= '0;
            SlaveRWLen_reg   <= '0;
            SlaveRWSize_reg  <= '0;
            SlaveRWBurst_reg <= 2'd0;
        end
    
        end

    // Write Data Channel（寫 DMAEN）
    always_comb begin
        if (CurrentState_S3 == WriteData && SlaveRWAddr_reg == DMA_EN_ADDR) begin
            DMAEN          = (WVALID_S3 && (WSTRB_S3 == {`AXI_STRB_BITS{1'b1}})) ? WDATA_S3[0] : isDMA_en;
        end else begin
            // TODO
            DMAEN          = isDMA_en;
        end
    end
    // ---------- S3 channel outputs ----------
    always_comb begin
        // defaults
        AWREADY_S3 = 1'b0;
        ARREADY_S3 = 1'b0;
        // W
        WREADY_S3  = 1'b0;
        // B
        BID_S3     = '0;
        BRESP_S3   = `AXI_RESP_DECERR;
        BVALID_S3  = 1'b0;
        // R
        RID_S3     = '0;
        RDATA_S3   = '0;
        RRESP_S3   = `AXI_RESP_DECERR;
        RLAST_S3   = 1'b0;
        RVALID_S3  = 1'b0;

        unique case (CurrentState_S3)
            ACCEPT: begin
                AWREADY_S3 = ~DMAEN_output;
                ARREADY_S3 = ~DMAEN_output;
            end
            ReadData: begin
                // 回 1 拍讀資料完成握手（dummy）
                RID_S3     = ARID_S3;
                RDATA_S3   = '0;
                RRESP_S3   = `AXI_RESP_DECERR;
                RLAST_S3   = 1'b1;
                RVALID_S3  = 1'b1;
            end
            WriteData: begin
                WREADY_S3  = 1'b1;
            end
            WriteResponse: begin
                BID_S3     = SlaveAWID_reg;
                BRESP_S3   = `AXI_RESP_OKAY;
                BVALID_S3  = 1'b1;
            end
        endcase
    end

    // ============================================================
    // Master M2 FSM
    // ============================================================
    m2_state_t                          CurrentState_M2, NextState_M2;
    // Master M2 FSM signals
    // ============================================================

    // State reg
    always_ff @(posedge ACLK or posedge ARESETn) begin
        if (ARESETn)  CurrentState_M2 <= IDLE;
        else          CurrentState_M2 <= NextState_M2;
    end
    
    always_ff @(posedge ACLK or posedge ARESETn) begin
        case (CurrentState_M2)
            IDLE: begin
                // TODO  ** SlaveRWAddr_reg ==  DESC_BASE_ADDR
                if (isDMA_en && SlaveRWAddr_reg ==  DESC_BASE_ADDR)  
                                                            NextState_M2 = DESCAddressPhase;
                else                                        NextState_M2 = IDLE;
            end
            DESCAddressPhase: begin
                if (~DMAEN)                                 NextState_M2 = IDLE;
                else if (ARVALID_M2 && ARREADY_M2)          NextState_M2 = ReadDESCData;
                else                                        NextState_M2 = DESCAddressPhase;
            end
            ReadDESCData: begin
                if (~DMAEN)                                  NextState_M2 = IDLE;
                else if (RVALID_M2 && RREADY_M2 && RLAST_M2) NextState_M2 = ReadDESCData;
                else                                         NextState_M2 = DESCAddressPhase;
            end
            TransferAdressPhase: begin
                if (~DMAEN)                                 NextState_M2 = IDLE;
                else if (AWREADY_M2 && ARREADY_M2 && ARVALID_M2 && AWVALID_M2)
                                                            NextState_M2 = TransferData;
                else                                        NextState_M2 = TransferAdressPhase;
            end
            TransferData: begin
                if (~DMAEN)                                 NextState_M2 = IDLE;
                else if (DMA_interrupt)                     NextState_M2 = IDLE;
                else if (EOT)                               NextState_M2 = DESCAddressPhase;
                else                                        NextState_M2 = TransferData;
            end

        endcase
    end



    // ---------- Master outputs ----------
    always_comb begin
        // defaults
        // Read Address
        ARID_M2    = '0;
        ARADDR_M2  = '0;
        ARLEN_M2   = `AXI_LEN_ONE;
        ARSIZE_M2  = `AXI_SIZE_WORD;
        ARBURST_M2 = `AXI_BURST_INC;
        ARVALID_M2 = 1'b0;
        // Read Data
        RREADY_M2  = 1'b0;
        // Write Address
        AWID_M2    = '0;
        AWADDR_M2  = '0;
        AWLEN_M2   = `AXI_LEN_ONE;
        AWSIZE_M2  = `AXI_SIZE_WORD;
        AWBURST_M2 = `AXI_BURST_INC;
        AWVALID_M2 = 1'b0;
        // Write Data
        WDATA_M2   = '0;
        WSTRB_M2   = '0;
        WLAST_M2   = 1'b0;
        WVALID_M2  = 1'b0;


        unique case (CurrentState_M2)
            DESCAddressPhase: begin
                ARID_M2    = DESC_ID[`AXI_ID_BITS-1:0];
                ARADDR_M2  = DstAddr_perBurst; // 讀 5 筆（含 EOC）
                ARLEN_M2   = `AXI_LEN_BITS'(5-1);                         // 5 beats => LEN=4
                ARSIZE_M2  = `AXI_SIZE_WORD;
                ARBURST_M2 = `AXI_BURST_INC;
                ARVALID_M2 = 1'b1;
            end
            ReadDESCData: begin
                RREADY_M2 = 1'b1;
            end
            TransferAdressPhase: begin
                // Read Address（從 SRC 搬出）
                ARID_M2    = SRC_ID[`AXI_ID_BITS-1:0];
                ARADDR_M2  = SrcAddr_perBurst;
                ARLEN_M2   = TransSize[`AXI_LEN_BITS-1:0]; // 假設 DMALEN 已是 beat-1
                ARSIZE_M2  = `AXI_SIZE_WORD;
                ARBURST_M2 = `AXI_BURST_INC;
                ARVALID_M2 = 1'b1;
                // Write Address（寫入 DST）
                AWID_M2    = SRC_ID[`AXI_ID_BITS-1:0];
                AWADDR_M2  = DstAddr_perBurst;
                AWLEN_M2   = TransSize[`AXI_LEN_BITS-1:0];
                AWSIZE_M2  = `AXI_SIZE_WORD;
                AWBURST_M2 = `AXI_BURST_INC;
                AWVALID_M2 = 1'b1;
            end
            TransferData: begin
                RREADY_M2  = 1'b1;
                WDATA_M2   = RDATA_M2;
                WSTRB_M2   = {`AXI_STRB_BITS{1'b1}};
                WLAST_M2   = RLAST_M2;
                WVALID_M2  = RVALID_M2 && RREADY_M2;
            end
        endcase
    end
    // Write Response
    always_ff @(posedge ACLK or posedge ARESETn) begin
        if (ARESETn) begin
            // Write Response
                            BREADY_M2  <= 1'b0; 
        end else begin
            if (CurrentState_M2 == TransferData && EOB) begin
                            BREADY_M2  <= 1'b1;
            end else begin
                            BREADY_M2  <= 1'b0;
            end
        end
    end

    // --------- RW counters ---------
    always_comb begin
        unique case (CurrentState_M2)
            ReadDESCData:             rwLEN = `AXI_LEN_BITS'(5-1); // 讀 5 筆描述子（含 EOC）
            TransferData:             rwLEN = TransSize;
            default:                  rwLEN = '0;
        endcase
    end

    always_ff @(posedge ACLK or posedge ARESETn) begin
        if (ARESETn) begin
            rwCount <= '0;
        end else if ((CurrentState_M2 == ReadDESCData) ||
                     (CurrentState_M2 == TransferData)) begin
            if ((rwCount == rwLEN) && RVALID_M2 && RREADY_M2 && RLAST_M2)
                rwCount <= '0;
            else if (RREADY_M2 && RVALID_M2)
                rwCount <= rwCount + 1'b1;
        end else begin
            rwCount <= '0;
        end
    end

    // ============================================================
    // DMA instance & glue
    // ============================================================
    // Descriptor read data feed into DMA regs
    always_comb begin
        DESC_input = '0;
        sel        = '0;
        // TODO
        if (CurrentState_S3 == WriteData && SlaveRWAddr_reg == DESC_BASE_ADDR) begin
            DESC_input  = WDATA_S3;
            sel         = 4'd4;
        end else if (CurrentState_M2 == ReadDESCData && RVALID_M2) begin
            DESC_input  = RDATA_M2;
            sel         = (rwCount + `AXI_LEN_BITS'd1)[3:0];
        end
    end
    assign EOB            = RREADY_M2 && WREADY_M2 && RVALID_M2 && WVALID_M2 && WLAST_M2;
    assign isTransferring = (CurrentState_M2 == TransferAdressPhase) || (CurrentState_M2 == TransferData);


    DMA dma (
        // =========================
        // Clocks & Reset
        // =========================
        clk             (clk),
        rst             (rst),

        // =========================
        // Control / Descriptor I/F
        // =========================
        DMAEN           (DMAEN),
        DESC_input      (DESC_input),
        sel             (sel),             // 0:DMASRC,1:DMADST,2:DMALEN,3:NEXT_DESC,4:EOC,7:BASEADDR
        EOB             (EOB),             // End of Burst
        isTransferring  (isTransferring),  // is Transfer state

        isDMA_en        (DMAEN_output),
        // Convenience mirrors (same width as DMASRC/DMADST)
        SrcAddr_perBurst(SrcAddr_perBurst),
        DstAddr_perBurst(DstAddr_perBurst),
        TransSize       (TransSize),
        EOT             (EOT),
        // Interrupt
        DMA_interrupt   (Interrupt)
    );

endmodule
