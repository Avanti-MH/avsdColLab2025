module WDT(

    input               clk,
    input               rst,
    input               clk2,
    input               rst2,

    input               WDEN,
    input               WDLIVE,
    input  [31:0]       WTOCNT,
    input               WDEN_RVALID,
    input               WDLIVE_RVALID,
    input               WTOCNT_RVALID,

    output logic        WTO_interrupt
);

    // ============================================================
    // State Definition
    // ============================================================
    typedef enum logic {
        DISABLED = 1'b0,
        ENABLED  = 1'b1
    } state_t;

    state_t CurrentState, NextState;

    // ============================================================
    // Internal Register
    // ============================================================
    logic [31:0] counter;
    logic [31:0] threshold;
    logic        timeout, timeoutSync1, timeoutSync2;

    // ============================================================
    // Set up WTOCNT
    // ============================================================
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2)               threshold <= 32'd0;
        else if (WTOCNT_RVALID) threshold <= WTOCNT;
    end

    // ============================================================
    // Finite State Machine
    // ============================================================

    // ---------------------------------------
    // State Register
    // ---------------------------------------
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2) CurrentState <= DISABLED;
        else      CurrentState <= NextState;
    end

    // ---------------------------------------
    // Next State Logic
    // ---------------------------------------
    always_comb begin
        case (CurrentState)
            DISABLED: begin
                if (WDEN_RVALID && WDEN)  NextState = ENABLED;
                else                      NextState = DISABLED;
            end
            ENABLED: begin
                if (WDEN_RVALID && ~WDEN) NextState = DISABLED;
                else                      NextState = ENABLED;
            end
        endcase
    end

    // ============================================================
    // Main Counter Logic
    // ============================================================
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2) begin
            counter <= 32'd0;
        end
        else begin
            case (CurrentState)
                ENABLED: counter <= (counter > threshold || (WDLIVE_RVALID && WDLIVE)) ? 32'd0 : counter + 32'd1;
                default: counter <= 32'd0;
            endcase
        end
    end

    // ============================================================
    // Timeout Detection
    // ============================================================
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2) timeout <= 1'b0;
        else      timeout <= (counter > threshold);
    end

    // ============================================================
    // Two-stage Synchronization for Timeout Signal
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            timeoutSync1 <= 1'b0;
            timeoutSync2 <= 1'b0;
        end
        else begin
            timeoutSync1 <= timeout;
            timeoutSync2 <= timeoutSync1;
        end
    end

    assign WTO_interrupt = timeoutSync2;

endmodule