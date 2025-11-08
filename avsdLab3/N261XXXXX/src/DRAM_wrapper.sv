`include "../include/AXI_define.svh"

module DRAM_wrapper (

    input   clk,
    input   rst,

    // Read Address
    input           [`AXI_IDS_BITS-1:0 ]    ARID_S,
    input           [`AXI_ADDR_BITS-1:0]    ARADDR_S,
    input           [`AXI_LEN_BITS-1:0 ]    ARLEN_S,
    input           [`AXI_SIZE_BITS-1:0]    ARSIZE_S,
    input           [1:0               ]    ARBURST_S,
    input                                   ARVALID_S,
    output  logic                           ARREADY_S,

    // Read Data
    output  logic   [`AXI_IDS_BITS-1:0 ]    RID_S,
    output  logic   [`AXI_DATA_BITS-1:0]    RDATA_S,
    output  logic   [1:0               ]    RRESP_S,
    output  logic                           RLAST_S,
    output  logic                           RVALID_S,
    input                                   RREADY_S,

    // Write Address
    input           [`AXI_IDS_BITS-1:0 ]    AWID_S,
    input           [`AXI_ADDR_BITS-1:0]    AWADDR_S,
    input           [`AXI_LEN_BITS-1:0 ]    AWLEN_S,
    input           [`AXI_SIZE_BITS-1:0]    AWSIZE_S,
    input           [1:0               ]    AWBURST_S,
    input                                   AWVALID_S,
    output  logic                           AWREADY_S,

    // Write Data
    input           [`AXI_DATA_BITS-1:0]    WDATA_S,
    input           [`AXI_STRB_BITS-1:0]    WSTRB_S,
    input                                   WLAST_S,
    input                                   WVALID_S,
    output  logic                           WREADY_S,

    // Write Response
    output  logic   [`AXI_IDS_BITS-1:0 ]    BID_S,
    output  logic   [1:0               ]    BRESP_S,
    output  logic                           BVALID_S,
    input                                   BREADY_S,

    // DRAM Interface
    output  logic                           DRAM_CSn,
    output  logic   [`AXI_STRB_BITS-1:0]    DRAM_WEn,
    output  logic                           DRAM_RASn,
    output  logic                           DRAM_CASn,
    output  logic   [10:0]                  DRAM_A,
    output  logic   [`AXI_DATA_BITS-1:0]    DRAM_D,
    input           [`AXI_DATA_BITS-1:0]    DRAM_Q,
    input                                   DRAM_valid
);

    //====================================================
    // State Definition
    //====================================================
    typedef enum logic [2:0] {
        RowActivation = 3'd0,
        ReadColumn    = 3'd1,
        WriteColumn   = 3'd2,
        WriteResponse = 3'd3,
        RowHit        = 3'd4,
        PreCharge     = 3'd5
    } state_t;

    state_t CurrentState, NextState;

    //====================================================
    // Local Signals and Registers
    //====================================================
    logic [2:0]                DLY_cnt;

    logic [`AXI_IDS_BITS-1:0 ] ARID, AWID;
    logic [`AXI_LEN_BITS-1:0 ] LEN;
    logic [`AXI_LEN_BITS-1:0 ] LEN_cnt;
    logic [`AXI_ADDR_BITS-1:0] ADDR;

    logic                      buf_RVALID;
    logic [`AXI_DATA_BITS-1:0] buf_DRAM_Q;
    logic                      Rd, Wr, HitRow;

    //====================================================
    // Finite State Machine
    //====================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if(rst) CurrentState <= RowActivation;
        else    CurrentState <= NextState;
    end

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        case (CurrentState)
            RowActivation: begin
                if      (Rd && DLY_cnt == 3'd4)    NextState = ReadColumn;
                else if (Wr && DLY_cnt == 3'd4)    NextState = WriteColumn;
                else                               NextState = RowActivation;
            end
            ReadColumn: begin
                if (RREADY_S & RVALID_S & RLAST_S) NextState = RowHit;
                else                               NextState = ReadColumn;
            end
            WriteColumn: begin
                if (WREADY_S & WVALID_S & WLAST_S) NextState = WriteResponse;
                else                               NextState = WriteColumn;
            end
            WriteResponse: begin
                if (BREADY_S & BVALID_S)           NextState = RowHit;
                else                               NextState = WriteResponse;
            end
            RowHit: begin
                if      (ARVALID_S && HitRow)      NextState = ReadColumn;
                else if (AWVALID_S && HitRow)      NextState = WriteColumn;
                else if (ARVALID_S && ~HitRow)     NextState = PreCharge;
                else if (AWVALID_S && ~HitRow)     NextState = PreCharge;
                else                               NextState = RowHit;
            end
            PreCharge: begin
                if (DLY_cnt == 3'd4)               NextState = RowActivation;
                else                               NextState = PreCharge;
            end
            default:                               NextState = RowActivation;
        endcase
    end

    // ============================================================
    // Channel Output Logic (combinational)
    // ============================================================
    always_comb begin
        ARREADY_S = 1'b0;
        AWREADY_S = 1'b0;
        RID_S     = `AXI_IDS_BITS'b0;
        RDATA_S   = `AXI_DATA_BITS'b0;
        RRESP_S   = `AXI_RESP_DECERR;
        RLAST_S   = 1'b0;
        RVALID_S  = 1'b0;
        WREADY_S  = 1'b0;
        BID_S     = `AXI_IDS_BITS'b0;
        BVALID_S  = 1'b0;
        BRESP_S   = `AXI_RESP_DECERR;

        case(CurrentState)
            RowActivation:begin
                ARREADY_S = (DLY_cnt == 3'd0);
                AWREADY_S = (DLY_cnt == 3'd0);
            end
            ReadColumn:begin
                RID_S     = ARID;
                RDATA_S   = (buf_RVALID) ? buf_DRAM_Q : DRAM_Q;
                RRESP_S   = `AXI_RESP_OKAY;
                RLAST_S   = (LEN_cnt == LEN && DLY_cnt == 3'd5);
                RVALID_S  = (DRAM_valid | buf_RVALID);
            end
            WriteColumn:begin
                WREADY_S = (DLY_cnt == 3'd4)
            end
            WriteResponse:begin
                BID_S = AWID;
                BVALID_S = 1'b1;
                BRESP_S = `AXI_RESP_OKAY;
            end
            RowHit:begin
                ARREADY_S = HitRow;
                AWREADY_S = HitRow;
            end
            default:begin
            end
        endcase
    end

    // ============================================================
	// Request Information Storage
	// ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            ARID <= `AXI_IDS_BITS'b0;
            AWID <= `AXI_IDS_BITS'b0;
            ADDR <= `AXI_ADDR_BITS'b0;
            LEN  <= `AXI_LEN_BITS'b0;
        end else if(CurrentState == RowActivation)begin
            ARID <= (ARVALID_S) ? ARID_S  : ARID;
            AWID <= (AWVALID_S) ? AWID_S  : AWID;
            LEN  <= (ARVALID_S) ? ARLEN_S : (AWVALID_S ? AWLEN_S  : LEN);
            ADDR <= (ARVALID_S) ? ARADDR_S: (AWVALID_S ? AWADDR_S : ADDR);
        end else if(CurrentState == RowHit)begin
            ARID <= (ARVALID_S && HitRow) ? ARID_S  : ARID;
            AWID <= (AWVALID_S && HitRow) ? AWID_S  : AWID;
            LEN  <= (ARVALID_S && HitRow) ? ARLEN_S : (AWVALID_S && HitRow ? AWLEN_S  : LEN);
            ADDR <= (ARVALID_S && HitRow) ? ARADDR_S: (AWVALID_S && HitRow ? AWADDR_S : ADDR);
        end
    end

    // ============================================================
	// Read / Write Request Storage
	// ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            Rd <= 1'b0;
            Wr <= 1'b0;
        end else if ((CurrentState == RowActivation) && (ARVALID_S | AWVALID_S)) begin
            Rd <= ARVALID_S;
            Wr <= AWVALID_S;
        end
    end
    // ============================================================
	// Row Hit Logic
	// ============================================================
    always_comb begin
        if (CurrentState == RowHit)begin
            if      (ARVALID_S && (ARADDR_S[22:12] == ADDR[22:12])) HitRow = 1'b1;
            else if (AWVALID_S && (AWADDR_S[22:12] == ADDR[22:12])) HitRow = 1'b1;
            else                                                    HitRow = 1'b0;
        end else                                                    HitRow = 1'b0;
    end

    // ============================================================
	// Burst Length Counter
	// ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            LEN_cnt <= `AXI_LEN_BITS'd0;
        else if ((RREADY_S & RVALID_S) || (WREADY_S & WVALID_S)) begin
            LEN_cnt <= (LEN_cnt == LEN) ? `AXI_LEN_BITS'd0 : LEN_cnt + `AXI_LEN_BITS'd1;
        end
    end

    // ============================================================
    // Delay Counter
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            DLY_cnt <= 3'd0;
        end else begin
            case (CurrentState)
                RowActivation: begin
                    if      (DLY_cnt == 3'd4)        DLY_cnt <= 3'd0;
                    else if (DLY_cnt > 3'd0)         DLY_cnt <= DLY_cnt + 3'd1;
                    else if (ARVALID_S | AWVALID_S)  DLY_cnt <= 3'd1;
                end
                ReadColumn: begin
                    if (DLY_cnt == 3'd5 && RREADY_S) DLY_cnt <= 3'd0; // When DLY_cnt = 5, ReadData is valid
                    else if (DLY_cnt == 3'd5)        DLY_cnt <= DLY_cnt;
                    else                             DLY_cnt <= DLY_cnt + 3'd1;
                end
                WriteColumn: begin
                    if (DLY_cnt == 3'd4 && WVALID_S) DLY_cnt <= 3'd0; // When DLY_cnt = 4, DRAM is ready to write
                    else                             DLY_cnt <= DLY_cnt + 3'd1;
                end
                RowHit: begin
                    if((ARVALID_S | AWVALID_S) && HitRow)
                                                     DLY_cnt <= DLY_cnt + 3'd1;
                end
                PreCharge: begin
                    if (DLY_cnt == 3'd4)             DLY_cnt <= 3'd0;
                    else                             DLY_cnt <= DLY_cnt + 3'd1;
                end
                default:                             DLY_cnt <= DLY_cnt;
            endcase
        end
    end
    // ============================================================
	// Buffer for ReadData
	// ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            buf_RVALID <= 1'b0;
            buf_DRAM_Q <= `AXI_DATA_BITS'b0;
        end else if (RVALID_S && ~RREADY_S) begin   // Not immediate handshake
            buf_RVALID <= RVALID_S;
            buf_DRAM_Q <= DRAM_Q;
        end else if (buf_RVALID && RREADY_S) begin  // handshake->reset
            buf_RVALID <= 1'b0;
            buf_DRAM_Q <= `AXI_DATA_BITS'b0;
        end
    end
    // ============================================================
	// DRAM Interface
	// ============================================================


    always_comb begin
        case (CurrentState)
            RowActivation: begin
                DRAM_CSn  = 1'b0;
                DRAM_RASn = ((DLY_cnt == 3'd0) && (ARVALID_S | AWVALID_S));
                DRAM_CASn = 1'b1;
                DRAM_WEn  = {`AXI_STRB_BITS{1'b1}};
                DRAM_A    = (ARVALID_S) ? ARADDR_S[22:12]: (AWVALID_S ? AWADDR_S[22:12] : ADDR[22:12]);
                DRAM_D    = `AXI_DATA_BITS'd0;
            end
            ReadColumn: begin
                DRAM_CSn  = 1'b0;
                DRAM_RASn = 1'b1;
                DRAM_CASn = (DLY_cnt != 3'd0);
                DRAM_WEn  = `AXI_STRB_BITS'd0;
                DRAM_A    = {1'b0, ADDR[11:2]} + {7'd0, LEN_cnt};
                DRAM_D    = `AXI_DATA_BITS'd0;
            end
            WriteColumn: begin
                DRAM_CSn  = 1'b0;
                DRAM_RASn = 1'b1;
                DRAM_CASn = (DLY_cnt != 3'd0);
                DRAM_WEn  = WSTRB_S;
                DRAM_A    = {1'b0, ADDR[11:2]} + {7'd0, LEN_cnt};
                DRAM_D    = WDATA_S;
            end
            PreCharge: begin
                DRAM_CSn  = 1'b0;
                DRAM_RASn = 1'b0;
                DRAM_CASn = 1'b1;
                DRAM_WEn  = `AXI_STRB_BITS'd0;
                DRAM_A    = 11'd0;
                DRAM_D    = `AXI_DATA_BITS'd0;
            end
            default: begin
                DRAM_CSn  = 1'b1;
                DRAM_RASn = 1'b1;
                DRAM_CASn = 1'b1;
                DRAM_WEn  = {`AXI_STRB_BITS{1'b1}};
                DRAM_A    = 11'd0;
                DRAM_D    = `AXI_DATA_BITS'd0;
            end
        endcase
    end

endmodule