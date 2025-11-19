module ASYN_FIFO (
    // Write domain
    input wclk,     // Write clock
    input wrst,     // Write reset
    input wpush,    // Write push
    input [36:0] FIFO_in,  // Write data
    output wfull,   // Write full flag

    // Read domain  
    input rclk,     // Read clock
    input rrst,     // Read reset
    input rpop,     // Read pop
    output [36:0] FIFO_out,  // Read data
    output rempty   // Read empty flag
);

    localparam FIFO_DEPTH = 4;     
    localparam ADDR_WIDTH = 2;  
    localparam DATA_WIDTH = 37; 

    logic [DATA_WIDTH-1:0] fifo_memory [0:FIFO_DEPTH-1];

    logic [ADDR_WIDTH-1:0] read_ptr, write_ptr;
    logic [ADDR_WIDTH-1:0] read_ptr_sync_stage1, read_ptr_sync_stage2;
    logic [ADDR_WIDTH-1:0] write_ptr_sync_stage1, write_ptr_sync_stage2;

    logic write_enable;

    // FIFO status detection
    assign wfull = (
        (write_ptr[ADDR_WIDTH-1] != read_ptr_sync_stage2[ADDR_WIDTH-1]) && 
        (write_ptr[ADDR_WIDTH-2:0] == read_ptr_sync_stage2[ADDR_WIDTH-2:0])
    );
    assign rempty = (read_ptr == write_ptr_sync_stage2);
    
    // Write enable
    assign write_enable = (wpush & ~wfull);
    
    // Read data
    assign FIFO_out = (!rempty) ? fifo_memory[read_ptr[ADDR_WIDTH-2:0]] : {DATA_WIDTH{1'b0}};

    // Read clock domain cross-clock sync
    always_ff @(posedge rclk or posedge rrst) begin
        if (rrst) begin
            write_ptr_sync_stage1 <= {ADDR_WIDTH{1'b0}};
            write_ptr_sync_stage2 <= {ADDR_WIDTH{1'b0}};
        end else begin
            write_ptr_sync_stage1 <= write_ptr;
            write_ptr_sync_stage2 <= write_ptr_sync_stage1;
        end
    end

    // Write clock domain cross-clock sync
    always_ff @(posedge wclk or posedge wrst) begin
        if (wrst) begin
            read_ptr_sync_stage1 <= {ADDR_WIDTH{1'b0}};
            read_ptr_sync_stage2 <= {ADDR_WIDTH{1'b0}};
        end else begin
            read_ptr_sync_stage1 <= read_ptr;
            read_ptr_sync_stage2 <= read_ptr_sync_stage1;
        end
    end

    // Write logic
    always_ff @(posedge wclk or posedge wrst) begin
        if (wrst) begin
            // Reset memory
            for (int i = 0; i < FIFO_DEPTH; i++)
                fifo_memory[i] <= {DATA_WIDTH{1'b0}};
            
            write_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (write_enable) begin
            // Write data and update pointer
            fifo_memory[write_ptr[ADDR_WIDTH-2:0]] <= FIFO_in;
            write_ptr <= write_ptr + {{ADDR_WIDTH-1{1'b0}}, 1'b1};
        end
    end

    // Read logic
    always_ff @(posedge rclk or posedge rrst) begin
        if (rrst) begin
            read_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (rpop && !rempty) begin
            read_ptr <= read_ptr + {{ADDR_WIDTH-1{1'b0}}, 1'b1};
        end
    end

endmodule