/*------------------------------------------------------------------------------
 * File        : DMA_wrapper.sv
 * Brief       : AXI-based DMA wrapper (Master M2 + Slave S3 sideband control)
 * Description :
 *   - Slave S3 提供簡易 CSR 介面（以 AWADDR=DMA_BASE_ADDR 寫入 DMAEN）
 *   - Master M2 先讀 Descriptor，再做 SRC->DST 的搬運
 * Reset       : ARESETn (active-low). Internally converted to rst = ~ARESETn.
 * Notes       : 依 `AXI_*` 巨集定義寬度；注意 `AXI_ID_BITS` vs `AXI_IDS_BITS`
 *----------------------------------------------------------------------------*/

module DMA_wrapper (
    // =========================
    // Clocks & Reset
    // =========================
    input  logic                        ACLK,
    input  logic                        ARESETn,

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
    localparam logic [`AXI_ADDR_BITS-1:0] DMA_BASE_ADDR = 32'h1002_0100;
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
        DMemAddressPhase      = 3'd1,
        DMemReadData          = 3'd2,
        IMemDramAdressPhase   = 3'd3,
        DramReadIMemWriteData = 3'd4
    } m2_state_t;

    // ============================================================
    // DMA side wires/regs
    // ============================================================
    logic                      wireDMAEN;
    logic [`AXI_ADDR_BITS-1:0] wireDESC_BASE;
    logic [`AXI_DATA_BITS-1:0] wireDESC_input;
    logic                      wireDESC_write_en;
    logic [3:0]                wireDESC_sel;
    logic                      wireDone;

    logic                      DMAEN_output;
    logic [`AXI_ADDR_BITS-1:0] DMASRC, DMADST, NEXT_DESC;
    logic [`AXI_DATA_BITS-1:0] DMALEN;
    logic                      EOC;
    logic [`AXI_ADDR_BITS-1:0] SRC_ADDR, DST_ADDR;
    logic                      DMA_interrupt;

    // ============================================================
    // Slave FSM
    // ============================================================
    trans_state_t                       CurrentState_S3, NextState_S3;
    logic [`AXI_IDS_BITS-1:0]           SlaveAWID_reg;
    logic [`AXI_ADDR_BITS-1:0]          SlaveRWAddr_reg;
    logic [`AXI_LEN_BITS-1:0]           SlaveRWLen_reg;
    logic [`AXI_SIZE_BITS-1:0]          SlaveRWSize_reg;
    logic [1:0]                         SlaveRWBurst_reg;

    // State reg
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) CurrentState_S3 <= ACCEPT;
        else          CurrentState_S3 <= NextState_S3;
    end

    // Next state
    always_comb begin
        unique case (CurrentState_S3)
            ACCEPT: begin
                if (AWVALID_S3 && (AWADDR_S3 == DMA_BASE_ADDR))  NextState_S3 = WriteData;
                else if (ARVALID_S3)                             NextState_S3 = ReadData;
                else                                             NextState_S3 = ACCEPT;
            end
            ReadData: begin
                if (RVALID_S3 && RREADY_S3 && RLAST_S3)          NextState_S3 = ACCEPT;
                else                                             NextState_S3 = ReadData;
            end
            WriteData: begin
                if (WVALID_S3 && WREADY_S3 && WLAST_S3)          NextState_S3 = WriteResponse;
                else                                             NextState_S3 = WriteData;
            end
            WriteResponse: begin
                if (BVALID_S3 && BREADY_S3)                      NextState_S3 = ACCEPT;
                else                                             NextState_S3 = WriteResponse;
            end
            default:                                             NextState_S3 = ACCEPT;
        endcase
    end

    // AW/AR ready
    assign AWREADY_S3 = (CurrentState_S3 == ACCEPT) && ~DMAEN_output;
    assign ARREADY_S3 = (CurrentState_S3 == ACCEPT) && ~DMAEN_output;

    // Latch AW* (只在需寫入 DMAEN 的情境)
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            SlaveAWID_reg    <= '0;
            SlaveRWAddr_reg  <= '0;
            SlaveRWLen_reg   <= '0;
            SlaveRWSize_reg  <= '0;
            SlaveRWBurst_reg <= 2'd0;
        end else if ((CurrentState_S3 == ACCEPT) && AWVALID_S3 && (AWADDR_S3 == DMA_BASE_ADDR)) begin
            SlaveAWID_reg    <= AWID_S3;
            SlaveRWAddr_reg  <= AWADDR_S3;
            SlaveRWLen_reg   <= AWLEN_S3;
            SlaveRWSize_reg  <= AWSIZE_S3;
            SlaveRWBurst_reg <= AWBURST_S3;
        end
    end

    // Write Data Channel (寫 DMAEN)
    always_comb begin
        WREADY_S3 = (CurrentState_S3 == WriteData);
        if (CurrentState_S3 == WriteData) begin
            wireDMAEN = (WVALID_S3 && (WSTRB_S3 == {`AXI_STRB_BITS{1'b1}})) ? WDATA_S3[0] : 1'b0;
        end else begin
            wireDMAEN = (wireDone) ? 1'b0 : DMAEN_output;
        end
    end

    // Write Response Channel
    always_comb begin
        if (CurrentState_S3 == WriteResponse) begin
            BID_S3    = SlaveAWID_reg;
            BRESP_S3  = `AXI_RESP_OKAY;
            BVALID_S3 = 1'b1;
        end else begin
            BID_S3    = '0;
            BRESP_S3  = `AXI_RESP_DECERR;
            BVALID_S3 = 1'b0;
        end
    end

    // 簡化處理：此 wrapper 不回傳真正的 Read Data，固定一次拍回應
    assign RID_S3    = ARID_S3;
    assign RDATA_S3  = '0;
    assign RRESP_S3  = `AXI_RESP_DECERR;
    assign RLAST_S3  = 1'b1;
    assign RVALID_S3 = (CurrentState_S3 == ReadData);

    // ============================================================
    // Master M2 FSM
    // ============================================================
    m2_state_t                           CurrentState_M2, NextState_M2;
    logic   [`AXI_LEN_BITS-1:0]          rwLEN, rwCount;

    // State reg
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) CurrentState_M2 <= IDLE;
        else          CurrentState_M2 <= NextState_M2;
    end

    // Next state
    always_comb begin
        unique case (CurrentState_M2)
            IDLE:                         NextState_M2 = DMemAddressPhase;
            DMemAddressPhase: begin
                if (ARREADY_M2 && wireDMAEN)                NextState_M2 = DMemReadData;
                else                                        NextState_M2 = DMemAddressPhase;
            end
            DMemReadData: begin
                if (RVALID_M2 && RREADY_M2 && RLAST_M2)     NextState_M2 = IMemDramAdressPhase;
                else                                        NextState_M2 = DMemReadData;
            end
            IMemDramAdressPhase: begin
                if (AWREADY_M2 && ARREADY_M2)               NextState_M2 = DramReadIMemWriteData;
                else                                        NextState_M2 = IMemDramAdressPhase;
            end
            DramReadIMemWriteData: begin
                if (RVALID_M2 && RREADY_M2 && WVALID_M2 && WREADY_M2 && RLAST_M2)
                                                        NextState_M2 = DMemAddressPhase;
                else                                    NextState_M2 = DramReadIMemWriteData;
            end
            default:                                      NextState_M2 = IDLE;
        endcase
    end

    // --------- Master Read Address ---------
    always_comb begin
        // defaults
        ARID_M2    = '0;
        ARADDR_M2  = '0;
        ARLEN_M2   = `AXI_LEN_ONE;
        ARSIZE_M2  = `AXI_SIZE_WORD;
        ARBURST_M2 = `AXI_BURST_INC;
        ARVALID_M2 = 1'b0;

        if (CurrentState_M2 == DMemAddressPhase && wireDMAEN) begin
            ARID_M2    = DESC_ID[`AXI_ID_BITS-1:0];
            ARADDR_M2  = DMAEN_output ? NEXT_DESC : DMA_BASE_ADDR; // 讀描述子（5筆字）
            ARLEN_M2   = `AXI_LEN_BITS'(4-1);                      // 5 beats => LEN=4
            ARSIZE_M2  = `AXI_SIZE_WORD;
            ARBURST_M2 = `AXI_BURST_INC;
            ARVALID_M2 = 1'b1;
        end else if (CurrentState_M2 == IMemDramAdressPhase) begin
            ARID_M2    = SRC_ID[`AXI_ID_BITS-1:0];
            ARADDR_M2  = SRC_ADDR;
            ARLEN_M2   = DMALEN[`AXI_LEN_BITS-1:0];                // 假設 DMALEN 已是 beat-1
            ARSIZE_M2  = `AXI_SIZE_WORD;
            ARBURST_M2 = `AXI_BURST_INC;
            ARVALID_M2 = 1'b1;
        end
    end

    // --------- Master Read Data ---------
    assign RREADY_M2 = (CurrentState_M2 == DMemReadData) ||
                       (CurrentState_M2 == DramReadIMemWriteData);

    always_comb begin
        wireDESC_input = '0;
        if (CurrentState_M2 == DMemReadData && RVALID_M2) begin
            wireDESC_input = RDATA_M2;
        end
    end

    // --------- Master Write Address ---------
    always_comb begin
        // defaults
        AWID_M2    = '0;
        AWADDR_M2  = '0;
        AWLEN_M2   = `AXI_LEN_ONE;
        AWSIZE_M2  = `AXI_SIZE_WORD;
        AWBURST_M2 = `AXI_BURST_INC;
        AWVALID_M2 = 1'b0;

        if (CurrentState_M2 == IMemDramAdressPhase) begin
            AWID_M2    = SRC_ID[`AXI_ID_BITS-1:0];
            AWADDR_M2  = DST_ADDR;
            AWLEN_M2   = DMALEN[`AXI_LEN_BITS-1:0];  // 假設 DMALEN 已是 beat-1
            AWSIZE_M2  = `AXI_SIZE_WORD;
            AWBURST_M2 = `AXI_BURST_INC;
            AWVALID_M2 = 1'b1;
        end
    end

    // --------- Master Write Data ---------
    always_comb begin
        // defaults
        WDATA_M2  = '0;
        WSTRB_M2  = '0;
        WLAST_M2  = 1'b0;
        WVALID_M2 = 1'b0;

        if (CurrentState_M2 == DramReadIMemWriteData) begin
            WDATA_M2  = RDATA_M2;
            WSTRB_M2  = {`AXI_STRB_BITS{1'b1}};
            WLAST_M2  = (rwCount == rwLEN);
            WVALID_M2 = RVALID_M2 && RREADY_M2;
        end
    end

    // --------- Write Response ---------
    assign BREADY_M2 = (CurrentState_M2 == DramReadIMemWriteData);

    // --------- RW counters ---------
    always_comb begin
        unique case (CurrentState_M2)
            DMemReadData:             rwLEN = `AXI_LEN_BITS'(5-1); // 讀5筆描述子 => LEN=5
            DramReadIMemWriteData:    rwLEN = DMALEN[`AXI_LEN_BITS-1:0];
            default:                  rwLEN = '0;
        endcase
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rwCount <= '0;
        end else if ((CurrentState_M2 == DMemReadData) ||
                     (CurrentState_M2 == DramReadIMemWriteData)) begin
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
    assign wireDESC_BASE      = DMA_BASE_ADDR;
    assign wireDESC_write_en  = (CurrentState_M2 == DMemReadData) && RVALID_M2 && RREADY_M2;
    assign wireDESC_sel       = rwCount[3:0]; // 0:DMASRC,1:DMADST,2:DMALEN,3:NEXT_DESC,4:EOC
    assign wireDone           = (CurrentState_M2 == DramReadIMemWriteData) && EOC &&
                                RVALID_M2 && RREADY_M2 && RLAST_M2;

    DMA dma (
        .clk            (ACLK              ),
        .rst            (~ARESETn          ),
        .DMAEN          (wireDMAEN         ),
        .DESC_BASE      (wireDESC_BASE     ),
        .DESC_input     (wireDESC_input    ),
        .DESC_write_en  (wireDESC_write_en ),
        .DESC_sel       (wireDESC_sel      ),
        .Done           (wireDone          ),
        .DMAEN_output   (DMAEN_output      ),
        .DMASRC         (DMASRC            ),
        .DMADST         (DMADST            ),
        .DMALEN         (DMALEN            ),
        .NEXT_DESC      (NEXT_DESC         ),
        .EOC            (EOC               ),
        .SRC_ADDR       (SRC_ADDR          ),
        .DST_ADDR       (DST_ADDR          ),
        .DMA_interrupt  (DMA_interrupt     )
    );

endmodule
