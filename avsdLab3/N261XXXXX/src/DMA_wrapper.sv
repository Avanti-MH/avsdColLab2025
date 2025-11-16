`include "../include/AXI_define.svh"
`include "../src/DMA/DMA.sv"

module DMA_wrapper (

    input  logic                        clk,
    input  logic                        rst,

    // =============================================================================
    // Master 2
    // =============================================================================

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

    // =============================================================================
    // Slave 3
    // =============================================================================

    // Read Address
    input  logic [`AXI_IDS_BITS-1:0]    ARID_S3,
    input  logic [`AXI_ADDR_BITS-1:0]   ARADDR_S3,
    input  logic [`AXI_LEN_BITS-1:0]    ARLEN_S3,
    input  logic [`AXI_SIZE_BITS-1:0]   ARSIZE_S3,
    input  logic [1:0]                  ARBURST_S3,
    input  logic                        ARVALID_S3,
    output logic                        ARREADY_S3,
    // Read Data
    output logic [`AXI_IDS_BITS-1:0]    RID_S3,
    output logic [`AXI_DATA_BITS-1:0]   RDATA_S3,
    output logic [1:0]                  RRESP_S3,
    output logic                        RLAST_S3,
    output logic                        RVALID_S3,
    input  logic                        RREADY_S3,

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

    // interrupt
    output logic                        DMA_interrupt
);
    //-------------------------------------------------------Slave 3-------------------------------------------------------//


    //====================================================
    // Local Parameters
    //====================================================
    localparam logic [`AXI_ADDR_BITS-1:0] DMA_EN_ADDR    = 32'h0000_0100;
    localparam logic [`AXI_ADDR_BITS-1:0] DESC_BASE_ADDR = 32'h0000_0200;

    //====================================================
    // State Definition
    //====================================================
    typedef enum logic [1:0] {
        ACCEPT        = 2'd0,
        ReadData      = 2'd1,
        WriteData     = 2'd2,
        WriteResponse = 2'd3
    } s3_state_t;

    s3_state_t CurrentState_S3, NextState_S3;

    // ============================================================
    // Local Signals
    // ============================================================
    logic [`AXI_IDS_BITS-1:0]  ARID_S, AWID_S;
    logic [`AXI_ADDR_BITS-1:0] ADDR_S;
    logic                      DMAEN_VALID, DMAEN;

    //====================================================
    // Finite State Machine
    //====================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) CurrentState_S3 <= ACCEPT;
        else     CurrentState_S3 <= NextState_S3;
    end

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        unique case (CurrentState_S3)
            ACCEPT: begin
                if      (AWVALID_S3)                    NextState_S3 = WriteData;
                else if (ARVALID_S3)                    NextState_S3 = ReadData;
                else                                    NextState_S3 = CurrentState_S3;
            end
            ReadData: begin
                if (RVALID_S3 && RREADY_S3 && RLAST_S3) NextState_S3 = ACCEPT;
                else                                    NextState_S3 = CurrentState_S3;
            end
            WriteData: begin
                if (WVALID_S3 && WREADY_S3 && WLAST_S3) NextState_S3 = WriteResponse;
                else                                    NextState_S3 = CurrentState_S3;
            end
            WriteResponse: begin
                if (BVALID_S3 && BREADY_S3)             NextState_S3 = ACCEPT;
                else                                    NextState_S3 = CurrentState_S3;
            end
            default:                                    NextState_S3 = ACCEPT;
        endcase
    end

    // ============================================================
    // Channel Output Logic (combinational)
    // ============================================================
    always_comb begin
        ARREADY_S3 = 1'b0;
        AWREADY_S3 = 1'b0;
        RID_S3     = `AXI_IDS_BITS'd0;
        RDATA_S3   = `AXI_DATA_BITS'd0;
        RRESP_S3   = `AXI_RESP_DECERR;
        RLAST_S3   = 1'b0;
        RVALID_S3  = 1'b0;
        WREADY_S3  = 1'b0;
        BID_S3     = `AXI_IDS_BITS'd0;
        BRESP_S3   = `AXI_RESP_DECERR;
        BVALID_S3  = 1'b0;
        case (CurrentState_S3)
            ACCEPT: begin
                ARREADY_S3 = 1'b1;
				AWREADY_S3 = 1'b1;
            end
            ReadData: begin
                RID_S3     = ARID_S;
                RVALID_S3  = 1'b1;
                RLAST_S3   = 1'b1;
            end
            WriteData: begin
                WREADY_S3  = 1'b1;
            end
            WriteResponse: begin
                BID_S3     = AWID_S;
                BVALID_S3  = 1'b1;
                BRESP_S3   = `AXI_RESP_OKAY;
            end
        endcase
    end

    // ============================================================
	// Request Information Storage
	// ============================================================
    always_ff @( posedge clk or posedge rst ) begin
		if (rst) begin
			ARID_S <= `AXI_IDS_BITS'd0;
			AWID_S <= `AXI_IDS_BITS'd0;
			ADDR_S <= `AXI_ADDR_BITS'd0;
		end else if(CurrentState_S3 == ACCEPT)begin
			ARID_S <= (ARVALID_S3) ? ARID_S  : ARID_S;
			AWID_S <= (AWVALID_S3) ? AWID_S  : AWID_S;
			ADDR_S <= (ARVALID_S3) ? ARADDR_S3: (AWVALID_S3 ? AWADDR_S3 : ADDR_S);
		end
	end

    // ============================================================
	// DMA Enable
	// ============================================================
    always_comb begin
        if (WVALID_S3 && WREADY_S3 && (ADDR_S == DMA_EN_ADDR)) begin
            DMAEN_VALID      = 1'b1;
            DMAEN            = WDATA_S3[0];
        end else begin
            DMAEN_VALID      = 1'b0;
            DMAEN            = 1'b0;
        end
    end

    //-------------------------------------------------------Master 2-------------------------------------------------------//

    //====================================================
    // State Definition
    //====================================================
    typedef enum logic [2:0] {
        IDLE                  = 3'd0,
        DESCAddressPhase      = 3'd1,
        ReadDESCData          = 3'd2,
        TransferAdressPhase   = 3'd3,
        TransferData          = 3'd4
    } m2_state_t;

    m2_state_t CurrentState_M2, NextState_M2;

    // ============================================================
    // Local Signals
    // ============================================================
    logic [`AXI_LEN_BITS-1:0]  LEN, LEN_cnt, DMA_BURST_LEN;
    logic                      buf_ARREADY_M2, buf_AWREADY_M2;
    logic                      DMA_WEn;
    logic [2:0]                DMA_A;
    logic [`AXI_DATA_BITS-1:0] DMA_WrData;
    logic                      DMA_BURST_DONE, DMA_FIRST_BURST;
    logic [`AXI_ADDR_BITS-1:0] DMA_DESC_ADDR;
    logic [`AXI_ADDR_BITS-1:0] DMA_BURST_SRC;
    logic [`AXI_ADDR_BITS-1:0] DMA_BURST_DST;
    logic                      DMA_BLOCK_DONE;
    logic                      DMA_EOC;

    //====================================================
    // Finite State Machine
    //====================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) CurrentState_M2 <= IDLE;
        else     CurrentState_M2 <= NextState_M2;
    end

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        case (CurrentState_M2)
            IDLE: begin
                if (DMAEN_VALID && DMAEN)               NextState_M2 = DESCAddressPhase;
                else                                    NextState_M2 = CurrentState_M2;
            end
            DESCAddressPhase: begin
                if (ARREADY_M2 && ARVALID_M2)           NextState_M2 = ReadDESCData;
                else                                    NextState_M2 = CurrentState_M2;
            end
            ReadDESCData: begin
                if (RVALID_M2 && RREADY_M2 && RLAST_M2) NextState_M2 = TransferAdressPhase;
                else                                    NextState_M2 = CurrentState_M2;
            end
            TransferAdressPhase: begin
                if ((ARREADY_M2 | buf_ARREADY_M2) && (AWREADY_M2 | buf_AWREADY_M2))
                                                        NextState_M2 = TransferData;
                else                                    NextState_M2 = CurrentState_M2;
            end
            TransferData: begin
                if (RVALID_M2 && RREADY_M2 && RLAST_M2 && WVALID_M2 && WREADY_M2 && WLAST_M2) begin
                    if (DMA_BLOCK_DONE && DMA_EOC)      NextState_M2 = IDLE;
                    else if(DMA_BLOCK_DONE && ~DMA_EOC) NextState_M2 = DESCAddressPhase;
                    else                                NextState_M2 = TransferAdressPhase;
                end else                                NextState_M2 = CurrentState_M2;
            end
            default:                                    NextState_M2 = IDLE;
        endcase
    end

    // ============================================================
    // Channel Output Logic (combinational)
    // ============================================================
     always_comb begin
        ARID_M2    = `AXI_ID_BITS'd0;
        AWID_M2    = `AXI_ID_BITS'd0;
        ARADDR_M2  = 32'h2000_0000;
        AWADDR_M2  = 32'h0001_0000;
        ARLEN_M2   = `AXI_LEN_ONE;
        AWLEN_M2   = `AXI_LEN_ONE;
        ARSIZE_M2  = `AXI_SIZE_WORD;
        AWSIZE_M2  = `AXI_SIZE_WORD;
        ARBURST_M2 = `AXI_BURST_INC;
        AWBURST_M2 = `AXI_BURST_INC;
        ARVALID_M2 = 1'b0;
        AWVALID_M2 = 1'b0;
        WLAST_M2   = 1'b0;
        WVALID_M2  = 1'b0;
        WSTRB_M2   = `AXI_STRB_BITS'd0;
        WDATA_M2   = `AXI_DATA_BITS'd0;
        RREADY_M2  = 1'b0;
        case (CurrentState_M2)
            DESCAddressPhase: begin
                ARVALID_M2 = 1'b1;
                ARADDR_M2  = DMA_DESC_ADDR;
                ARLEN_M2   = `AXI_LEN_BITS'(5-1);
            end
            ReadDESCData: begin
                RREADY_M2 = 1'b1;
            end
            TransferAdressPhase: begin
                ARVALID_M2 = 1'b1;
                ARADDR_M2  = DMA_BURST_SRC;
                ARLEN_M2   = DMA_BURST_LEN;

                AWVALID_M2 = 1'b1;
                AWADDR_M2  = DMA_BURST_DST;
                AWLEN_M2   = DMA_BURST_LEN;
            end
            TransferData: begin
                RREADY_M2  = WREADY_M2;

                WVALID_M2  = RVALID_M2;
                WDATA_M2   = RDATA_M2;
                WSTRB_M2   = `AXI_STRB_WORD;
                WLAST_M2   = (LEN_cnt == LEN);
            end
        endcase
    end

    // Write Response
    always_ff @(posedge clk or posedge rst) begin
        if (rst) BREADY_M2 <= 1'b0;
        else     BREADY_M2 <= (WVALID_M2 && WREADY_M2 && WLAST_M2);
    end

    // ============================================================
    // Address Ready Buffer
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            buf_AWREADY_M2 <= 1'b0;
            buf_ARREADY_M2 <= 1'b0;
        end else if (CurrentState_M2 == TransferAdressPhase) begin
            buf_ARREADY_M2 <= (~buf_ARREADY_M2) ? ARREADY_M2 : buf_ARREADY_M2;
            buf_AWREADY_M2 <= (~buf_AWREADY_M2) ? AWREADY_M2 : buf_AWREADY_M2;
        end else begin
            buf_AWREADY_M2 <= 1'b0;
            buf_ARREADY_M2 <= 1'b0;
        end
    end

    // ============================================================
    // Length Storage and Counter Logic
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            LEN     <= `AXI_LEN_BITS'd0;
            LEN_cnt <= `AXI_LEN_BITS'd0;
        end else if (ARVALID_M2 && ARREADY_M2) begin
            LEN     <= ARLEN_M2;
            LEN_cnt <= `AXI_LEN_BITS'd0;
        end else if (AWVALID_M2 && AWREADY_M2) begin
            LEN     <= AWLEN_M2;
            LEN_cnt <= `AXI_LEN_BITS'd0;
        end else if ((RVALID_M2 && RREADY_M2) || (WVALID_M2 && WREADY_M2)) begin
            if (LEN_cnt == LEN) LEN_cnt <= `AXI_LEN_BITS'd0;
            else                LEN_cnt <= LEN_cnt + `AXI_LEN_BITS'd1;
        end
    end

    // ============================================================
    // DMA Interface
    // ============================================================
    always_comb begin
        DMA_BURST_DONE  = (RVALID_M2 && RREADY_M2 && RLAST_M2 && WVALID_M2 && WREADY_M2 && WLAST_M2);
        DMA_FIRST_BURST = (CurrentState_M2 == ReadDESCData) && (NextState_M2 != ReadDESCData);
        DMA_WEn     = 1'b0;
        DMA_A       = 3'd0;
        DMA_WrData  = 32'd0;
        if (WVALID_S3 && WREADY_S3 && (ADDR_S == DESC_BASE_ADDR)) begin
            DMA_WEn     = 1'b1;
            DMA_A       = 3'd5;
            DMA_WrData  = WDATA_S3;
        end else if ((CurrentState_M2 == ReadDESCData) && RVALID_M2 && RREADY_M2) begin
            DMA_WEn     = 1'b1;
            DMA_A       = LEN_cnt;
            DMA_WrData  = RDATA_M2;
        end
    end


DMA dma (
    .clk            (clk               ),
    .rst            (rst               ),

    .En_VALID       (DMAEN_VALID       ),
    .En             (DMAEN             ),
    .WEn            (DMA_WEn           ),
    .A              (DMA_A             ),
    .DI             (DMA_WrData        ),
    .BURST_DONE     (DMA_BURST_DONE    ),
    .FIRST_BURST    (DMA_FIRST_BURST   ),

    .DESC_ADDR      (DMA_DESC_ADDR     ),
    .BURST_SRC      (DMA_BURST_SRC     ),
    .BURST_DST      (DMA_BURST_DST     ),
    .BURST_LEN      (DMA_BURST_LEN     ),

    .BLOCK_DONE     (DMA_BLOCK_DONE    ),
    .EOC            (DMA_EOC           ),
    .DMA_interrupt  (DMA_interrupt     )
);

endmodule
