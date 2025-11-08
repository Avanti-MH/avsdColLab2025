`include "../include/def.svh"
`include "../include/AXI_define.svh"
`include "../src/CPU/CPU.sv"
`include "../src/CPU/controlID.sv"
`include "../src/CPU/controlEX.sv"
`include "../src/CPU/controlWB.sv"
`include "../src/CPU/IFID.sv"
`include "../src/CPU/IDEX.sv"
`include "../src/CPU/EXMEM.sv"
`include "../src/CPU/MEMWB.sv"
`include "../src/CPU/pcUnit.sv"
`include "../src/CPU/decoder.sv"
`include "../src/CPU/regFile.sv"
`include "../src/CPU/fpRegFile.sv"
`include "../src/CPU/immGenerator.sv"
`include "../src/CPU/alu.sv"
`include "../src/CPU/fpu.sv"
`include "../src/CPU/jbUnit.sv"
`include "../src/CPU/csrFile.sv"
`include "../src/CPU/loadFilter.sv"
`include "../src/CPU/storeFilter.sv"
`include "../src/CPU/branchPredictorGshare.sv"



module CPU_wrapper (
    input  logic        ACLK,
    input  logic        ARESETn,

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

    // ReadData
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

    // ReadData
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

    // WriteData
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

    // =============================================================================
    // Local parameters
    // =============================================================================
    typedef enum logic [1:0] {
        IDLE_M0        = 2'd0,
        ReadAddress_M0 = 2'd1,
        ReadData_M0    = 2'd2
    } m0_state_t;

    typedef enum logic [2:0] {
        IDLE_M1          = 3'd0,
        AddressPhase_M1  = 3'd1,
        ReadData_M1      = 3'd2,
        WriteData_M1     = 3'd3,
        WriteResponse_M1 = 3'd4
    } m1_state_t;

    // =============================================================================
    // Local signals
    // =============================================================================
    m0_state_t                 CurrentState_M0, NextState_M0;
    m1_state_t                 CurrentState_M1, NextState_M1;
    logic [`AXI_DATA_BITS-1:0] WriteData_CPU, Instr_CPU, ReadData_CPU;
    logic [`AXI_ADDR_BITS-1:0] IM_A_CPU, DM_A_CPU;
    logic                      DM_CEB_CPU, IM_CEB_CPU, DM_WEB_CPU;
    logic [`AXI_STRB_BITS-1:0] DM_BWEB_CPU;
    logic                      IM_stall, DM_stall;
    logic [`AXI_LEN_BITS-1:0]  WLEN, Wcount;


    // =============================================================================
    // Master 0 (IM) - Finite State Machine
    // =============================================================================

    // ---------------------------------------
    // State register
    // ---------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn)
        if (~ARESETn)  CurrentState_M0 <= IDLE_M0;
        else           CurrentState_M0 <= NextState_M0;

    // ---------------------------------------
    // Next state logic
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
    // Master 0 (IM) - Channel Logic
    // =============================================================================

    // ---------------------------------------
    // IDLE : Do nothing
    // ---------------------------------------

    // ---------------------------------------
    // ReadAddress
    // ---------------------------------------
    always_comb begin
        if (CurrentState_M0 == ReadAddress_M0) begin
            ARID_M0    = `AXI_ID_BITS'd0;
            ARADDR_M0  = IM_A_CPU;
            ARLEN_M0   = `AXI_LEN_ONE;
            ARSIZE_M0  = `AXI_SIZE_WORD;
            ARBURST_M0 = `AXI_BURST_INC;
            ARVALID_M0 = ~IM_CEB_CPU;
        end
        else begin
            ARID_M0    = `AXI_ID_BITS'd0;
            ARADDR_M0  = `AXI_ADDR_BITS'd0;
            ARLEN_M0   = `AXI_LEN_ONE;
            ARSIZE_M0  = `AXI_SIZE_WORD;
            ARBURST_M0 = `AXI_BURST_INC;
            ARVALID_M0 = 1'b0;
        end
    end

    // ---------------------------------------
    // ReadData
    // ---------------------------------------
    assign Instr_CPU   = (RVALID_M0 && RREADY_M0) ? RDATA_M0 : `AXI_DATA_BITS'd0;
    assign RREADY_M0   = (CurrentState_M0 == ReadData_M0);

    // =============================================================================
    // Master 1 (DM) - Finite State Machine
    // =============================================================================

    // ---------------------------------------
    // State register
    // ---------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn)
        if (~ARESETn)  CurrentState_M1 <= IDLE_M1;
        else           CurrentState_M1 <= NextState_M1;

    // ---------------------------------------
    // Next state logic
    // ---------------------------------------
    always_comb begin
        case (CurrentState_M1)
            IDLE_M1:                                                                NextState_M1 = AddressPhase_M1;
            AddressPhase_M1: begin
                if      (~DM_CEB_CPU && ~DM_WEB_CPU && AWVALID_M1 && AWREADY_M1)    NextState_M1 = WriteData_M1;
                else if (~DM_CEB_CPU && DM_WEB_CPU && ARVALID_M1 && ARREADY_M1)     NextState_M1 = ReadData_M1;
                else                                                                NextState_M1 = CurrentState_M1;
            end
            ReadData_M1: begin
                if (RREADY_M1 && RLAST_M1 && RVALID_M1)                             NextState_M1 = AddressPhase_M1;
                else                                                                NextState_M1 = CurrentState_M1;
            end
            WriteData_M1: begin
                if (WREADY_M1 && WLAST_M1 && WVALID_M1)                             NextState_M1 = WriteResponse_M1;
                else                                                                NextState_M1 = CurrentState_M1;
            end
            WriteResponse_M1: begin
                if (BVALID_M1 && BREADY_M1)                                         NextState_M1 = AddressPhase_M1;
                else                                                                NextState_M1 = CurrentState_M1;
            end
            default:                                                                NextState_M1 = IDLE_M1;
        endcase
    end

    // =============================================================================
    // Master 1 (DM) - Channel Logic
    // =============================================================================

    // ---------------------------------------
    // IDLE : Do nothing
    // ---------------------------------------

    // ---------------------------------------
    // Address ( AR / AW )
    // ---------------------------------------
    always_comb begin
        if (CurrentState_M1 == AddressPhase_M1) begin
            // AR
            ARID_M1    = `AXI_ID_BITS'd0;
            ARADDR_M1  = DM_A_CPU;
            ARLEN_M1   = `AXI_LEN_ONE;
            ARSIZE_M1  = `AXI_SIZE_WORD;
            ARBURST_M1 = `AXI_BURST_INC;
            ARVALID_M1 = (~DM_CEB_CPU && DM_WEB_CPU);
            // AW
            AWID_M1    = `AXI_ID_BITS'd0;
            AWADDR_M1  = DM_A_CPU;
            AWLEN_M1   = `AXI_LEN_ONE;
            AWSIZE_M1  = `AXI_SIZE_WORD;
            AWBURST_M1 = `AXI_BURST_INC;
            AWVALID_M1 = (~DM_CEB_CPU && ~DM_WEB_CPU);
        end
        else begin
            // AR
            ARID_M1    = `AXI_ID_BITS'd0;
            ARADDR_M1  = 32'h0001_0000;
            ARLEN_M1   = `AXI_LEN_ONE;
            ARSIZE_M1  = `AXI_SIZE_WORD;
            ARBURST_M1 = `AXI_BURST_INC;
            ARVALID_M1 = 1'b0;
            // AW
            AWID_M1    = `AXI_ID_BITS'd0;
            AWADDR_M1  = 32'h0001_0000;
            AWLEN_M1   = `AXI_LEN_ONE;
            AWSIZE_M1  = `AXI_SIZE_WORD;
            AWBURST_M1 = `AXI_BURST_INC;
            AWVALID_M1 = 1'b0;
        end
    end

    // ---------------------------------------
    // ReadData
    // ---------------------------------------
    assign ReadData_CPU = (RVALID_M1 && RREADY_M1) ? RDATA_M1 : `AXI_DATA_BITS'd0;
    assign RREADY_M1    = (CurrentState_M1 == ReadData_M1);

    // ---------------------------------------
    // WriteData
    // ---------------------------------------
    always_comb begin
        if (CurrentState_M1 == WriteData_M1) begin
            WLAST_M1  = (Wcount == WLEN);
            WVALID_M1 = 1'b1;
            WSTRB_M1  = DM_BWEB_CPU;
            WDATA_M1  = WriteData_CPU;
        end
        else begin
            WLAST_M1  = 1'b0;
            WVALID_M1 = 1'b0;
            WSTRB_M1  = `AXI_STRB_BITS'd0;
            WDATA_M1  = `AXI_DATA_BITS'd0;
        end
    end

    // ---------------------------------------
    // WriteResponse
    // ---------------------------------------
    assign BREADY_M1 = (CurrentState_M1 == WriteResponse_M1);


    // ============================================================
	// Counter logic
	// ============================================================
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            WLEN            <= `AXI_LEN_BITS'd0;
            Wcount          <= `AXI_LEN_BITS'd0;
        end
        else begin
            // Capture address phase info
            if ((CurrentState_M1 == AddressPhase_M1) && AWVALID_M1 && AWREADY_M1) begin
                WLEN           <= AWLEN_M1;
            end
            // Count write data beats
            if ((CurrentState_M1 == WriteData_M1) && WREADY_M1) begin
                if (Wcount == WLEN) Wcount <= `AXI_LEN_BITS'd0;
                else                Wcount <= Wcount + `AXI_LEN_BITS'd1;
            end
        end
    end

    // =============================================================================
    // Stall Logic
    // =============================================================================

    // ---------------------------------------
    // IM stall
    // ---------------------------------------
    always_comb begin
        IM_stall = 1'b0;
        case (CurrentState_M0)
            ReadAddress_M0: IM_stall = ~(IM_CEB_CPU);
            ReadData_M0:    IM_stall = ~(RVALID_M0 && RREADY_M0 && RLAST_M0);
            default:        IM_stall = 1'b0;
        endcase
    end

    // ---------------------------------------
    // DM stall
    // ---------------------------------------
    always_comb begin
        DM_stall = 1'b0;
        if (~DM_CEB_CPU) begin
            case (CurrentState_M1)
                AddressPhase_M1:  DM_stall = 1'b1;
                ReadData_M1:      DM_stall = ~(RVALID_M1 && RREADY_M1 && RLAST_M1);
                WriteData_M1:     DM_stall = 1'b1;
                WriteResponse_M1: DM_stall = ~(BVALID_M1 && BREADY_M1);
                default:          DM_stall = 1'b0;
            endcase
        end else begin
            DM_stall = 1'b0;
        end
    end

CPU CPU (
    // input
    .clk       (ACLK            ),
    .rst       (~ARESETn        ),
    .Instr     (Instr_CPU       ),
    .ReadData  (ReadData_CPU    ),
    .IM_stall  (IM_stall        ),
    .DM_stall  (DM_stall        ),
    // output
    .PC        (IM_A_CPU        ),
    .DM_A      (DM_A_CPU        ),
    .WriteData (WriteData_CPU   ),
    .DM_CEB    (DM_CEB_CPU      ),
    .IM_CEB    (IM_CEB_CPU      ),
    .DM_WEB    (DM_WEB_CPU      ),
    .DM_BWEB   (DM_BWEB_CPU     )
);

endmodule