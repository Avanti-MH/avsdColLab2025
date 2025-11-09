//////////////////////////////////////////////////////////////////////
//          ██╗       ██████╗   ██╗  ██╗    ██████╗            		//
//          ██║       ██╔══█║   ██║  ██║    ██╔══█║            		//
//          ██║       ██████║   ███████║    ██████║            		//
//          ██║       ██╔═══╝   ██╔══██║    ██╔═══╝            		//
//          ███████╗  ██║  	    ██║  ██║    ██║  	           		//
//          ╚══════╝  ╚═╝  	    ╚═╝  ╚═╝    ╚═╝  	           		//
//                                                             		//
// 	2025 Advanced VLSI System Design, advisor: Lih-Yih, Chiou		//
//                                                             		//
//////////////////////////////////////////////////////////////////////
//                                                             		//
// 	Autor: 			TZUNG-JIN, TSAI (Leo)				  	   		//
//	Filename:		 AXI.sv			                            	//
//	Description:	Top module of AXI	 							//
// 	Version:		1.0	    								   		//
//////////////////////////////////////////////////////////////////////
`include "../include/AXI_define.svh"
`include "../src/AXI/Arbiter.sv"
`include "../src/AXI/DefaultSlave.sv"
`include "../src/AXI/Decoder.sv"
`include "../src/AXI/Read.sv"
`include "../src/AXI/Write.sv"

