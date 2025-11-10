module jbUnit(
    input  [31:0] src1,
    input  [31:0] src2,
    output logic [31:0] jbTarget
);

    // ------------------------------------------------------------
    // Compute jump/branch target (aligned to word boundary)
    // ------------------------------------------------------------
    assign jbTarget = (src1 + src2) & (~32'd3);

endmodule
