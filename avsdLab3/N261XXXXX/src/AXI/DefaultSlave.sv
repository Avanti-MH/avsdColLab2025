module DefaultSlave(
    input  logic                            clk,
    input  logic                            rst,

    // ReadAddress
    input  logic [`AXI_IDS_BITS-1:0]        ARID_DEFAULT,
    input  logic [`AXI_ADDR_BITS-1:0]       ARADDR_DEFAULT,
    input  logic [`AXI_LEN_BITS-1:0]        ARLEN_DEFAULT,
    input  logic [`AXI_SIZE_BITS-1:0]       ARSIZE_DEFAULT,
    input  logic [1:0]                      ARBURST_DEFAULT,
    input  logic                            ARVALID_DEFAULT,
    output logic                            ARREADY_DEFAULT,

    // ReadData
    output logic [`AXI_IDS_BITS-1:0]        RID_DEFAULT,
    output logic [`AXI_DATA_BITS-1:0]       RDATA_DEFAULT,
    output logic [1:0]                      RRESP_DEFAULT,
    output logic                            RLAST_DEFAULT,
    output logic                            RVALID_DEFAULT,
    input  logic                            RREADY_DEFAULT,

    // WriteAddress
    input  logic [`AXI_IDS_BITS-1:0]        AWID_DEFAULT,
    input  logic [`AXI_ADDR_BITS-1:0]       AWADDR_DEFAULT,
    input  logic [`AXI_LEN_BITS-1:0]        AWLEN_DEFAULT,
    input  logic [`AXI_SIZE_BITS-1:0]       AWSIZE_DEFAULT,
    input  logic [1:0]                      AWBURST_DEFAULT,
    input  logic                            AWVALID_DEFAULT,
    output logic                            AWREADY_DEFAULT,

    // WriteData
    input  logic [`AXI_DATA_BITS-1:0]       WDATA_DEFAULT,
    input  logic [`AXI_STRB_BITS-1:0]       WSTRB_DEFAULT,
    input  logic                            WLAST_DEFAULT,
    input  logic                            WVALID_DEFAULT,
    output logic                            WREADY_DEFAULT,

    // WriteResponse
    output logic [`AXI_IDS_BITS-1:0]        BID_DEFAULT,
    output logic [1:0]                      BRESP_DEFAULT,
    output logic                            BVALID_DEFAULT,
    input  logic                            BREADY_DEFAULT
);

// ============================================================
// Local signals and parameters
// ============================================================
    logic [1:0] 				CurrentState, NextState;
    logic [`AXI_IDS_BITS-1:0] 	AWID, ARID;
    logic [`AXI_ADDR_BITS-1:0] 	RWADDR;
    logic [`AXI_LEN_BITS-1:0] 	RWLEN;
    logic [`AXI_SIZE_BITS-1:0] 	RWSIZE;
    logic [1:0] 				RWBURST;
    logic [`AXI_LEN_BITS-1:0] 	RWcount;
    logic 						RAddrLAST;

    localparam  IDLE            = 2'd0,
                ReadData        = 2'd1,
                WriteData       = 2'd2,
                WriteResponse   = 2'd3;

// ============================================================
// Finite State Machine
// ============================================================

    // ---------------------------------------
    // State register
    // ---------------------------------------
    always_ff @( posedge clk or negedge rst ) begin
        if (~rst) CurrentState <= IDLE;
        else      CurrentState <= NextState;
    end

    // ---------------------------------------
    // Next state logic
    // ---------------------------------------
    always_comb begin
        case(CurrentState)
        IDLE: begin
            if (ARVALID_DEFAULT)          NextState = ReadData;
            else if (AWVALID_DEFAULT)     NextState = WriteData;
            else                          NextState = IDLE;
        end
        ReadData: begin
            if (RVALID_DEFAULT && RREADY_DEFAULT && RLAST_DEFAULT)
                                          NextState = IDLE;
            else                          NextState = CurrentState;
        end
        WriteData: begin
            if (WVALID_DEFAULT && WREADY_DEFAULT && WLAST_DEFAULT)
                                          NextState = WriteResponse;
            else                          NextState = CurrentState;
        end
        WriteResponse: begin
            if(BVALID_DEFAULT && BREADY_DEFAULT)
                                          NextState = IDLE;
            else                          NextState = CurrentState;
        end
        endcase
    end

// ============================================================
// Channel logic
// ============================================================

    // ---------------------------------------
    // IDLE
    // ---------------------------------------
    assign ARREADY_DEFAULT = (CurrentState == IDLE);
    assign AWREADY_DEFAULT = (CurrentState == IDLE);

    // ---------------------------------------
    // ReadData
    // ---------------------------------------
    always_comb begin
        if (CurrentState == ReadData) begin
            RID_DEFAULT 	= ARID;
            RDATA_DEFAULT 	= `AXI_DATA_BITS'd0;
            RRESP_DEFAULT 	= 2'b11;
            RVALID_DEFAULT 	= 1'b1;
            RLAST_DEFAULT 	= RAddrLAST;
        end
        else begin
            RID_DEFAULT 	= `AXI_IDS_BITS'd0;
            RDATA_DEFAULT 	= `AXI_DATA_BITS'd0;
            RRESP_DEFAULT 	= 2'b11;
            RVALID_DEFAULT 	= 1'b0;
            RLAST_DEFAULT 	= 1'b0;
        end
    end

    // ---------------------------------------
    // WriteData
    // ---------------------------------------
    assign WREADY_DEFAULT = (CurrentState == WriteData);

    // ---------------------------------------
    // WriteResponse
    // ---------------------------------------
    always_comb begin
        if (CurrentState == WriteResponse) begin
            BID_DEFAULT 	= AWID;
            BVALID_DEFAULT 	= 1'b1;
            BRESP_DEFAULT 	= 2'b11;
        end
        else begin
            BID_DEFAULT 	= `AXI_IDS_BITS'd0;
            BVALID_DEFAULT 	= 1'b0;
            BRESP_DEFAULT 	= 2'b00;
        end
    end

// ============================================================
// Sequential storage logic
// ============================================================
    always_ff @( posedge clk or negedge rst ) begin
        if (~rst) begin
            ARID 	<= `AXI_IDS_BITS'd0;
            AWID 	<= `AXI_IDS_BITS'd0;
            RWADDR 	<= `AXI_ADDR_BITS'd0;
            RWLEN 	<= `AXI_LEN_BITS'd0;
            RWSIZE 	<= `AXI_SIZE_BITS'd0;
            RWBURST <= 2'd0;
        end
        else begin
            if ((CurrentState == IDLE) && ARVALID_DEFAULT) begin
                ARID  	<= ARID_DEFAULT;
                RWADDR 	<= ARADDR_DEFAULT;
                RWLEN 	<= ARLEN_DEFAULT;
                RWSIZE 	<= ARSIZE_DEFAULT;
                RWBURST <= ARBURST_DEFAULT;
            end
            else if ((CurrentState == IDLE) && AWVALID_DEFAULT) begin
                AWID  	<= AWID_DEFAULT;
                RWADDR 	<= AWADDR_DEFAULT;
                RWLEN 	<= AWLEN_DEFAULT;
                RWSIZE 	<= AWSIZE_DEFAULT;
                RWBURST <= AWBURST_DEFAULT;
            end
        end
    end

// ============================================================
// Counter logic
// ============================================================
    always_ff @(posedge clk or negedge rst) begin // RWcount
		if (!rst) begin
			RWcount   <= `AXI_LEN_BITS'd0;
			RAddrLAST <= 1'b0;
		end
		else begin
			// ------------------------------------------------
			// Case 1: Data transfer (read or write in progress)
			// ------------------------------------------------
			if ((RVALID_DEFAULT && RREADY_DEFAULT) || (WVALID_DEFAULT && WREADY_DEFAULT)) begin
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
			else if ((CurrentState == IDLE) && ARVALID_DEFAULT) begin
				if (RWcount == ARLEN_DEFAULT) begin
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

endmodule