module AXI #(
    parameter int NUM_M     = 3,
    parameter int NUM_S     = 6,
    parameter int MIDX_BITS = 2,
    parameter int SIDX_BITS = 3
)(
    input  logic clk,
    input  logic rst,

    // ========================================================
    // Master
    // ========================================================

    // -------------------- READ CHANNEL ----------------------
    input  logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   ARID_M,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0] ARADDR_M,
    input  logic [NUM_M-1:0][`AXI_LEN_BITS-1:0]  ARLEN_M,
    input  logic [NUM_M-1:0][`AXI_SIZE_BITS-1:0] ARSIZE_M,
    input  logic [NUM_M-1:0][1:0]                ARBURST_M,
    input  logic [NUM_M-1:0]                     ARVALID_M,
    output logic [NUM_M-1:0]                     ARREADY_M,

    output logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   RID_M,
    output logic [NUM_M-1:0][`AXI_DATA_BITS-1:0] RDATA_M,
    output logic [NUM_M-1:0][1:0]                RRESP_M,
    output logic [NUM_M-1:0]                     RLAST_M,
    output logic [NUM_M-1:0]                     RVALID_M,
    input  logic [NUM_M-1:0]                     RREADY_M,

    // -------------------- WRITE CHANNEL ---------------------
    input  logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   AWID_M,
    input  logic [NUM_M-1:0][`AXI_ADDR_BITS-1:0] AWADDR_M,
    input  logic [NUM_M-1:0][`AXI_LEN_BITS-1:0]  AWLEN_M,
    input  logic [NUM_M-1:0][`AXI_SIZE_BITS-1:0] AWSIZE_M,
    input  logic [NUM_M-1:0][1:0]                AWBURST_M,
    input  logic [NUM_M-1:0]                     AWVALID_M,
    output logic [NUM_M-1:0]                     AWREADY_M,

    input  logic [NUM_M-1:0][`AXI_DATA_BITS-1:0] WDATA_M,
    input  logic [NUM_M-1:0][`AXI_STRB_BITS-1:0] WSTRB_M,
    input  logic [NUM_M-1:0]                     WLAST_M,
    input  logic [NUM_M-1:0]                     WVALID_M,
    output logic [NUM_M-1:0]                     WREADY_M,

    output logic [NUM_M-1:0][`AXI_ID_BITS-1:0]   BID_M,
    output logic [NUM_M-1:0][1:0]                BRESP_M,
    output logic [NUM_M-1:0]                     BVALID_M,
    input  logic [NUM_M-1:0]                     BREADY_M,



    // ========================================================
    // Slave
    // ========================================================

    // -------------------- READ CHANNEL ----------------------
    output logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  ARID_S,
    output logic [NUM_S-1:0][`AXI_ADDR_BITS-1:0] ARADDR_S,
    output logic [NUM_S-1:0][`AXI_LEN_BITS-1:0]  ARLEN_S,
    output logic [NUM_S-1:0][`AXI_SIZE_BITS-1:0] ARSIZE_S,
    output logic [NUM_S-1:0][1:0]                ARBURST_S,
    output logic [NUM_S-1:0]                     ARVALID_S,
    input  logic [NUM_S-1:0]                     ARREADY_S,

    input  logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  RID_S,
    input  logic [NUM_S-1:0][`AXI_DATA_BITS-1:0] RDATA_S,
    input  logic [NUM_S-1:0][1:0]                RRESP_S,
    input  logic [NUM_S-1:0]                     RLAST_S,
    input  logic [NUM_S-1:0]                     RVALID_S,
    output logic [NUM_S-1:0]                     RREADY_S,

    // -------------------- WRITE CHANNEL ---------------------
    output logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  AWID_S,
    output logic [NUM_S-1:0][`AXI_ADDR_BITS-1:0] AWADDR_S,
    output logic [NUM_S-1:0][`AXI_LEN_BITS-1:0]  AWLEN_S,
    output logic [NUM_S-1:0][`AXI_SIZE_BITS-1:0] AWSIZE_S,
    output logic [NUM_S-1:0][1:0]                AWBURST_S,
    output logic [NUM_S-1:0]                     AWVALID_S,
    input  logic [NUM_S-1:0]                     AWREADY_S,

    output logic [NUM_S-1:0][`AXI_DATA_BITS-1:0] WDATA_S,
    output logic [NUM_S-1:0][`AXI_STRB_BITS-1:0] WSTRB_S,
    output logic [NUM_S-1:0]                     WLAST_S,
    output logic [NUM_S-1:0]                     WVALID_S,
    input  logic [NUM_S-1:0]                     WREADY_S,

    input  logic [NUM_S-1:0][`AXI_IDS_BITS-1:0]  BID_S,
    input  logic [NUM_S-1:0][1:0]                BRESP_S,
    input  logic [NUM_S-1:0]                     BVALID_S,
    output logic [NUM_S-1:0]                     BREADY_S

);

	// ============================================================
    // Local Signals
    // ============================================================

    // ------------------------------------------------------------
    // Request Signals
    // ------------------------------------------------------------
    logic [NUM_S:0][NUM_M-1:0] R_REQ;
    logic [NUM_S:0][NUM_M-1:0] W_REQ;

    // ------------------------------------------------------------
    // Index Arrays
    // ------------------------------------------------------------
    // Slave Indices
    logic [MIDX_BITS-1:0] SRIdx [NUM_S:0];
    logic [MIDX_BITS-1:0] SWIdx [NUM_S:0];

    // Master Indices
    logic [SIDX_BITS-1:0] MRIdx [NUM_M-1:0];
    logic [SIDX_BITS-1:0] MWIdx [NUM_M-1:0];

	// ============================================================
	// Default Slave Signals and Instance (Slave 6)
	// ============================================================
    // AR
	logic [`AXI_IDS_BITS-1:0]   ARID_DEFAULT;
	logic [`AXI_ADDR_BITS-1:0]  ARADDR_DEFAULT;
	logic [`AXI_LEN_BITS-1:0]   ARLEN_DEFAULT;
	logic [`AXI_SIZE_BITS-1:0]  ARSIZE_DEFAULT;
	logic [1:0]                 ARBURST_DEFAULT;
	logic                       ARVALID_DEFAULT;
	logic                       ARREADY_DEFAULT;
    // R
	logic [`AXI_IDS_BITS-1:0]   RID_DEFAULT;
	logic [`AXI_DATA_BITS-1:0]  RDATA_DEFAULT;
	logic [1:0]                 RRESP_DEFAULT;
	logic                       RLAST_DEFAULT;
	logic                       RVALID_DEFAULT;
	logic                       RREADY_DEFAULT;
    // AW
	logic [`AXI_IDS_BITS-1:0]   AWID_DEFAULT;
	logic [`AXI_ADDR_BITS-1:0]  AWADDR_DEFAULT;
	logic [`AXI_LEN_BITS-1:0]   AWLEN_DEFAULT;
	logic [`AXI_SIZE_BITS-1:0]  AWSIZE_DEFAULT;
	logic [1:0]                 AWBURST_DEFAULT;
	logic                       AWVALID_DEFAULT;
	logic                       AWREADY_DEFAULT;
    // W
	logic [`AXI_DATA_BITS-1:0]  WDATA_DEFAULT;
	logic [`AXI_STRB_BITS-1:0]  WSTRB_DEFAULT;
	logic                       WLAST_DEFAULT;
	logic                       WVALID_DEFAULT;
	logic                       WREADY_DEFAULT;
    // B
	logic [`AXI_IDS_BITS-1:0]   BID_DEFAULT;
	logic [1:0]                 BRESP_DEFAULT;
	logic                       BVALID_DEFAULT;
	logic                       BREADY_DEFAULT;

	// ---------------------------------------
	// Default Slave Instance
	// ---------------------------------------
	DefaultSlave uDefaultSlave(
		.clk             (clk             ),
		.rst             (rst             ),

		.ARID_DEFAULT    (ARID_DEFAULT    ),
		.ARADDR_DEFAULT  (ARADDR_DEFAULT  ),
		.ARLEN_DEFAULT   (ARLEN_DEFAULT   ),
		.ARSIZE_DEFAULT  (ARSIZE_DEFAULT  ),
		.ARBURST_DEFAULT (ARBURST_DEFAULT ),
		.ARVALID_DEFAULT (ARVALID_DEFAULT ),
		.ARREADY_DEFAULT (ARREADY_DEFAULT ),

		.RID_DEFAULT     (RID_DEFAULT     ),
		.RDATA_DEFAULT   (RDATA_DEFAULT   ),
		.RRESP_DEFAULT   (RRESP_DEFAULT   ),
		.RLAST_DEFAULT   (RLAST_DEFAULT   ),
		.RVALID_DEFAULT  (RVALID_DEFAULT  ),
		.RREADY_DEFAULT  (RREADY_DEFAULT  ),

		.AWID_DEFAULT    (AWID_DEFAULT    ),
		.AWADDR_DEFAULT  (AWADDR_DEFAULT  ),
		.AWLEN_DEFAULT   (AWLEN_DEFAULT   ),
		.AWSIZE_DEFAULT  (AWSIZE_DEFAULT  ),
		.AWBURST_DEFAULT (AWBURST_DEFAULT ),
		.AWVALID_DEFAULT (AWVALID_DEFAULT ),
		.AWREADY_DEFAULT (AWREADY_DEFAULT ),

		.WDATA_DEFAULT   (WDATA_DEFAULT   ),
		.WSTRB_DEFAULT   (WSTRB_DEFAULT   ),
		.WLAST_DEFAULT   (WLAST_DEFAULT   ),
		.WVALID_DEFAULT  (WVALID_DEFAULT  ),
		.WREADY_DEFAULT  (WREADY_DEFAULT  ),

		.BID_DEFAULT     (BID_DEFAULT     ),
		.BRESP_DEFAULT   (BRESP_DEFAULT   ),
		.BVALID_DEFAULT  (BVALID_DEFAULT  ),
		.BREADY_DEFAULT  (BREADY_DEFAULT  )
	);

    // ============================================================
	// Decoder
	// ============================================================
	Decoder #(
		.NUM_M           (NUM_M          ),
		.NUM_S           (NUM_S          )
    ) req_decoder (
		.ARVALID_M       (ARVALID_M      ),
		.AWVALID_M       (AWVALID_M      ),
		.ARADDR_M        (ARADDR_M       ),
		.AWADDR_M        (AWADDR_M       ),
		.R_REQ           (R_REQ          ),
		.W_REQ           (W_REQ          )
	);

    // ============================================================
    // Arbiter
    // ============================================================
    Arbiter #(
        .NUM_M              (NUM_M                       ),
        .NUM_S              (NUM_S                       ),
        .MIDX_BITS          (MIDX_BITS                   ),
        .SIDX_BITS          (SIDX_BITS                   )
    ) uArbiter (
        .clk                (clk                         ),
        .rst                (rst                         ),
        .R_REQ              (R_REQ                       ),
        .W_REQ              (W_REQ                       ),

        .RREADY_M           (RREADY_M                    ),
        .BREADY_M           (BREADY_M                    ),
        .RVALID_S           ({RVALID_DEFAULT, RVALID_S  }),
        .RLAST_S            ({RLAST_DEFAULT , RLAST_S   }),
        .BVALID_S           ({BVALID_DEFAULT, BVALID_S  }),

        .ARREADY_S          ({ARREADY_DEFAULT, ARREADY_S}),
        .AWREADY_S          ({AWREADY_DEFAULT, AWREADY_S}),
        .SRIdx              (SRIdx                       ),
        .SWIdx              (SWIdx                       ),
        .MRIdx              (MRIdx                       ),
        .MWIdx              (MWIdx                       )
    );

    // ============================================================
    // Read Channel
    // ============================================================
    Read #(
        .NUM_M              (NUM_M                                          ),
        .NUM_S              (NUM_S                                          ),
        .MIDX_BITS          (MIDX_BITS                                      ),
        .SIDX_BITS          (SIDX_BITS                                      )
    ) uRead (
        .SRIdx              (SRIdx                                          ),
        .MRIdx              (MRIdx                                          ),

        .ARID_M             ({ARID_M    , `AXI_ID_BITS'd0                  }),
        .ARADDR_M           ({ARADDR_M  , `AXI_ADDR_BITS'd0                }),
        .ARLEN_M            ({ARLEN_M   , `AXI_LEN_BITS'd0                 }),
        .ARSIZE_M           ({ARSIZE_M  , `AXI_SIZE_BITS'd0                }),
        .ARBURST_M          ({ARBURST_M , 2'd0                             }),
        .ARVALID_M          ({ARVALID_M , 1'b0                             }),
        .ARREADY_M          (ARREADY_M                                      ),

        .ARID_S             ({ARID_DEFAULT    , ARID_S                     }),
        .ARADDR_S           ({ARADDR_DEFAULT  , ARADDR_S                   }),
        .ARLEN_S            ({ARLEN_DEFAULT   , ARLEN_S                    }),
        .ARSIZE_S           ({ARSIZE_DEFAULT  , ARSIZE_S                   }),
        .ARBURST_S          ({ARBURST_DEFAULT , ARBURST_S                  }),
        .ARVALID_S          ({ARVALID_DEFAULT , ARVALID_S                  }),
        .ARREADY_S          ({ARREADY_DEFAULT , ARREADY_S, 1'd0            }),

        .RID_M              (RID_M                                          ),
        .RDATA_M            (RDATA_M                                        ),
        .RRESP_M            (RRESP_M                                        ),
        .RLAST_M            (RLAST_M                                        ),
        .RVALID_M           (RVALID_M                                       ),
        .RREADY_M           ({RREADY_M , 1'b0                               }),

        .RID_S              ({RID_DEFAULT    , RID_S   , `AXI_IDS_BITS'd0  }),
        .RDATA_S            ({RDATA_DEFAULT  , RDATA_S , `AXI_DATA_BITS'd0 }),
        .RRESP_S            ({RRESP_DEFAULT  , RRESP_S , 2'd0              }),
        .RLAST_S            ({RLAST_DEFAULT  , RLAST_S , 1'd0              }),
        .RVALID_S           ({RVALID_DEFAULT , RVALID_S, 1'd0              }),
        .RREADY_S           ({RREADY_DEFAULT , RREADY_S                    })
    );

    // ============================================================
    // Write Channel
    // ============================================================
    Write #(
        .NUM_M              (NUM_M                                          ),
        .NUM_S              (NUM_S                                          ),
        .MIDX_BITS          (MIDX_BITS                                      ),
        .SIDX_BITS          (SIDX_BITS                                      )
    ) uWrite (
        .SWIdx              (SWIdx                                          ),
        .MWIdx              (MWIdx                                          ),

        .AWID_M             ({AWID_M    , `AXI_ID_BITS'd0                  }),
        .AWADDR_M           ({AWADDR_M  , `AXI_ADDR_BITS'd0                }),
        .AWLEN_M            ({AWLEN_M   , `AXI_LEN_BITS'd0                 }),
        .AWSIZE_M           ({AWSIZE_M  , `AXI_SIZE_BITS'd0                }),
        .AWBURST_M          ({AWBURST_M , 2'd0                             }),
        .AWVALID_M          ({AWVALID_M , 1'b0                             }),
        .AWREADY_M          (AWREADY_M                                      ),

        .AWID_S             ({AWID_DEFAULT    , AWID_S                     }),
        .AWADDR_S           ({AWADDR_DEFAULT  , AWADDR_S                   }),
        .AWLEN_S            ({AWLEN_DEFAULT   , AWLEN_S                    }),
        .AWSIZE_S           ({AWSIZE_DEFAULT  , AWSIZE_S                   }),
        .AWBURST_S          ({AWBURST_DEFAULT , AWBURST_S                  }),
        .AWVALID_S          ({AWVALID_DEFAULT , AWVALID_S                  }),
        .AWREADY_S          ({AWREADY_DEFAULT , AWREADY_S, 1'd0            }),

        .WDATA_M            ({WDATA_M   , `AXI_DATA_BITS'd0                }),
        .WSTRB_M            ({WSTRB_M   , `AXI_STRB_BITS'd0                }),
        .WLAST_M            ({WLAST_M   , 1'b0                             }),
        .WVALID_M           ({WVALID_M  , 1'b0                             }),
        .WREADY_M           (WREADY_M                                       ),

        .WDATA_S            ({WDATA_DEFAULT   , WDATA_S                    }),
        .WSTRB_S            ({WSTRB_DEFAULT   , WSTRB_S                    }),
        .WLAST_S            ({WLAST_DEFAULT   , WLAST_S                    }),
        .WVALID_S           ({WVALID_DEFAULT  , WVALID_S                   }),
        .WREADY_S           ({WREADY_DEFAULT  , WREADY_S , 1'd0            }),

        .BID_M              (BID_M                                          ),
        .BRESP_M            (BRESP_M                                        ),
        .BVALID_M           (BVALID_M                                       ),
        .BREADY_M           ({BREADY_M , 1'b0                              }),

        .BID_S              ({BID_DEFAULT    , BID_S    , `AXI_IDS_BITS'd0 }),
        .BRESP_S            ({BRESP_DEFAULT  , BRESP_S  , 2'd0             }),
        .BVALID_S           ({BVALID_DEFAULT , BVALID_S , 1'd0             }),
        .BREADY_S           ({BREADY_DEFAULT , BREADY_S                    })
    );


endmodule