`include "../include/AXI_define.svh"
`include "../src/WDT/WDT.sv"
`include "../src/WDT/ASYN_FIFO.sv"

module WDT_wrapper (

    input  logic                            clk,
    input  logic                            rst,
    input  logic                            clk2,
    input  logic                            rst2,

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
    input  logic                            BREADY_S,

    // Interrupt
    output logic                            WTO_interrupt
);

    // ============================================================
    // State Definition
    // ============================================================
    typedef enum logic [1:0] {
        ACCEPT        = 2'd0,
        ReadData      = 2'd1,
        WriteData     = 2'd2,
        WriteResponse = 2'd3
    } state_t;

    state_t                     CurrentState, NextState;

    // ============================================================
    // Registers Address Mapping
    // ============================================================
    localparam logic [31:0] ADDR_LIST [0:2] = '{32'h0000_0100,
                                                32'h0000_0200,
                                                32'h0000_0300};

    // ============================================================
    // Watchdog Timer Registers
    // ============================================================
    logic [2:0]                wpush, wfull, fifo_empty;
    logic [`AXI_DATA_BITS-1:0] fifo_out [0:2];
    logic                      WREADY; // Depend on FIFO is full or not

    // ============================================================
    // ID Registers
    // ============================================================
    logic [`AXI_IDS_BITS-1:0 ]  AWID, ARID;
    logic [`AXI_ADDR_BITS-1:0]  ADDR;

    // ============================================================
    // Finite State Machine
    // ============================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @( posedge clk or posedge rst ) begin
        if (rst) CurrentState <= ACCEPT;
        else     CurrentState <= NextState;
    end

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        case(CurrentState)
        ACCEPT: begin
            if      (ARVALID_S) NextState = ReadData;
            else if (AWVALID_S) NextState = WriteData;
            else                NextState = ACCEPT;
        end
        ReadData: begin
            if (RREADY_S)       NextState = ACCEPT;
            else                NextState = CurrentState;
        end
        WriteData: begin
            if (WVALID_S && WLAST_S)
                                NextState = WriteResponse;
            else                NextState = CurrentState;
        end
        WriteResponse: begin
            if(BREADY_S)        NextState = ACCEPT;
            else                NextState = CurrentState;
        end
        endcase
    end

    // ============================================================
    // Channel Output Logic (combinational)
    // ============================================================
    always_comb begin
        ARREADY_S = 1'b0;
        AWREADY_S = 1'b0;
        RID_S     = `AXI_IDS_BITS'd0;
        RDATA_S   = `AXI_DATA_BITS'd0;
        RRESP_S   = `AXI_RESP_DECERR;
        RVALID_S  = 1'b0;
        RLAST_S   = 1'b0;
        WREADY_S  = 1'b0;
        BID_S     = `AXI_IDS_BITS'd0;
        BVALID_S  = 1'b0;
        BRESP_S   = `AXI_RESP_DECERR;

        case (CurrentState)
            ACCEPT: begin
                ARREADY_S = 1'b1;
                AWREADY_S = 1'b1;
            end
            ReadData: begin
                RID_S     = ARID;
                RDATA_S   = `AXI_DATA_BITS'd0;
                RRESP_S   = `AXI_RESP_DECERR;
                RVALID_S  = 1'b1;
                RLAST_S   = 1'b1;
            end
            WriteData: begin
                WREADY_S  = WREADY;
            end
            WriteResponse: begin
                BID_S     = AWID;
                BVALID_S  = 1'b1;
                BRESP_S   = `AXI_RESP_OKAY;
            end
        endcase
    end

    // ============================================================
    // ID Storage
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ARID <= `AXI_IDS_BITS'd0;
            AWID <= `AXI_IDS_BITS'd0;
            ADDR <= `AXI_ADDR_BITS'b0;
        end
        else if (CurrentState == ACCEPT) begin
            ARID <= ARVALID_S ? ARID_S : ARID;
            AWID <= AWVALID_S ? AWID_S : AWID;
            ADDR <= (ARVALID_S) ? ARADDR_S: (AWVALID_S ? AWADDR_S : ADDR);
        end
    end

    // ============================================================
    // WDT Interface
    // ============================================================

    // FIFO Write Push Control and Write Ready Signal
    always_comb begin
        wpush  = 3'b0;
        WREADY = 1'b0;
        if (CurrentState == WriteData && WVALID_S) begin
            for (int i = 0; i < 3; i++) begin
                if (ADDR == ADDR_LIST[i]) begin
                    wpush[i] = 1'b1;
                    WREADY = ~wfull[i];
                end
            end
        end
    end

    genvar i;
    generate
    for (i = 0; i < 3; i++) begin : fifo_gen
        ASYN_FIFO #(.DATA_WIDTH(`AXI_DATA_BITS)) asyn_fifo (
            .wclk(clk),
            .wrst(rst),
            .wpush(wpush[i]),
            .FIFO_in(WDATA_S),
            .wfull(wfull[i]),
            .rclk(clk2),
            .rrst(rst2),
            .rpop(1'b1),
            .FIFO_out(fifo_out[i]),
            .rempty(fifo_empty[i])
        );
    end
    endgenerate


WDT wdt (
    // input
    .clk(clk),
    .rst(rst),
    .clk2(clk2),
    .rst2(rst2),
    .WDEN          (fifo_out[0][0]),
    .WDLIVE        (fifo_out[1][0]),
    .WTOCNT        (fifo_out[2]),
    .WDEN_RVALID   (~fifo_empty[0]),
    .WDLIVE_RVALID (~fifo_empty[1]),
    .WTOCNT_RVALID (~fifo_empty[2]),
    // outut
    .WTO_interrupt (WTO_interrupt)
);

endmodule