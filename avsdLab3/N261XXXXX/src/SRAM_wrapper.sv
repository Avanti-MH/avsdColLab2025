`include "../include/AXI_define.svh"

module SRAM_wrapper(

  	input  logic                            ACLK,
    input  logic                            ARESETn,

    // ReadAddress
    input  logic [`AXI_IDS_BITS-1:0]        ARID_S,
    input  logic [`AXI_ADDR_BITS-1:0]       ARADDR_S,
    input  logic [`AXI_LEN_BITS-1:0]        ARLEN_S,
    input  logic [`AXI_SIZE_BITS-1:0]       ARSIZE_S,
    input  logic [1:0]                      ARBURST_S,
    input  logic                            ARVALID_S,
    output logic                            ARREADY_S,

    // ReadData
    output logic [`AXI_IDS_BITS-1:0]        RID_S,
    output logic [`AXI_DATA_BITS-1:0]       RDATA_S,
    output logic [1:0]                      RRESP_S,
    output logic                            RLAST_S,
    output logic                            RVALID_S,
    input  logic                            RREADY_S,

    // WriteAddress
    input  logic [`AXI_IDS_BITS-1:0]        AWID_S,
    input  logic [`AXI_ADDR_BITS-1:0]       AWADDR_S,
    input  logic [`AXI_LEN_BITS-1:0]        AWLEN_S,
    input  logic [`AXI_SIZE_BITS-1:0]       AWSIZE_S,
    input  logic [1:0]                      AWBURST_S,
    input  logic                            AWVALID_S,
    output logic                            AWREADY_S,

    // WriteData
    input  logic [`AXI_DATA_BITS-1:0]       WDATA_S,
    input  logic [`AXI_STRB_BITS-1:0]       WSTRB_S,
    input  logic                            WLAST_S,
    input  logic                            WVALID_S,
    output logic                            WREADY_S,

    // WriteResponse
    output logic [`AXI_IDS_BITS-1:0]        BID_S,
    output logic [1:0]                      BRESP_S,
    output logic                            BVALID_S,
    input  logic                            BREADY_S
);

	//====================================================
    // State Definition
    //====================================================
	typedef enum logic [1:0] {
		ACCEPT        = 2'd0,
		ReadData      = 2'd1,
		WriteData     = 2'd2,
		WriteResponse = 2'd3
	} state_t;

	state_t CurrentState, NextState;

	//====================================================
    // Local Signals and Registers
    //====================================================
	logic [`AXI_IDS_BITS-1:0] 	AWID, ARID;
	logic [`AXI_LEN_BITS-1:0] 	LEN;
	logic [`AXI_LEN_BITS-1:0]   LEN_cnt;
	logic [`AXI_ADDR_BITS-1:0] 	ADDR;

	logic 						buf_VALID;
	logic [`AXI_DATA_BITS-1:0]  buf_SRAM_Q;

	logic 						SRAM_CEBn, SRAM_WEBn;
	logic [`AXI_DATA_BITS-1:0]  SRAM_BWEBn;
	logic [13:0] 				SRAM_A;
	logic [`AXI_DATA_BITS-1:0] 	SRAM_D, SRAM_Q;

	// ============================================================
	// Finite State Machine
	// ============================================================

	// ---------------------------------------
    // State register
    // ---------------------------------------
	always_ff @( posedge ACLK or negedge ARESETn ) begin // CurrentState NextState
		if (~ARESETn) CurrentState <= ACCEPT;
		else 	  	  CurrentState <= NextState;
	end

	// ---------------------------------------
    // Next state logic
    // ---------------------------------------
	always_comb begin
        case(CurrentState)
        ACCEPT: begin
            if (ARVALID_S)      NextState = ReadData;
            else if (AWVALID_S) NextState = WriteData;
            else                NextState = ACCEPT;
        end
        ReadData: begin
            if (RVALID_S && RREADY_S && RLAST_S)
                                NextState = ACCEPT;
            else                NextState = CurrentState;
        end
        WriteData: begin
            if (WVALID_S && WREADY_S && WLAST_S)
                                NextState = WriteResponse;
            else                NextState = CurrentState;
        end
        WriteResponse: begin
            if(BVALID_S && BREADY_S)
                                NextState = ACCEPT;
            else                NextState = CurrentState;
        end
        endcase
    end

	// ============================================================
    // Channel Output Logic (combinational)
    // ============================================================
	always_comb begin
		ARREADY_S   = 1'b0;
		AWREADY_S   = 1'b0;
		RID_S       = `AXI_IDS_BITS'd0;
		RDATA_S     = `AXI_DATA_BITS'd0;
		RRESP_S     = `AXI_RESP_DECERR;
		RVALID_S    = 1'b0;
		RLAST_S     = 1'b0;
		WREADY_S    = 1'b0;
		BID_S       = `AXI_IDS_BITS'd0;
		BVALID_S    = 1'b0;
		BRESP_S     = `AXI_RESP_DECERR;
		case (CurrentState)
			ACCEPT: begin
				ARREADY_S = 1'b1;
				AWREADY_S = 1'b1;
			end
			ReadData: begin
				RID_S     = ARID;
				RDATA_S   = (buf_VALID) ? buf_SRAM_Q : SRAM_Q;
				RRESP_S   = `AXI_RESP_OKAY;
				RVALID_S  = 1'b1;
				RLAST_S   = (LEN_cnt == LEN);
			end
			WriteData: begin
				WREADY_S  = 1'b1;
			end
			WriteResponse: begin
				BID_S     = AWID;
				BVALID_S  = 1'b1;
				BRESP_S   = `AXI_RESP_OKAY;
			end
		endcase
	end

	// ============================================================
	// Request Information Storage
	// ============================================================
	always_ff @( posedge ACLK or negedge ARESETn ) begin
		if (~ARESETn) begin
			ARID <= `AXI_IDS_BITS'd0;
			AWID <= `AXI_IDS_BITS'd0;
			ADDR <= `AXI_ADDR_BITS'd0;
			LEN  <= `AXI_LEN_BITS'd0;
		end else if(CurrentState == ACCEPT)begin
			ARID <= (ARVALID_S) ? ARID_S  : ARID;
			AWID <= (AWVALID_S) ? AWID_S  : AWID;
			LEN  <= (ARVALID_S) ? ARLEN_S : (AWVALID_S ? AWLEN_S  : LEN);
			ADDR <= (ARVALID_S) ? ARADDR_S: (AWVALID_S ? AWADDR_S : ADDR);
		end
	end

	// ============================================================
	// Counter logic
	// ============================================================
	always_ff @(posedge ACLK or negedge ARESETn) begin
		if (~ARESETn) begin
			LEN_cnt <= `AXI_LEN_BITS'd0;
		end else if ((RVALID_S && RREADY_S) || (WVALID_S && WREADY_S)) begin
			LEN_cnt <= (LEN_cnt == LEN) ? `AXI_LEN_BITS'd0 : LEN_cnt + `AXI_LEN_BITS'd1;
		end
	end

	// ============================================================
	// Buffer for ReadData
	// ============================================================
	always_ff @( posedge ACLK or negedge ARESETn ) begin // Pending
		if (~ARESETn) begin
			buf_VALID  <= 1'b0;
			buf_SRAM_Q <= `AXI_DATA_BITS'b0;
		end else if (RVALID_S && ~RREADY_S) begin
			buf_VALID  <= 1'b1;
			buf_SRAM_Q <= SRAM_Q;
		end else if (RVALID_S && RREADY_S) begin
			buf_VALID  <= 1'b0;
			buf_SRAM_Q <= `AXI_DATA_BITS'b0;
		end
	end
	// ============================================================
	// SRAM Interface
	// ============================================================
	always_comb begin
		SRAM_CEBn  = 1'b0;
		SRAM_WEBn  = 1'b1;
		SRAM_BWEBn = 32'hFFFF_FFFF;
		SRAM_D     = 32'd0;
		SRAM_A     = 14'd0;
		case (CurrentState)
            ACCEPT:
                SRAM_A 	   = ARVALID_S ? ARADDR_S[15:2] : 14'd0;
            ReadData:
                SRAM_A 	   = ADDR[15:2] + {10'd0, LEN_cnt + `AXI_LEN_BITS'd1};
            WriteData : begin
				SRAM_WEBn  = 1'b0;
                SRAM_BWEBn = {{8{~WSTRB_S[3]}}, {8{~WSTRB_S[2]}}, {8{~WSTRB_S[1]}}, {8{~WSTRB_S[0]}}};
				SRAM_A	   = ADDR[15:2] + {10'd0, LEN_cnt};
				SRAM_D     = WDATA_S;
            end
        endcase
    end

TS1N16ADFPCLLLVTA512X45M4SWSHOD i_SRAM (
    .SLP		(1'b0		),
    .DSLP		(1'b0		),
    .SD			(1'b0		),
    .PUDELAY	(			),
    .CLK		(ACLK		),
	.CEB		(SRAM_CEBn	),
	.WEB		(SRAM_WEBn	),
    .A			(SRAM_A		),
	.D			(SRAM_D		),
    .BWEB		(SRAM_BWEBn	),
    .RTSEL		(2'b01		),
    .WTSEL		(2'b01		),
    .Q			(SRAM_Q		)
);


endmodule
