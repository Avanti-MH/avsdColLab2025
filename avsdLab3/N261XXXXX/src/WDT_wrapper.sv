`include "./WDT/WDT.sv"
`include "../include/AXI_define.svh"
`include "./CDC_lib/ASYN_FIFO.sv"
//`include "../CDC_lib/asyn_fifo_32bit.sv"

module WDT_wrapper (
    // Clock and Reset Signals
    input wire clk,
    input wire clk2,
    input wire rst,
    input wire rst2,
    
    // AXI Write Address Channel
    input wire [`AXI_IDS_BITS-1:0]   AWID,
    input wire [`AXI_ADDR_BITS-1:0]  AWADDR,
    input wire [`AXI_LEN_BITS-1:0]   AWLEN,
    input wire [`AXI_SIZE_BITS-1:0]  AWSIZE,
    input wire [1:0]                 AWBURST,
    input wire                       AWVALID,
    output logic                     AWREADY,

    // AXI Write Data Channel
    input wire [`AXI_DATA_BITS-1:0]  WDATA,
    input wire [`AXI_STRB_BITS-1:0]  WSTRB,
    input wire                       WLAST,
    input wire                       WVALID,
    output logic                     WREADY,

    // AXI Read Address Channel
    input wire [`AXI_IDS_BITS-1:0]   ARID,
    input wire [`AXI_ADDR_BITS-1:0]  ARADDR,
    input wire [`AXI_LEN_BITS-1:0]   ARLEN,
    input wire [`AXI_SIZE_BITS-1:0]  ARSIZE,
    input wire [1:0]                 ARBURST,
    input wire                       ARVALID,
    output logic                     ARREADY,

    // AXI Read Data Channel
    output logic [`AXI_IDS_BITS-1:0] RID,
    output logic [`AXI_DATA_BITS-1:0] RDATA,
    output logic [1:0]               RRESP,
    output logic                     RLAST,
    output logic                     RVALID,
    input wire                       RREADY,

    // AXI Write Response Channel
    output logic [`AXI_IDS_BITS-1:0] BID,
    output logic [1:0]               BRESP,
    output logic                     BVALID,
    input wire                       BREADY,

    // Interrupt Signal
    output logic WTO_interrupt
);

    // State Machine Parameters
    localparam IDLE       = 2'd0;
    localparam RDATA_STATE = 2'd1;
    localparam WDATA_STATE = 2'd2;
    localparam B_STATE     = 2'd3;

    // Address Range Parameters
    localparam ADDR_BEGIN = 32'h1001_0000;
    localparam ADDR_END   = 32'h1001_03ff;

    // Internal Signals for Asynchronous FIFO
    logic wpush, wfull;
    logic [36:0] FIFO_in, FIFO_out;
    logic rempty;

    // Registered Address and Burst Signals
    logic [`AXI_IDS_BITS-1:0]  ARID_r, AWID_r;
    logic [`AXI_ADDR_BITS-1:0] ARADDR_r, AWADDR_r;
    logic [`AXI_LEN_BITS-1:0]  ARLEN_r, AWLEN_r;
    logic [`AXI_LEN_BITS-1:0]  R_burst_r, W_burst_r;

    // Watchdog Timer Control Signals
    logic WDEN, WDLIVE;
    logic [31:0] WTOCNT;
    logic WDEN_valid, WDLIVE_valid, WTOCNT_valid;

    // Handshake and State Signals
    logic handshake_AR, handshake_R, handshake_AW, handshake_W, handshake_B;
    logic [1:0] current_state, next_state; 

    // AXI Read Channel Assignments
    assign RID      = ARID_r;
    assign ARREADY  = (current_state == IDLE) ? 1'b1 : 1'b0;
    assign RVALID   = (current_state == RDATA_STATE) ? 1'b1 : 1'b0;
    assign RDATA    = 32'd0;
    assign RLAST    = (RVALID && (R_burst_r == ARLEN_r)) ? 1'b1 : 1'b0;
    assign RRESP    = ((ARADDR_r >= ADDR_BEGIN) && (ARADDR_r <= ADDR_END)) ? 2'b00 : 2'b11;

    // AXI Write Channel Assignments
    assign AWREADY = (current_state == IDLE) ? 1'b1 : 1'b0;
    assign WREADY  = (current_state == WDATA_STATE && ~wfull) ? 1'b1 : 1'b0;
    assign BRESP   = ((ARADDR_r >= ADDR_BEGIN) && (ARADDR_r <= ADDR_END)) ? 2'b00 : 2'b11;

    // FIFO Write Data Preparation
    assign FIFO_in  = {WDEN_valid, WDEN, WDLIVE_valid, WDLIVE, WTOCNT_valid, WTOCNT};

    // State Machine Sequential Logic
    always_ff @(posedge clk , posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else 
            current_state <= next_state;
    end

    // Handshake Signal Definitions
    assign handshake_AR = ARREADY & ARVALID;
    assign handshake_AW = AWVALID & AWREADY;
    assign handshake_R  = RVALID & RREADY;
    assign handshake_W  = WVALID & WREADY;
    assign handshake_B  = BVALID & BREADY;

    // Next State Logic
    always_comb begin
        case (current_state)
            IDLE        : next_state = (handshake_AW) ? WDATA_STATE : IDLE;
            RDATA_STATE : next_state = (handshake_R & RLAST) ? IDLE : RDATA_STATE;
            WDATA_STATE : next_state = (handshake_W & WLAST) ? B_STATE : WDATA_STATE;
            B_STATE     : next_state = (handshake_B) ? IDLE : B_STATE;
            default     : next_state = IDLE;
        endcase
    end

    // Read Burst Counter
    always_ff @(posedge clk , posedge rst) begin
        if (rst)
            R_burst_r <= 4'd0;
        else if (handshake_R) begin
            R_burst_r <= RLAST ? 4'd0 : R_burst_r + 4'd1;
        end
    end

    // Read Address Channel Registers
    always_ff @(posedge clk , posedge rst) begin
        if (rst) begin
            ARID_r   <= 8'd0;
            ARADDR_r <= 32'd0;
            ARLEN_r  <= 4'd0;
        end
        else if (handshake_AR) begin
            ARID_r   <= ARID;
            ARADDR_r <= ARADDR;
            ARLEN_r  <= ARLEN;
        end
    end

    // Write Address Channel Registers
    always_ff @(posedge clk , posedge rst) begin
        if (rst) begin
            AWADDR_r <= 32'd0;
            AWID_r   <= 8'd0;
            AWLEN_r  <= 4'd0;
        end
        else if (handshake_AW) begin
            AWADDR_r <= AWADDR;
            AWID_r   <= AWID;
            AWLEN_r  <= AWLEN;
        end
    end

    // Write Response Channel Control
    always_ff @(posedge clk , posedge rst) begin
        if (rst)
            BVALID <= 1'd0;
        else
            BVALID <= (next_state == B_STATE) ? 1'd1 : 1'd0;
    end

    always_ff @(posedge clk , posedge rst) begin
        if (rst)
            BID <= 8'd0;
        else if (next_state == B_STATE)
            BID <= AWID;
    end

    // Watchdog Timer Enable Control
    always_ff @(posedge clk , posedge rst) begin
        if (rst) begin
            WDEN <= 1'd0;
            WDEN_valid <= 1'd0;
        end
        else if (~WDEN_valid && current_state == WDATA_STATE && AWADDR_r == 32'h0000_0100) begin
            WDEN <= WDATA[0];
            WDEN_valid <= 1'b1;
        end
        else begin
            WDEN <= 1'b0;
            WDEN_valid <= 1'b0;
        end
    end

    // Watchdog Timer Live Control
    always_ff @(posedge clk , posedge rst) begin
        if (rst) begin
            WDLIVE <= 1'd0;
            WDLIVE_valid <= 1'd0;
        end
        else if (~WDLIVE_valid && current_state == WDATA_STATE && AWADDR_r == 32'h0000_0200) begin
            WDLIVE <= WDATA[0];
            WDLIVE_valid <= 1'b1; 
        end
        else begin
            WDLIVE <= 1'b0;
            WDLIVE_valid <= 1'b0;
        end
    end

    // Watchdog Timer Timeout Counter
    always_ff @(posedge clk , posedge rst) begin
        if (rst) begin
            WTOCNT <= 32'd0;
            WTOCNT_valid <= 1'd0;
        end
        else if (~WTOCNT_valid && handshake_W && AWADDR_r == 32'h0000_0300) begin
            WTOCNT <= WDATA;
            WTOCNT_valid <= 1'b1;
        end
        else begin
            WTOCNT <= 32'b0;
            WTOCNT_valid <= 1'b0;
        end
    end

    // FIFO Write Push Control
    always_ff @(posedge clk , posedge rst) begin
        if (rst) begin
            wpush <= 0;
        end
        else if ((~WTOCNT_valid && handshake_W && AWADDR_r == 32'h0000_0300) || 
                 (~WDLIVE_valid && handshake_W && AWADDR_r == 32'h0000_0200) || 
                 (~WDEN_valid && handshake_W && AWADDR_r == 32'h0000_0100) && ~wfull) begin
            wpush <= 1;
        end
        else begin
            wpush <= 0;
        end
    end

    // Asynchronous FIFO Instance
    ASYN_FIFO asyn_fifo (
        .wclk(clk),      
        .wrst(rst),      
        .wpush(wpush),     
        .FIFO_in(FIFO_in),     
        .wfull(wfull),     

        .rclk(clk2),      
        .rrst(rst2),      
        .rpop(1'b1),      
        .FIFO_out(FIFO_out),     
        .rempty(rempty)    
    );

    // Watchdog Timer Instance
    WDT wdt (
        .clk(clk),
        .clk2(clk2),
        .rst(rst),
        .rst2(rst2),
        .WDEN(FIFO_out[35]),
        .WDEN_valid(FIFO_out[36]),
        .WDLIVE(FIFO_out[33]),
        .WDLIVE_valid(FIFO_out[34]),
        .WTOCNT(FIFO_out[31:0]),
        .WTOCNT_valid(FIFO_out[32]),
        .rempty(rempty),
        .WTO_interrupt(WTO_interrupt)
    );

endmodule