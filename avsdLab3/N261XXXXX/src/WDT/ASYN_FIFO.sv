module ASYN_FIFO #(
    // ============================================================
    // Parameters
    // ============================================================
    parameter FIFO_DEPTH = 4,
    parameter DATA_WIDTH = 32
) (
    // ============================================================
    // Clock Domain Interfaces
    // ============================================================
    input  logic                  wclk,
    input  logic                  wrst,
    input  logic                  wpush,
    input  logic [DATA_WIDTH-1:0] FIFO_in,
    output logic                  wfull,

    input  logic                  rclk,
    input  logic                  rrst,
    input  logic                  rpop,
    output logic [DATA_WIDTH-1:0] FIFO_out,
    output logic                  rempty
);

    // ============================================================
    // Local Parameters
    // ============================================================
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
    localparam PTR_WIDTH  = ADDR_WIDTH + 1;

    // ============================================================
    // Internal Signals
    // ============================================================
    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    logic [PTR_WIDTH-1:0] wrPtrBin,  rdPtrBin;
    logic [PTR_WIDTH-1:0] wrPtrGray, rdPtrGray;
    logic [PTR_WIDTH-1:0] rdPtrGraySync1, rdPtrGraySync2;
    logic [PTR_WIDTH-1:0] wrPtrGraySync1, wrPtrGraySync2;

    // ============================================================
    // Binary -> Gray conversion
    // ============================================================
    function logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
        bin2gray = (bin >> 1) ^ bin;
    endfunction

    // ============================================================
    // FIFO Status
    // ============================================================
    always_ff @(posedge wclk or posedge wrst) begin
        if (wrst)
            wfull <= 1'b0;
        else
            // full: MSB 不同且其餘位相等
            wfull <= (wrPtrGray[PTR_WIDTH-1] != rdPtrGraySync2[PTR_WIDTH-1]) &&
                     (wrPtrGray[PTR_WIDTH-2:0] == rdPtrGraySync2[PTR_WIDTH-2:0]);
    end

    always_ff @(posedge rclk or posedge rrst) begin
        if (rrst)
            rempty <= 1'b1;
        else
            rempty <= (rdPtrGray == wrPtrGraySync2);
    end

    // ============================================================
    // Write Logic
    // ============================================================
    always_ff @(posedge wclk or posedge wrst) begin
        if (wrst) begin
            wrPtrBin  <= PTR_WIDTH'd0;
            wrPtrGray <= PTR_WIDTH'd0;
            for (int i = 0; i < FIFO_DEPTH; i++)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else if (wpush & ~wfull) begin
            mem[wrPtrBin[ADDR_WIDTH-1:0]] <= FIFO_in;
            wrPtrBin  <= wrPtrBin + PTR_WIDTH'd1;
            wrPtrGray <= bin2gray(wrPtrBin + PTR_WIDTH'd1);
        end
    end

    // ============================================================
    // Read Logic
    // ============================================================
    always_ff @(posedge rclk or posedge rrst) begin
        if (rrst) begin
            rdPtrBin  <= PTR_WIDTH'd0;
            rdPtrGray <= PTR_WIDTH'd0;
        end else if (rpop & ~rempty) begin
            rdPtrBin  <= rdPtrBin + PTR_WIDTH'd1;
            rdPtrGray <= bin2gray(rdPtrBin + PTR_WIDTH'd1);
        end
    end

    assign FIFO_out = (!rempty) ? mem[rdPtrBin[ADDR_WIDTH-1:0]] : {DATA_WIDTH{1'b0}};

    // ============================================================
    // Cross-Clock Synchronization
    // ============================================================
    always_ff @(posedge wclk or posedge wrst) begin
        if (wrst) begin
            rdPtrGraySync1 <= PTR_WIDTH'd0;
            rdPtrGraySync2 <= PTR_WIDTH'd0;
        end else begin
            rdPtrGraySync1 <= rdPtrGray;
            rdPtrGraySync2 <= rdPtrGraySync1;
        end
    end

    always_ff @(posedge rclk or posedge rrst) begin
        if (rrst) begin
            wrPtrGraySync1 <= PTR_WIDTH'd0;
            wrPtrGraySync2 <= PTR_WIDTH'd0;
        end else begin
            wrPtrGraySync1 <= wrPtrGray;
            wrPtrGraySync2 <= wrPtrGraySync1;
        end
    end

endmodule
