`include "../include/AXI_define.svh"
`include "../src/CPU_wrapper.sv"
`include "../src/SRAM_wrapper.sv"
`include "../src/ROM_wrapper.sv"
`include "../src/DRAM_wrapper.sv"
`include "../src/DMA_wrapper.sv"
`include "../src/WDT_wrapper.sv"
`include "../src/AXI/AXI.sv"

module top(

	input							clk,
	input							rst,
	input							clk2,
	input							rst2,

    // ROM Interface
	output							ROM_enable,
	output							ROM_read,
	output	[11:0]					ROM_address,
    input	[`AXI_DATA_BITS-1:0]	ROM_out,


    // DRAM Interface
    output							DRAM_CSn,
    output	[`AXI_STRB_BITS-1:0]	DRAM_WEn,
    output							DRAM_RASn,
    output							DRAM_CASn,
    output	[10:0]					DRAM_A,
    output	[`AXI_DATA_BITS-1:0]	DRAM_D,
	input 	[`AXI_DATA_BITS-1:0]	DRAM_Q,
	input 							DRAM_valid
);

	// ============================================================
	// Local Parameters
	// ============================================================
	localparam int NUM_M     = 3;
    localparam int NUM_S     = 6;
    localparam int MIDX_BITS = 3;
    localparam int SIDX_BITS = 2;

	// ============================================================
	// Interrupt Signals
	// ============================================================
	logic          DMA_interrupt;
	logic          WTO_interrupt;

	// ============================================================
	// Packed AXI Signals
	// ============================================================
	logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   ARID_M;
    logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0] ARADDR_M;
    logic [NUM_M-1:0][`AXI_LEN_BITS-1:0]  ARLEN_M;
    logic [NUM_M-1:0][`AXI_SIZE_BITS-1:0] ARSIZE_M;
    logic [NUM_M-1:0][1:0]                ARBURST_M;
    logic [NUM_M-1:0]                     ARVALID_M;
    logic [NUM_M-1:0]                     ARREADY_M;

    logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   RID_M;
    logic [NUM_M-1:0][`AXI_DATA_BITS-1:0] RDATA_M;
    logic [NUM_M-1:0][1:0]                RRESP_M;
    logic [NUM_M-1:0]                     RLAST_M;
    logic [NUM_M-1:0]                     RVALID_M;
    logic [NUM_M-1:0]                     RREADY_M;

    logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  ARID_S;
    logic [NUM_S-1:0][`AXI_ADDR_BITS-1:0] ARADDR_S;
    logic [NUM_S-1:0][`AXI_LEN_BITS-1:0]  ARLEN_S;
    logic [NUM_S-1:0][`AXI_SIZE_BITS-1:0] ARSIZE_S;
    logic [NUM_S-1:0][1:0]                ARBURST_S;
    logic [NUM_S-1:0]                     ARVALID_S;
    logic [NUM_S-1:0]                     ARREADY_S;

    logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  RID_S;
    logic [NUM_S-1:0][`AXI_DATA_BITS-1:0] RDATA_S;
    logic [NUM_S-1:0][1:0]                RRESP_S;
    logic [NUM_S-1:0]                     RLAST_S;
    logic [NUM_S-1:0]                     RVALID_S;
    logic [NUM_S-1:0]                     RREADY_S;

    logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   AWID_M;
    logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0] AWADDR_M;
    logic [NUM_M-1:0][`AXI_LEN_BITS-1:0]  AWLEN_M;
    logic [NUM_M-1:0][`AXI_SIZE_BITS-1:0] AWSIZE_M;
    logic [NUM_M-1:0][1:0]                AWBURST_M;
    logic [NUM_M-1:0]                     AWVALID_M;
    logic [NUM_M-1:0]                     AWREADY_M;

    logic [NUM_M-1:0][`AXI_DATA_BITS-1:0] WDATA_M;
    logic [NUM_M-1:0][`AXI_STRB_BITS-1:0] WSTRB_M;
    logic [NUM_M-1:0]                     WLAST_M;
    logic [NUM_M-1:0]                     WVALID_M;
    logic [NUM_M-1:0]                     WREADY_M;

    logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   BID_M;
    logic [NUM_M-1:0][1:0]                BRESP_M;
    logic [NUM_M-1:0]                     BVALID_M;
    logic [NUM_M-1:0]                     BREADY_M;

	logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  AWID_S;
    logic [NUM_S-1:0][`AXI_ADDR_BITS-1:0] AWADDR_S;
    logic [NUM_S-1:0][`AXI_LEN_BITS-1:0]  AWLEN_S;
    logic [NUM_S-1:0][`AXI_SIZE_BITS-1:0] AWSIZE_S;
    logic [NUM_S-1:0][1:0]                AWBURST_S;
    logic [NUM_S-1:0]                     AWVALID_S;
    logic [NUM_S-1:0]                     AWREADY_S;

    logic [NUM_S-1:0][`AXI_DATA_BITS-1:0] WDATA_S;
    logic [NUM_S-1:0][`AXI_STRB_BITS-1:0] WSTRB_S;
    logic [NUM_S-1:0]                     WLAST_S;
    logic [NUM_S-1:0]                     WVALID_S;
    logic [NUM_S-1:0]                     WREADY_S;

    logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  BID_S;
    logic [NUM_S-1:0][1:0]                BRESP_S;
    logic [NUM_S-1:0]                     BVALID_S;
    logic [NUM_S-1:0]                     BREADY_S;

	// ============================================================
	// Master 0 Write Channel Default Assignment
	// ============================================================
	assign AWID_M[0]    = `AXI_ID_BITS'd0;
	assign AWADDR_M[0]  = `AXI_ADDR_BITS'd0;
	assign AWLEN_M[0]   = `AXI_LEN_BITS'd0;
	assign AWSIZE_M[0]  = `AXI_SIZE_BITS'd0;
	assign AWBURST_M[0] = 2'd0;
	assign AWVALID_M[0] = 1'b0;

	assign WDATA_M[0]   = `AXI_DATA_BITS'd0;
	assign WSTRB_M[0]   = `AXI_STRB_BITS'd0;
	assign WLAST_M[0]   = 1'b0;
	assign WVALID_M[0]  = 1'b0;

	assign BREADY_M[0]  = 1'b0;

	// ============================================================
	// Module Instance
	// ============================================================
	CPU_wrapper CPU_wrapper(
		.clk            (clk                ),
		.rst            (rst                ),

		// interrupt
		.DMA_interrupt  (DMA_interrupt     ),
		.WTO_interrupt  (WTO_interrupt     ),

        // Master 0
		.ARID_M0        (ARID_M[0]         ),
		.ARADDR_M0      (ARADDR_M[0]       ),
		.ARLEN_M0       (ARLEN_M[0]        ),
		.ARSIZE_M0      (ARSIZE_M[0]       ),
		.ARBURST_M0     (ARBURST_M[0]      ),
		.ARVALID_M0     (ARVALID_M[0]      ),
		.ARREADY_M0     (ARREADY_M[0]      ),

		.RID_M0         (RID_M[0]          ),
		.RDATA_M0       (RDATA_M[0]        ),
		.RRESP_M0       (RRESP_M[0]        ),
		.RLAST_M0       (RLAST_M[0]        ),
		.RVALID_M0      (RVALID_M[0]       ),
		.RREADY_M0      (RREADY_M[0]       ),

        // Master 1
		.ARID_M1        (ARID_M[1]         ),
		.ARADDR_M1      (ARADDR_M[1]       ),
		.ARLEN_M1       (ARLEN_M[1]        ),
		.ARSIZE_M1      (ARSIZE_M[1]       ),
		.ARBURST_M1     (ARBURST_M[1]      ),
		.ARVALID_M1     (ARVALID_M[1]      ),
		.ARREADY_M1     (ARREADY_M[1]      ),

		.RID_M1         (RID_M[1]          ),
		.RDATA_M1       (RDATA_M[1]        ),
		.RRESP_M1       (RRESP_M[1]        ),
		.RLAST_M1       (RLAST_M[1]        ),
		.RVALID_M1      (RVALID_M[1]       ),
		.RREADY_M1      (RREADY_M[1]       ),

		.AWID_M1        (AWID_M[1]         ),
		.AWADDR_M1      (AWADDR_M[1]       ),
		.AWLEN_M1       (AWLEN_M[1]        ),
		.AWSIZE_M1      (AWSIZE_M[1]       ),
		.AWBURST_M1     (AWBURST_M[1]      ),
		.AWVALID_M1     (AWVALID_M[1]      ),
		.AWREADY_M1     (AWREADY_M[1]      ),

		.WDATA_M1       (WDATA_M[1]        ),
		.WSTRB_M1       (WSTRB_M[1]        ),
		.WLAST_M1       (WLAST_M[1]        ),
		.WVALID_M1      (WVALID_M[1]       ),
		.WREADY_M1      (WREADY_M[1]       ),

		.BID_M1         (BID_M[1]          ),
		.BRESP_M1       (BRESP_M[1]        ),
		.BVALID_M1      (BVALID_M[1]       ),
		.BREADY_M1      (BREADY_M[1]       )
	);

	ROM_wrapper ROM_wrapper(
		.clk			(clk				),
		.rst			(rst     			),

		.ARID_S			(ARID_S[0]			),
		.ARADDR_S		(ARADDR_S[0]		),
		.ARLEN_S		(ARLEN_S[0]			),
		.ARSIZE_S		(ARSIZE_S[0]		),
		.ARBURST_S		(ARBURST_S[0]		),
		.ARVALID_S		(ARVALID_S[0]		),
		.ARREADY_S		(ARREADY_S[0]		),

		.RID_S			(RID_S[0]			),
		.RDATA_S		(RDATA_S[0]			),
		.RRESP_S		(RRESP_S[0]			),
		.RLAST_S		(RLAST_S[0]			),
		.RVALID_S		(RVALID_S[0]		),
		.RREADY_S		(RREADY_S[0]		),

		.AWID_S			(AWID_S[0]			),
		.AWADDR_S		(AWADDR_S[0]		),
		.AWLEN_S		(AWLEN_S[0]			),
		.AWSIZE_S		(AWSIZE_S[0]		),
		.AWBURST_S		(AWBURST_S[0]		),
		.AWVALID_S		(AWVALID_S[0]		),
		.AWREADY_S		(AWREADY_S[0]		),

		.WDATA_S		(WDATA_S[0]			),
		.WSTRB_S		(WSTRB_S[0]			),
		.WLAST_S		(WLAST_S[0]			),
		.WVALID_S		(WVALID_S[0]		),
		.WREADY_S		(WREADY_S[0]		),

		.BID_S			(BID_S[0]			),
		.BRESP_S		(BRESP_S[0]			),
		.BVALID_S		(BVALID_S[0]		),
		.BREADY_S		(BREADY_S[0]		),

		// ROM Interface
		.ROM_enable		(ROM_enable			),
		.ROM_read		(ROM_read			),
		.ROM_address	(ROM_address		),
		.ROM_out		(ROM_out			)
	);

	SRAM_wrapper IM1(
		.clk			(clk				),
		.rst			(rst     			),

		.ARID_S			(ARID_S[1]			),
		.ARADDR_S		(ARADDR_S[1]		),
		.ARLEN_S		(ARLEN_S[1]			),
		.ARSIZE_S		(ARSIZE_S[1]		),
		.ARBURST_S		(ARBURST_S[1]		),
		.ARVALID_S		(ARVALID_S[1]		),
		.ARREADY_S		(ARREADY_S[1]		),

		.RID_S			(RID_S[1]			),
		.RDATA_S		(RDATA_S[1]			),
		.RRESP_S		(RRESP_S[1]			),
		.RLAST_S		(RLAST_S[1]			),
		.RVALID_S		(RVALID_S[1]		),
		.RREADY_S		(RREADY_S[1]		),

		.AWID_S			(AWID_S[1]			),
		.AWADDR_S		(AWADDR_S[1]		),
		.AWLEN_S		(AWLEN_S[1]			),
		.AWSIZE_S		(AWSIZE_S[1]		),
		.AWBURST_S		(AWBURST_S[1]		),
		.AWVALID_S		(AWVALID_S[1]		),
		.AWREADY_S		(AWREADY_S[1]		),

		.WDATA_S		(WDATA_S[1]			),
		.WSTRB_S		(WSTRB_S[1]			),
		.WLAST_S		(WLAST_S[1]			),
		.WVALID_S		(WVALID_S[1]		),
		.WREADY_S		(WREADY_S[1]		),

		.BID_S			(BID_S[1]			),
		.BRESP_S		(BRESP_S[1]			),
		.BVALID_S		(BVALID_S[1]		),
		.BREADY_S		(BREADY_S[1]		)
	);

	SRAM_wrapper DM1(
		.clk			(clk				),
		.rst			(rst	     		),

		.ARID_S			(ARID_S[2]			),
		.ARADDR_S		(ARADDR_S[2]		),
		.ARLEN_S		(ARLEN_S[2]			),
		.ARSIZE_S		(ARSIZE_S[2]		),
		.ARBURST_S		(ARBURST_S[2]		),
		.ARVALID_S		(ARVALID_S[2]		),
		.ARREADY_S		(ARREADY_S[2]		),

		.RID_S			(RID_S[2]			),
		.RDATA_S		(RDATA_S[2]			),
		.RRESP_S		(RRESP_S[2]			),
		.RLAST_S		(RLAST_S[2]			),
		.RVALID_S		(RVALID_S[2]		),
		.RREADY_S		(RREADY_S[2]		),

		.AWID_S			(AWID_S[2]			),
		.AWADDR_S		(AWADDR_S[2]		),
		.AWLEN_S		(AWLEN_S[2]			),
		.AWSIZE_S		(AWSIZE_S[2]		),
		.AWBURST_S		(AWBURST_S[2]		),
		.AWVALID_S		(AWVALID_S[2]		),
		.AWREADY_S		(AWREADY_S[2]		),

		.WDATA_S		(WDATA_S[2]			),
		.WSTRB_S		(WSTRB_S[2]			),
		.WLAST_S		(WLAST_S[2]			),
		.WVALID_S		(WVALID_S[2]		),
		.WREADY_S		(WREADY_S[2]		),

		.BID_S			(BID_S[2]			),
		.BRESP_S		(BRESP_S[2]			),
		.BVALID_S		(BVALID_S[2]		),
		.BREADY_S		(BREADY_S[2]		)
	);

	DMA_wrapper DMA_wrapper(
		.clk            (clk                ),
		.rst            (rst                ),

		// Master 2
		.ARID_M2        (ARID_M[2]          ),
		.ARADDR_M2      (ARADDR_M[2]        ),
		.ARLEN_M2       (ARLEN_M[2]         ),
		.ARSIZE_M2      (ARSIZE_M[2]        ),
		.ARBURST_M2     (ARBURST_M[2]       ),
		.ARVALID_M2     (ARVALID_M[2]       ),
		.ARREADY_M2     (ARREADY_M[2]       ),

		.RID_M2         (RID_M[2]           ),
		.RDATA_M2       (RDATA_M[2]         ),
		.RRESP_M2       (RRESP_M[2]         ),
		.RLAST_M2       (RLAST_M[2]         ),
		.RVALID_M2      (RVALID_M[2]        ),
		.RREADY_M2      (RREADY_M[2]        ),

		.AWID_M2        (AWID_M[2]          ),
		.AWADDR_M2      (AWADDR_M[2]        ),
		.AWLEN_M2       (AWLEN_M[2]         ),
		.AWSIZE_M2      (AWSIZE_M[2]        ),
		.AWBURST_M2     (AWBURST_M[2]       ),
		.AWVALID_M2     (AWVALID_M[2]       ),
		.AWREADY_M2     (AWREADY_M[2]       ),

		.WDATA_M2       (WDATA_M[2]         ),
		.WSTRB_M2       (WSTRB_M[2]         ),
		.WLAST_M2       (WLAST_M[2]         ),
		.WVALID_M2      (WVALID_M[2]        ),
		.WREADY_M2      (WREADY_M[2]        ),

		.BID_M2         (BID_M[2]           ),
		.BRESP_M2       (BRESP_M[2]         ),
		.BVALID_M2      (BVALID_M[2]        ),
		.BREADY_M2      (BREADY_M[2]        ),

		// Slave 3
		.ARID_S3        (ARID_S[3]          ),
		.ARADDR_S3      (ARADDR_S[3]        ),
		.ARLEN_S3       (ARLEN_S[3]         ),
		.ARSIZE_S3      (ARSIZE_S[3]        ),
		.ARBURST_S3     (ARBURST_S[3]       ),
		.ARVALID_S3     (ARVALID_S[3]       ),
		.ARREADY_S3     (ARREADY_S[3]       ),

		.RREADY_S3      (RREADY_S[3]        ),
		.RID_S3         (RID_S[3]           ),
		.RDATA_S3       (RDATA_S[3]         ),
		.RRESP_S3       (RRESP_S[3]         ),
		.RLAST_S3       (RLAST_S[3]         ),
		.RVALID_S3      (RVALID_S[3]        ),

		.AWID_S3        (AWID_S[3]          ),
		.AWADDR_S3      (AWADDR_S[3]        ),
		.AWLEN_S3       (AWLEN_S[3]         ),
		.AWSIZE_S3      (AWSIZE_S[3]        ),
		.AWBURST_S3     (AWBURST_S[3]       ),
		.AWVALID_S3     (AWVALID_S[3]       ),
		.AWREADY_S3     (AWREADY_S[3]       ),

		.WDATA_S3       (WDATA_S[3]         ),
		.WSTRB_S3       (WSTRB_S[3]         ),
		.WLAST_S3       (WLAST_S[3]         ),
		.WVALID_S3      (WVALID_S[3]        ),
		.WREADY_S3      (WREADY_S[3]        ),

		.BREADY_S3      (BREADY_S[3]        ),
		.BID_S3         (BID_S[3]           ),
		.BRESP_S3       (BRESP_S[3]         ),
		.BVALID_S3      (BVALID_S[3]        ),

		.DMA_interrupt  (DMA_interrupt      )
	);

	WDT_wrapper WDT_wrapper(
		.clk           (clk             ),
		.rst           (rst             ),
		.clk2          (clk2            ),
		.rst2          (rst2            ),

		.ARID_S        (ARID_S[4]       ),
		.ARADDR_S      (ARADDR_S[4]     ),
		.ARLEN_S       (ARLEN_S[4]      ),
		.ARSIZE_S      (ARSIZE_S[4]     ),
		.ARBURST_S     (ARBURST_S[4]    ),
		.ARVALID_S     (ARVALID_S[4]    ),
		.ARREADY_S     (ARREADY_S[4]    ),

		.RID_S         (RID_S[4]        ),
		.RDATA_S       (RDATA_S[4]      ),
		.RRESP_S       (RRESP_S[4]      ),
		.RLAST_S       (RLAST_S[4]      ),
		.RVALID_S      (RVALID_S[4]     ),
		.RREADY_S      (RREADY_S[4]     ),

		.AWID_S        (AWID_S[4]       ),
		.AWADDR_S      (AWADDR_S[4]     ),
		.AWLEN_S       (AWLEN_S[4]      ),
		.AWSIZE_S      (AWSIZE_S[4]     ),
		.AWBURST_S     (AWBURST_S[4]    ),
		.AWVALID_S     (AWVALID_S[4]    ),
		.AWREADY_S     (AWREADY_S[4]    ),

		.WDATA_S       (WDATA_S[4]      ),
		.WSTRB_S       (WSTRB_S[4]      ),
		.WLAST_S       (WLAST_S[4]      ),
		.WVALID_S      (WVALID_S[4]     ),
		.WREADY_S      (WREADY_S[4]     ),

		.BID_S         (BID_S[4]        ),
		.BRESP_S       (BRESP_S[4]      ),
		.BVALID_S      (BVALID_S[4]     ),
		.BREADY_S      (BREADY_S[4]     ),

		.WTO_interrupt (WTO_interrupt   )
	);

	DRAM_wrapper DRAM_wrapper(
		.clk         (clk           ),
		.rst         (rst           ),

		.ARID_S      (ARID_S[5]     ),
		.ARADDR_S    (ARADDR_S[5]   ),
		.ARLEN_S     (ARLEN_S[5]    ),
		.ARSIZE_S    (ARSIZE_S[5]   ),
		.ARBURST_S   (ARBURST_S[5]  ),
		.ARVALID_S   (ARVALID_S[5]  ),
		.ARREADY_S   (ARREADY_S[5]  ),

		.RID_S       (RID_S[5]      ),
		.RDATA_S     (RDATA_S[5]    ),
		.RRESP_S     (RRESP_S[5]    ),
		.RLAST_S     (RLAST_S[5]    ),
		.RVALID_S    (RVALID_S[5]   ),
		.RREADY_S    (RREADY_S[5]   ),

		.AWID_S      (AWID_S[5]     ),
		.AWADDR_S    (AWADDR_S[5]   ),
		.AWLEN_S     (AWLEN_S[5]    ),
		.AWSIZE_S    (AWSIZE_S[5]   ),
		.AWBURST_S   (AWBURST_S[5]  ),
		.AWVALID_S   (AWVALID_S[5]  ),
		.AWREADY_S   (AWREADY_S[5]  ),

		.WDATA_S     (WDATA_S[5]    ),
		.WSTRB_S     (WSTRB_S[5]    ),
		.WLAST_S     (WLAST_S[5]    ),
		.WVALID_S    (WVALID_S[5]   ),
		.WREADY_S    (WREADY_S[5]   ),

		.BID_S       (BID_S[5]      ),
		.BRESP_S     (BRESP_S[5]    ),
		.BVALID_S    (BVALID_S[5]   ),
		.BREADY_S    (BREADY_S[5]   ),

		.DRAM_CSn    (DRAM_CSn      ),
		.DRAM_WEn    (DRAM_WEn      ),
		.DRAM_RASn   (DRAM_RASn     ),
		.DRAM_CASn   (DRAM_CASn     ),
		.DRAM_A      (DRAM_A        ),
		.DRAM_D      (DRAM_D        ),
		.DRAM_Q      (DRAM_Q        ),
		.DRAM_valid  (DRAM_valid    )
	);

	AXI #(
		.NUM_M     	(NUM_M		   ),
    	.NUM_S     	(NUM_S		   ),
    	.MIDX_BITS  (MIDX_BITS	   ),
    	.SIDX_BITS 	(SIDX_BITS	   )
	) AXI (
		.clk       	(clk           ),
		.rst    	(rst           ),

		.ARID_M     (ARID_M        ),
		.ARADDR_M   (ARADDR_M      ),
		.ARLEN_M    (ARLEN_M       ),
		.ARSIZE_M   (ARSIZE_M      ),
		.ARBURST_M  (ARBURST_M     ),
		.ARVALID_M  (ARVALID_M     ),
		.ARREADY_M  (ARREADY_M     ),

		.RID_M      (RID_M         ),
		.RDATA_M    (RDATA_M       ),
		.RRESP_M    (RRESP_M       ),
		.RLAST_M    (RLAST_M       ),
		.RVALID_M   (RVALID_M      ),
		.RREADY_M   (RREADY_M      ),

		.ARID_S     (ARID_S        ),
		.ARADDR_S   (ARADDR_S      ),
		.ARLEN_S    (ARLEN_S       ),
		.ARSIZE_S   (ARSIZE_S      ),
		.ARBURST_S  (ARBURST_S     ),
		.ARVALID_S  (ARVALID_S     ),
		.ARREADY_S  (ARREADY_S     ),

		.RID_S      (RID_S         ),
		.RDATA_S    (RDATA_S       ),
		.RRESP_S    (RRESP_S       ),
		.RLAST_S    (RLAST_S       ),
		.RVALID_S   (RVALID_S      ),
		.RREADY_S   (RREADY_S      ),

		.AWID_M     (AWID_M        ),
		.AWADDR_M   (AWADDR_M      ),
		.AWLEN_M    (AWLEN_M       ),
		.AWSIZE_M   (AWSIZE_M      ),
		.AWBURST_M  (AWBURST_M     ),
		.AWVALID_M  (AWVALID_M     ),
		.AWREADY_M  (AWREADY_M     ),

		.WDATA_M    (WDATA_M       ),
		.WSTRB_M    (WSTRB_M       ),
		.WLAST_M    (WLAST_M       ),
		.WVALID_M   (WVALID_M      ),
		.WREADY_M   (WREADY_M      ),

		.BID_M      (BID_M         ),
		.BRESP_M    (BRESP_M       ),
		.BVALID_M   (BVALID_M      ),
		.BREADY_M   (BREADY_M      ),

		.AWID_S     (AWID_S        ),
		.AWADDR_S   (AWADDR_S      ),
		.AWLEN_S    (AWLEN_S       ),
		.AWSIZE_S   (AWSIZE_S      ),
		.AWBURST_S  (AWBURST_S     ),
		.AWVALID_S  (AWVALID_S     ),
		.AWREADY_S  (AWREADY_S     ),

		.WDATA_S    (WDATA_S       ),
		.WSTRB_S    (WSTRB_S       ),
		.WLAST_S    (WLAST_S       ),
		.WVALID_S   (WVALID_S      ),
		.WREADY_S   (WREADY_S      ),

		.BID_S      (BID_S         ),
		.BRESP_S    (BRESP_S       ),
		.BVALID_S   (BVALID_S      ),
		.BREADY_S   (BREADY_S      )
	);


endmodule