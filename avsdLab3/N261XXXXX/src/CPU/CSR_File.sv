module CSR_File (
    input  logic        clk,
    input  logic        rst,
    input  logic        IF_DONE,
    input  logic        MEM_DONE,

    input  logic        DMA_interrupt,
    input  logic        WTO_interrupt,
    input  logic        interrupt_taken,
    input  logic        interrupt_return,
    input  logic [31:0] EX_mepc,

    input  logic        enable,
    input  logic        stall,
    input  logic        flush,
    input  logic [2:0]  func3,
    input  logic [11:0] csrIdx,
    input  logic [31:0] src2,

    output logic [31:0] csrOut,
    output logic        MIE,
    output logic        MEIE,
    output logic        MTIE,
    output logic        MEIP,
    output logic        MTIP,
    output logic [31:0] MTVEC,
    output logic [31:0] MEPC
);

    // ============================================================
    // CSR Registers
    // ============================================================
    logic [63:0] cycle;
    logic [63:0] instret;
    logic [31:0] mstatus;
    logic [31:0] mie;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] mip;

    // ============================================================
    // Local Signals
    // ============================================================
    logic [31:0] rd_data;
    logic [31:0] wr_data;
    logic [63:0] instret_out;

    // ============================================================
    // CSR Read
    // ============================================================
    // -------------------------------
    // Read Data
    // -------------------------------
    always_comb begin
        unique case (csrIdx)
            `CSR_INSTRETH: rd_data = instret_out[63:32];
            `CSR_INSTRET:  rd_data = instret_out[31:0];
            `CSR_CYCLEH:   rd_data = cycle[63:32];
            `CSR_CYCLE:    rd_data = cycle[31:0];
            `CSR_MSTATUS:  rd_data = mstatus;
            `CSR_MIE:      rd_data = mie;
            `CSR_MTVEC:    rd_data = mtvec;
            `CSR_MEPC:     rd_data = mepc;
            `CSR_MIP:      rd_data = mip;
            default:       rd_data = 32'd0;
        endcase
    end

    // -------------------------------
    // CSR Output
    // -------------------------------
    always_comb begin
        if (enable) csrOut = rd_data;
        else        csrOut = 32'd0;
    end

    // ============================================================
    // CSR Write
    // ============================================================
    // -------------------------------
    // Write Data
    // -------------------------------
    always_comb begin
        unique case (func3)
            `CSRRW, `CSRRWI: wr_data = src2;
            `CSRRS, `CSRRSI: wr_data = rd_data | src2;
            `CSRRC, `CSRRCI: wr_data = rd_data & (~src2);
            default:         wr_data = 32'd0;
        endcase
    end

    // -------------------------------
    // CSR Update
    // -------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus <= 32'd0;
            mie     <= 32'd0;
            mtvec   <= 32'h0001_0000;
            mepc    <= 32'd0;
            mip     <= 32'd0;

            cycle   <= 64'd0;
            instret <= 64'd0;
        end
        else begin
            // -------------------------------
            // hardware-updated CSRs
            // -------------------------------
            cycle <= cycle + 64'd1;

            if (IF_DONE && MEM_DONE) begin
                if      (stall) instret <= instret;
                else if (flush) instret <= instret - 64'd1;
                else            instret <= instret + 64'd1;


                // -------------------------------
                // CSR instruction write
                // -------------------------------
                if (enable) begin
                    unique case (csrIdx)
                        `CSR_MSTATUS: mstatus <= {19'd0, wr_data[12:11], 3'b0, wr_data[7], 3'b0, wr_data[3], 3'b0};
                        `CSR_MIE    : mie     <= {20'd0, wr_data[11], 3'b0, wr_data[7], 7'b0};
                        `CSR_MTVEC  : mtvec   <= mtvec;
                        `CSR_MEPC   : mepc    <= {wr_data[31:2], 2'd0};
                        `CSR_MIP    : mip     <= 32'b0;
                        default     :         ;
                    endcase
                end

                // -------------------------------
                // Interrupt Taken
                // -------------------------------
                if (interrupt_taken) begin
                    //         |------| MPP |------|   MPIE   |-----|    MIE    |-----|
                    mstatus <= {19'd0, 2'b11, 3'd0, mstatus[3], 3'd0,    1'b0   , 3'd0};
                    mip     <= 32'd0;
                    mepc    <= EX_mepc;
                end
                // -------------------------------
                // Interrupt Return
                // -------------------------------
                else if (interrupt_return) begin
                    //         |------| MPP |------|   MPIE   |-----|    MIE    |-----|
                    mstatus <= {19'd0, 2'b11, 3'd0,    1'b1   , 3'd0, mstatus[7], 3'd0};
                    mip     <= 32'd0;
                end
                // -------------------------------
                // Interrupt
                // -------------------------------
                mip[7]  <= WTO_interrupt;
                mip[11] <= DMA_interrupt;
            end
        end
    end

    // ============================================================
    // Combinational Outputs and Instret Decrement
    // ============================================================
    assign MIE         = mstatus[3];
    assign MEIE        = mie[11];
    assign MTIE        = mie[7];
    assign MEIP        = mip[11];
    assign MTIP        = mip[7];
    assign MTVEC       = mtvec;
    assign MEPC        = mepc;
    assign instret_out = instret - 64'd2;


endmodule
