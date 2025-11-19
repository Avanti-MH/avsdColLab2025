module WDT(
    // Clock and Reset Signals
    input  clk,
    input  rst,
    input  clk2,
    input  rst2,

    // Watchdog Timer Configuration Inputs
    input  WDEN,          
    input  WDEN_valid,     
    input  WDLIVE,        
    input  WDLIVE_valid,    
    input  [31:0] WTOCNT,   
    input  WTOCNT_valid,   
    input  rempty,          
    
    // Timeout Output
    output logic WTO_interrupt          
);

    // Internal Registers
    logic [31:0] watchdog_counter;      
    logic wdt_enable_state;            
    logic wdt_live_state;               
    logic [31:0] wdt_timeout_threshold;         

    // Watchdog Enable Register
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2) begin
            wdt_enable_state <= 1'b0;
        end
        else if (WDEN_valid & ~rempty) begin
            wdt_enable_state <= WDEN;
        end
    end

    // Watchdog Live Signal Register
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2) begin
            wdt_live_state <= 1'b0;
        end
        else if (WDLIVE_valid & ~rempty) begin
            wdt_live_state <= WDLIVE;
        end
    end

    // Timeout Counter Value Register
    always_ff @(posedge clk2 or posedge rst2) begin
        if (rst2) begin
            wdt_timeout_threshold <= 32'b0;
        end
        else if (WTOCNT_valid & ~rempty) begin
            wdt_timeout_threshold <= WTOCNT;
        end
    end

    // Main Counter Logic
    always_ff @(posedge clk2 or posedge rst2) begin 
        if (rst2) begin
            watchdog_counter <= 32'd0;
        end
        else begin
            if (wdt_enable_state) begin
                // Reset counter if it exceeds timeout or live signal is active
                if (watchdog_counter > wdt_timeout_threshold) 
                    watchdog_counter <= !WDEN && WDEN_valid ? 32'd0 : watchdog_counter;
                else 
                    watchdog_counter <= wdt_live_state ? 32'd0 : watchdog_counter + 32'd1;
                
            end
        end
    end

    // Timeout Detection Signals
    logic wdt_timeout_detected;            
    logic wdt_timeout_sync_stage1;         
    logic wdt_timeout_sync_stage2;    
    
    // Timeout Detection
    always_ff @(posedge clk2 or posedge rst2) begin 
        if (rst2)
            wdt_timeout_detected <= 1'd0;
        else if (watchdog_counter > wdt_timeout_threshold)
            wdt_timeout_detected <= 1'd1;
        else 
            wdt_timeout_detected <= 1'd0;
    end

    // Two-stage Synchronization for Timeout Signal
    always_ff @(posedge clk2 or posedge rst2) begin 
        if (rst2) begin
            wdt_timeout_sync_stage1 <= 1'b0;
            wdt_timeout_sync_stage2 <= 1'b0;
        end
        else begin
            wdt_timeout_sync_stage1 <= wdt_timeout_detected;
            wdt_timeout_sync_stage2 <= wdt_timeout_sync_stage1;
        end
    end

    // Final Timeout Output
    assign WTO_interrupt = wdt_timeout_sync_stage2;

endmodule