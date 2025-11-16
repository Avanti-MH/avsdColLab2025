module DefaultSlave(
    input  logic                            clk,
    input  logic                            rst,

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
	logic [`AXI_LEN_BITS-1:0] 	LEN, LEN_cnt;

    // ============================================================
	// Finite State Machine
	// ============================================================

	// ---------------------------------------
    // State Register
    // ---------------------------------------
	always_ff @( posedge clk or posedge rst ) begin
		if (rst) CurrentState <= ACCEPT;
		else 	 CurrentState <= NextState;
	end

	// ---------------------------------------
    // Next State Logic
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
				RVALID_S  = 1'b1;
				RLAST_S   = (LEN_cnt == LEN);
			end
			WriteData: begin
				WREADY_S  = 1'b1;
			end
			WriteResponse: begin
				BID_S     = AWID;
				BVALID_S  = 1'b1;
			end
		endcase
	end

    // ============================================================
	// Request Information Storage
	// ============================================================
	always_ff @( posedge clk or posedge rst ) begin
		if (rst) begin
			ARID <= `AXI_IDS_BITS'd0;
			AWID <= `AXI_IDS_BITS'd0;
			LEN  <= `AXI_LEN_BITS'd0;
		end else if(CurrentState == ACCEPT)begin
			ARID <= (ARVALID_S) ? ARID_S  : ARID;
			AWID <= (AWVALID_S) ? AWID_S  : AWID;
			LEN  <= (ARVALID_S) ? ARLEN_S : (AWVALID_S ? AWLEN_S  : LEN);
		end
	end

    // ============================================================
	// Counter logic
	// ============================================================
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			LEN_cnt <= `AXI_LEN_BITS'd0;
		end else if ((RVALID_S && RREADY_S) || (WVALID_S && WREADY_S)) begin
			LEN_cnt <= (LEN_cnt == LEN) ? `AXI_LEN_BITS'd0 : LEN_cnt + `AXI_LEN_BITS'd1;
		end
	end


endmodule