`include "../include/AXI_define.svh"
`include "../src/CPU/CPU.sv"

module CPU_wrapper (
    input  logic                      clk,
    input  logic                      rst,

    // =============================================================================
    // Interrupt
    // =============================================================================
    input  logic                      DMA_interrupt,
    input  logic                      WTO_interrupt,

    // =============================================================================
    // Master 0 (IM)
    // =============================================================================

    // ReadAddress
    output logic [`AXI_ID_BITS-1:0]   ARID_M0,
    output logic [`AXI_ADDR_BITS-1:0] ARADDR_M0,
    output logic [`AXI_LEN_BITS-1:0]  ARLEN_M0,
    output logic [`AXI_SIZE_BITS-1:0] ARSIZE_M0,
    output logic [1:0]                ARBURST_M0,
    output logic                      ARVALID_M0,
    input  logic                      ARREADY_M0,

    // MEM_RdData
    input  logic [`AXI_ID_BITS-1:0]   RID_M0,
    input  logic [`AXI_DATA_BITS-1:0] RDATA_M0,
    input  logic [1:0]                RRESP_M0,
    input  logic                      RLAST_M0,
    input  logic                      RVALID_M0,
    output logic                      RREADY_M0,

    // =============================================================================
    // Master 1 (DM)
    // =============================================================================

    // ReadAddress
    output logic [`AXI_ID_BITS-1:0]   ARID_M1,
    output logic [`AXI_ADDR_BITS-1:0] ARADDR_M1,
    output logic [`AXI_LEN_BITS-1:0]  ARLEN_M1,
    output logic [`AXI_SIZE_BITS-1:0] ARSIZE_M1,
    output logic [1:0]                ARBURST_M1,
    output logic                      ARVALID_M1,
    input  logic                      ARREADY_M1,

    // MEM_RdData
    input  logic [`AXI_ID_BITS-1:0]   RID_M1,
    input  logic [`AXI_DATA_BITS-1:0] RDATA_M1,
    input  logic [1:0]                RRESP_M1,
    input  logic                      RLAST_M1,
    input  logic                      RVALID_M1,
    output logic                      RREADY_M1,

    // WriteAddress
    output logic [`AXI_ID_BITS-1:0]   AWID_M1,
    output logic [`AXI_ADDR_BITS-1:0] AWADDR_M1,
    output logic [`AXI_LEN_BITS-1:0]  AWLEN_M1,
    output logic [`AXI_SIZE_BITS-1:0] AWSIZE_M1,
    output logic [1:0]                AWBURST_M1,
    output logic                      AWVALID_M1,
    input  logic                      AWREADY_M1,

    // MEM_WrData
    output logic [`AXI_DATA_BITS-1:0] WDATA_M1,
    output logic [`AXI_STRB_BITS-1:0] WSTRB_M1,
    output logic                      WLAST_M1,
    output logic                      WVALID_M1,
    input  logic                      WREADY_M1,

    // WriteResponse
    input  logic [`AXI_ID_BITS-1:0]   BID_M1,
    input  logic [1:0]                BRESP_M1,
    input  logic                      BVALID_M1,
    output logic                      BREADY_M1
);

//-----------------------------------------------------------Master 0-----------------------------------------------------------//

    //====================================================
    // State Definition
    //====================================================
    typedef enum logic [1:0] {
        IDLE_M0        = 2'd0,
        ReadAddress_M0 = 2'd1,
        ReadData_M0    = 2'd2
    } m0_state_t;

    m0_state_t CurrentState_M0, NextState_M0;


    //====================================================
    // Local Signals and Registers
    //====================================================
    logic [`AXI_ADDR_BITS-1:0] IF_ADDR;
    logic [`AXI_DATA_BITS-1:0] IF_RdData;
    logic                      IF_VALID, IF_DONE;

    // =============================================================================
    // Finite State Machine
    // =============================================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @(posedge clk or posedge rst)
        if (rst)  CurrentState_M0 <= IDLE_M0;
        else      CurrentState_M0 <= NextState_M0;

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        case (CurrentState_M0)
            IDLE_M0:                                    NextState_M0 = ReadAddress_M0;
            ReadAddress_M0: begin
                if (ARREADY_M0 && ARVALID_M0)           NextState_M0 = ReadData_M0;
                else                                    NextState_M0 = CurrentState_M0;
            end
            ReadData_M0: begin
                if (RREADY_M0 && RLAST_M0 && RVALID_M0) NextState_M0 = ReadAddress_M0;
                else                                    NextState_M0 = CurrentState_M0;
            end
            default:                                    NextState_M0 = IDLE_M0;
        endcase
    end

    // =============================================================================
    // Channel Output Logic (combinational)
    // =============================================================================
    always_comb begin
        ARID_M0    = `AXI_ID_BITS'd0;
        ARADDR_M0  = `AXI_ADDR_BITS'd0;
        ARLEN_M0   = `AXI_LEN_ONE;
        ARSIZE_M0  = `AXI_SIZE_WORD;
        ARBURST_M0 = `AXI_BURST_INC;
        ARVALID_M0 = 1'b0;
        RREADY_M0  = 1'b0;
        case (CurrentState_M0)
            ReadAddress_M0: begin
                ARVALID_M0 = IF_VALID;
                ARADDR_M0  = IF_ADDR;
            end
            ReadData_M0: begin
                RREADY_M0  = 1'b1;
            end
            default: begin
            end
        endcase
    end

    // =============================================================================
    // CPU Interface
    // =============================================================================
    always_comb begin
        IF_RdData = `AXI_DATA_BITS'd0;
        IF_DONE   = 1'b0;
        case (CurrentState_M0)
            ReadAddress_M0: begin
                IF_DONE   = ~IF_VALID;
            end
            ReadData_M0: begin
                IF_RdData = (RVALID_M0 && RREADY_M0) ? RDATA_M0 : `AXI_DATA_BITS'd0;
                IF_DONE   = (RREADY_M0 && RLAST_M0 && RVALID_M0);
            end
            default: begin
            end
        endcase
    end

//-----------------------------------------------------------Master 1-----------------------------------------------------------//

    //====================================================
    // State Definition
    //====================================================
    typedef enum logic [2:0] {
        IDLE_M1          = 3'd0,
        AddressPhase_M1  = 3'd1,
        ReadData_M1      = 3'd2,
        WriteData_M1     = 3'd3,
        WriteResponse_M1 = 3'd4
    } m1_state_t;

    m1_state_t CurrentState_M1, NextState_M1;

    //====================================================
    // Local Signals and Registers
    //====================================================
    logic                      MEM_VALID, MEM_WEB, MEM_DONE;
    logic [`AXI_ADDR_BITS-1:0] MEM_ADDR;
    logic [`AXI_DATA_BITS-1:0] MEM_WrData, MEM_RdData;
    logic [`AXI_STRB_BITS-1:0] MEM_STRB;

    // =============================================================================
    // Finite State Machine
    // =============================================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @(posedge clk or posedge rst)
        if (rst) CurrentState_M1 <= IDLE_M1;
        else     CurrentState_M1 <= NextState_M1;

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        case (CurrentState_M1)
            IDLE_M1:                                    NextState_M1 = AddressPhase_M1;
            AddressPhase_M1: begin
                if      (AWVALID_M1 && AWREADY_M1)      NextState_M1 = WriteData_M1;
                else if (ARVALID_M1 && ARREADY_M1)      NextState_M1 = ReadData_M1;
                else                                    NextState_M1 = CurrentState_M1;
            end
            ReadData_M1: begin
                if (RREADY_M1 && RLAST_M1 && RVALID_M1) NextState_M1 = AddressPhase_M1;
                else                                    NextState_M1 = CurrentState_M1;
            end
            WriteData_M1: begin
                if (WREADY_M1 && WLAST_M1 && WVALID_M1) NextState_M1 = WriteResponse_M1;
                else                                    NextState_M1 = CurrentState_M1;
            end
            WriteResponse_M1: begin
                if (BVALID_M1 && BREADY_M1)             NextState_M1 = AddressPhase_M1;
                else                                    NextState_M1 = CurrentState_M1;
            end
            default:                                    NextState_M1 = IDLE_M1;
        endcase
    end

    // =============================================================================
    // Channel Output Logic (combinational)
    // =============================================================================
    always_comb begin
        ARID_M1    = `AXI_ID_BITS'd0;
        AWID_M1    = `AXI_ID_BITS'd0;
        ARADDR_M1  = 32'h0001_0000;
        AWADDR_M1  = 32'h0001_0000;
        ARLEN_M1   = `AXI_LEN_ONE;
        AWLEN_M1   = `AXI_LEN_ONE;
        ARSIZE_M1  = `AXI_SIZE_WORD;
        AWSIZE_M1  = `AXI_SIZE_WORD;
        ARBURST_M1 = `AXI_BURST_INC;
        AWBURST_M1 = `AXI_BURST_INC;
        ARVALID_M1 = 1'b0;
        AWVALID_M1 = 1'b0;
        WLAST_M1   = 1'b0;
        WVALID_M1  = 1'b0;
        WSTRB_M1   = `AXI_STRB_BITS'd0;
        WDATA_M1   = `AXI_DATA_BITS'd0;
        RREADY_M1  = 1'b0;
        BREADY_M1  = 1'b0;

        case (CurrentState_M1)
            AddressPhase_M1: begin
                ARVALID_M1 = (MEM_VALID && ~MEM_WEB);
                AWVALID_M1 = (MEM_VALID && MEM_WEB);
                ARADDR_M1  = MEM_ADDR;
                AWADDR_M1  = MEM_ADDR;
            end
            ReadData_M1: begin
                RREADY_M1    = 1'b1;
            end
            WriteData_M1: begin
                WLAST_M1  = 1'b1;
                WVALID_M1 = 1'b1;
                WSTRB_M1  = MEM_STRB;
                WDATA_M1  = MEM_WrData;
            end
            WriteResponse_M1: begin
                BREADY_M1 = 1'b1;
            end
            default:begin
            end
        endcase
    end

    // =============================================================================
    // CPU Interface
    // =============================================================================
    always_comb begin
        MEM_RdData = `AXI_DATA_BITS'd0;
        MEM_DONE   = 1'b0;
        case (CurrentState_M1)
            AddressPhase_M1: begin
                MEM_DONE   = ~MEM_VALID;
            end
            ReadData_M1: begin
                MEM_RdData = (RVALID_M1 && RREADY_M1) ? RDATA_M1 : `AXI_DATA_BITS'd0;
                MEM_DONE   = (RREADY_M1 && RLAST_M1 && RVALID_M1);
            end
            WriteResponse_M1: begin
                MEM_DONE   = (BVALID_M1 && BREADY_M1);
            end
            default: begin
            end
        endcase
    end

//-----------------------------------------------------------CPU Instance-----------------------------------------------------------//

CPU CPU (
    .clk            (clk             ),
    .rst            (rst             ),
    .DMA_interrupt  (DMA_interrupt   ),
	.WTO_interrupt  (WTO_interrupt   ),

    .IF_RdData      (IF_RdData       ),
    .IF_DONE        (IF_DONE         ),
    .MEM_RdData     (MEM_RdData      ),
    .MEM_DONE       (MEM_DONE        ),

    .IF_VALID       (IF_VALID        ),
    .IF_ADDR        (IF_ADDR         ),
    .MEM_VALID      (MEM_VALID       ),
    .MEM_ADDR       (MEM_ADDR        ),
    .MEM_WrData     (MEM_WrData      ),
    .MEM_WEB        (MEM_WEB         ),
    .MEM_STRB       (MEM_STRB        )
);

endmodule