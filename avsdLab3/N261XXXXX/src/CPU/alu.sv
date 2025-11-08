module alu (
    input  [31:0] src1,
    input  [31:0] src2,
    input  [4:0]  opcode,
    input  [3:0]  func,
    input         is_mtype,
    output logic [31:0] aluOut
);

    // ============================================================
    // Intermediate results
    // ============================================================
    logic [31:0] abs_src1, abs_src2;
    logic [63:0] abs_mul_res, mul_res;
    logic sign;
    logic [31:0] add_4_res, add_res, sub_res, xor_res, or_res, and_res;
    logic [31:0] slt_res, sltu_res, sll_res, srl_res, sra_res;

    // ============================================================
    // Multiplication handling (M-extension)
    // ============================================================
    always_comb begin : multiplication_block
        sign = 1'b0;
        case (func[3:1])
            `FUNC_MULH: begin // signed × signed
                abs_src1 = (src1 ^ {32{src1[31]}}) + {31'd0, src1[31]};
                abs_src2 = (src2 ^ {32{src2[31]}}) + {31'd0, src2[31]};
                sign = src1[31] ^ src2[31];
            end
            `FUNC_MULHSU: begin // signed × unsigned
                abs_src1 = (src1 ^ {32{src1[31]}}) + {31'd0, src1[31]};
                abs_src2 = src2;
                sign = src1[31];
            end
            `FUNC_MUL, `FUNC_MULHU: begin // unsigned × unsigned
                abs_src1 = src1;
                abs_src2 = src2;
            end
            default: begin
                abs_src1 = 32'd0;
                abs_src2 = 32'd0;
            end
        endcase
        abs_mul_res = abs_src1 * abs_src2;
        mul_res = (abs_mul_res ^ {64{sign}}) + {63'd0, sign};
    end

    // ============================================================
    // Standard operation results
    // ============================================================
    always_comb begin : operation_computations
        add_4_res = src1 + 4;
        add_res   = src1 + src2;
        sub_res   = src1 - src2;
        xor_res   = src1 ^ src2;
        or_res    = src1 | src2;
        and_res   = src1 & src2;
        sltu_res  = {31'd0, src1 < src2};
        srl_res   = src1 >> src2[4:0];
        sra_res   = $signed(src1) >>> src2[4:0];
        sll_res   = src1 << src2[4:0];
        slt_res   = {31'd0, $signed(src1) < $signed(src2)};
    end

    // ============================================================
    // Output selection based on opcode
    // ============================================================
    always_comb begin : output_selection
        case (opcode)
            // ----------------------------------------------------
            // R-type and M-type
            // ----------------------------------------------------
            `OP_RM_TYPE: begin
                if (is_mtype) begin
                    if (func[3:1] == `FUNC_MUL)
                        aluOut = mul_res[31:0];      // MUL (low 32-bit)
                    else
                        aluOut = mul_res[63:32];     // MULH / MULHSU / MULHU (high 32-bit)
                end else begin
                    case ({func})
                        `FUNC_ADD:  aluOut = add_res;
                        `FUNC_SUB:  aluOut = sub_res;
                        `FUNC_SLL:  aluOut = sll_res;
                        `FUNC_SLT:  aluOut = slt_res;
                        `FUNC_SLTU: aluOut = sltu_res;
                        `FUNC_XOR:  aluOut = xor_res;
                        `FUNC_SRL:  aluOut = srl_res;
                        `FUNC_SRA:  aluOut = sra_res;
                        `FUNC_OR:   aluOut = or_res;
                        `FUNC_AND:  aluOut = and_res;
                        default:    aluOut = 32'd0;
                    endcase
                end
            end

            // ----------------------------------------------------
            // I-type (load, arithmetic/logic)
            // ----------------------------------------------------
            `OP_I_LOAD:  aluOut = add_res; // address = rs1 + imm
            `OP_I_ARITH: begin
                casez ({func})
                    4'b000?: aluOut = add_res;   // ADDI
                    4'b0010: aluOut = sll_res;   // SLLI
                    4'b010?: aluOut = slt_res;   // SLTI
                    4'b011?: aluOut = sltu_res;  // SLTIU
                    4'b100?: aluOut = xor_res;   // XORI
                    4'b1010: aluOut = srl_res;   // SRLI
                    4'b1011: aluOut = sra_res;   // SRAI
                    4'b110?: aluOut = or_res;    // ORI
                    4'b111?: aluOut = and_res;   // ANDI
                    default: aluOut = 32'd0;
                endcase
            end

            // ----------------------------------------------------
            // Store
            // ----------------------------------------------------
            `OP_S_TYPE: aluOut = add_res; // address = rs1 + imm

            // ----------------------------------------------------
            // Branch
            // ----------------------------------------------------
            `OP_B_TYPE: begin
                aluOut[31:1] = 31'd0; // branch flag (address handled by JBU)
                case (func[3:1])
                    `BR_EQ : aluOut[0] = src1 == src2;
                    `BR_NE : aluOut[0] = src1 != src2;
                    `BR_LT : aluOut[0] = $signed(src1) < $signed(src2);
                    `BR_GE : aluOut[0] = $signed(src1) >= $signed(src2);
                    `BR_LTU: aluOut[0] = src1 < src2;
                    `BR_GEU: aluOut[0] = src1 >= src2;
                    default: aluOut[0] = 1'b0;
                endcase
            end

            // ----------------------------------------------------
            // Upper immediates & jumps
            // ----------------------------------------------------
            `OP_AUIPC: aluOut = add_res;
            `OP_LUI:   aluOut = src2;
            `OP_JAL:   aluOut = add_4_res; // writebackData = PC + 4 (address handled by JBU)
            `OP_JALR:  aluOut = add_4_res; // writebackData = PC + 4 (address handled by JBU)

            // ----------------------------------------------------
            // Floating-point load/store (address calculation)
            // ----------------------------------------------------
            `OP_FLW: aluOut = add_res; // address = rs1 + imm
            `OP_FSW: aluOut = add_res; // address = rs1 + imm

            // ----------------------------------------------------
            // Default
            // ----------------------------------------------------
            default: aluOut = 32'd0;
        endcase
    end

endmodule
