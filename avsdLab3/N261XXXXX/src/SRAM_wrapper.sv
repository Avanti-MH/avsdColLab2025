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

	// ============================================================
	// Local signals and parameters
	// ============================================================
	typedef enum logic [1:0] {
		ACCEPT        = 2'd0,
		ReadData      = 2'd1,
		WriteData     = 2'd2,
		WriteResponse = 2'd3
	} trans_state_t;


	trans_state_t 				CurrentState, NextState;
	logic [`AXI_IDS_BITS-1:0] 	AWID, ARID;
	logic [`AXI_ADDR_BITS-1:0] 	RWADDR, A_tmp;
	logic [`AXI_LEN_BITS-1:0] 	RWLEN;
	logic [`AXI_SIZE_BITS-1:0]  RWSIZE;
	logic [1:0] 				RWBURST;
	logic [`AXI_LEN_BITS-1:0]   RWcount;
	logic [`AXI_DATA_BITS-1:0]  ReadBuffer;
	logic 						Waiting, RAddrLAST;
	logic 						CEB, WEB;
	logic [`AXI_DATA_BITS-1:0]  BWEB;
	logic [`AXI_DATA_BITS-1:0] 	DI, DO;
	logic [13:0] 				A;

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
            if (ARVALID_S)          	  NextState = ReadData;
            else if (AWVALID_S)     	  NextState = WriteData;
            else                          NextState = ACCEPT;
        end
        ReadData: begin
            if (RVALID_S && RREADY_S && RLAST_S)
                                          NextState = ACCEPT;
            else                          NextState = CurrentState;
        end
        WriteData: begin
            if (WVALID_S && WREADY_S && WLAST_S)
                                          NextState = WriteResponse;
            else                          NextState = CurrentState;
        end
        WriteResponse: begin
            if(BVALID_S && BREADY_S)
                                          NextState = ACCEPT;
            else                          NextState = CurrentState;
        end
        endcase
    end

	// ============================================================
	// Address calculation logic
	// ============================================================
	always_comb begin
		if ((CurrentState == ACCEPT) && ARVALID_S)
			A_tmp = (ARADDR_S) >> 2;
		else
			A_tmp = {1'b0, (RWADDR[31:2] + {26'd0, RWcount})};

		A = A_tmp[13:0];
	end
	// ============================================================
	// Channel logic
	// ============================================================

	// ---------------------------------------
    // ACCEPT
    // ---------------------------------------
    assign ARREADY_S = (CurrentState == ACCEPT);
    assign AWREADY_S = (CurrentState == ACCEPT);

	// ---------------------------------------
    // ReadData
    // ---------------------------------------
	always_comb begin
		if (CurrentState == ReadData) begin
			RID_S 		= ARID;
			RDATA_S 	= (Waiting) ? ReadBuffer : DO;
			RRESP_S 	= `AXI_RESP_OKAY;
			RVALID_S 	= 1'b1;
			RLAST_S 	= RAddrLAST;
		end
		else begin
			RID_S 		= `AXI_IDS_BITS'd0;
			RDATA_S 	= `AXI_DATA_BITS'd0;
			RRESP_S 	= `AXI_RESP_DECERR;
			RVALID_S	= 1'b0;
			RLAST_S 	= 1'b0;
		end
	end

	// ---------------------------------------
    // WriteData
    // ---------------------------------------
	always_comb begin
		if (CurrentState == WriteData) begin
			WREADY_S 	= 1'b1;
			DI 			= WDATA_S;
			BWEB 		= {{8{~WSTRB_S[3]}}, {8{~WSTRB_S[2]}}, {8{~WSTRB_S[1]}}, {8{~WSTRB_S[0]}}};
			WEB 		= 1'b0;
		end
		else begin
			WREADY_S 	= 1'b0;
			DI 			= 32'd0;
			BWEB 		= 32'hFFFF_FFFF;
			WEB 		= 1'b1;
		end
	end

	// ---------------------------------------
    // WriteResponse
    // ---------------------------------------
	always_comb begin
		if (CurrentState == WriteResponse) begin
			BID_S 		= AWID;
			BVALID_S 	= 1'b1;
			BRESP_S 	= `AXI_RESP_OKAY;
		end
		else begin
			BID_S 		= `AXI_IDS_BITS'd0;
			BVALID_S 	= 1'b0;
			BRESP_S 	= `AXI_RESP_DECERR;
		end
	end

	// ============================================================
	// Sequential storage logic
	// ============================================================
	always_ff @( posedge ACLK or negedge ARESETn ) begin
		if (~ARESETn) begin
			ARID 	<= `AXI_IDS_BITS'd0;
            AWID 	<= `AXI_IDS_BITS'd0;
            RWADDR 	<= `AXI_ADDR_BITS'd0;
            RWLEN 	<= `AXI_LEN_BITS'd0;
            RWSIZE 	<= `AXI_SIZE_BITS'd0;
            RWBURST <= 2'd0;
		end
		else begin
			if ((CurrentState == ACCEPT) && ARVALID_S) begin
				ARID  	<= ARID_S;
				RWADDR 	<= ARADDR_S;
				RWLEN 	<= ARLEN_S;
				RWSIZE 	<= ARSIZE_S;
				RWBURST <= ARBURST_S;
			end
			else if ((CurrentState == ACCEPT) && AWVALID_S) begin
				AWID  	<= AWID_S;
				RWADDR 	<= AWADDR_S;
				RWLEN 	<= AWLEN_S;
				RWSIZE 	<= AWSIZE_S;
				RWBURST <= AWBURST_S;
			end
		end
	end

	// ============================================================
	// Counter logic
	// ============================================================
	always_ff @(posedge ACLK or negedge ARESETn) begin // RWcount
		if (!ARESETn) begin
			RWcount   <= `AXI_LEN_BITS'd0;
			RAddrLAST <= 1'b0;
		end
		else begin
			// ------------------------------------------------
			// Case 1: Data transfer (read or write in progress)
			// ------------------------------------------------
			if ((RVALID_S && RREADY_S) || (WVALID_S && WREADY_S)) begin
				if ((RWcount == RWLEN) || RAddrLAST) begin
					RWcount   <= `AXI_LEN_BITS'd0;
					RAddrLAST <= 1'b1;
				end
				else begin
					RWcount   <= RWcount + `AXI_LEN_BITS'd1;
					RAddrLAST <= 1'b0;
				end
			end

			// ------------------------------------------------
			// Case 2: Idle state receiving new read request
			// ------------------------------------------------
			else if ((CurrentState == ACCEPT) && ARVALID_S) begin
				if (RWcount == ARLEN_S) begin
					RWcount   <= `AXI_LEN_BITS'd0;
					RAddrLAST <= 1'b1;
				end
				else begin
					RWcount   <= RWcount + `AXI_LEN_BITS'd1;
					RAddrLAST <= 1'b0;
				end
			end
		end
	end


	always_ff @( posedge ACLK or negedge ARESETn ) begin // Waiting
		if (!ARESETn) Waiting <= 1'b0;
		else begin
			if ((CurrentState == ReadData) && ~RREADY_S)
				  Waiting <= 1'b1;
			else  Waiting <= 1'b0;
		end
	end

	always_ff @( posedge ACLK or negedge ARESETn ) begin // ReadBuffer
		if (!ARESETn) ReadBuffer <= `AXI_DATA_BITS'd0;
		else begin
			if ((CurrentState == ReadData) && Waiting)
				  ReadBuffer <= ReadBuffer;
			else  ReadBuffer <= DO;
		end
	end

	always_ff @( posedge ACLK or negedge ARESETn ) begin // CurrentState NextState
		if (~ARESETn) CEB <= 1'b0;
	end

TS1N16ADFPCLLLVTA512X45M4SWSHOD i_SRAM (
    .SLP(1'b0),
    .DSLP(1'b0),
    .SD(1'b0),
    .PUDELAY(),
    .CLK(ACLK),
	.CEB(CEB),
	.WEB(WEB),
    .A(A),
	.D(DI),
    .BWEB(BWEB),
    .RTSEL(2'b01),
    .WTSEL(2'b01),
    .Q(DO)
);


endmodule
