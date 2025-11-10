`ifndef DEF_SVH
`define DEF_SVH

// =========================================================
// Opcode 定義 (RISC-V Base)
// =========================================================
`define OP_RM_TYPE  5'b01100  // R-type and M-type
`define OP_I_LOAD   5'b00000  // I-type load
`define OP_I_ARITH  5'b00100  // I-type arithmetic
`define OP_S_TYPE   5'b01000  // S-type store
`define OP_B_TYPE   5'b11000  // B-type branch
`define OP_AUIPC    5'b00101  // AUIPC
`define OP_LUI      5'b01101  // LUI
`define OP_JAL      5'b11011  // JAL
`define OP_JALR     5'b11001  // JALR
`define OP_FLW      5'b00001  // FLW (floating load)
`define OP_FSW      5'b01001  // FSW (floating store)
`define OP_FTYPE    5'b10100  // FADD.S / FSUB.S
`define OP_CSR      5'b11100  // CSR type opcode

// =========================================================
// Function codes for R/I-type (funct3/funct7_5 simplified)
// =========================================================
`define FUNC_ADD    4'b0000   // ADD
`define FUNC_SUB    4'b0001   // SUB
`define FUNC_SLL    4'b0010   // SLL
`define FUNC_SLT    4'b0100   // SLT
`define FUNC_SLTU   4'b0110   // SLTU
`define FUNC_XOR    4'b1000   // XOR
`define FUNC_SRL    4'b1010   // SRL
`define FUNC_SRA    4'b1011   // SRA
`define FUNC_OR     4'b1100   // OR
`define FUNC_AND    4'b1110   // AND

// =========================================================
// M-type funct3
// =========================================================
`define FUNC_MUL    3'b000   // MUL
`define FUNC_MULH   3'b001   // MULH
`define FUNC_MULHSU 3'b010   // MULHSU
`define FUNC_MULHU  3'b011   // MULHU

// =========================================================
// Branch funct3
// =========================================================
`define BR_EQ  3'b000
`define BR_NE  3'b001
`define BR_LT  3'b100
`define BR_GE  3'b101
`define BR_LTU 3'b110
`define BR_GEU 3'b111

// =========================================================
// Load/Store funct3
// =========================================================
`define MEM_BYTE  3'b000
`define MEM_HALF  3'b001
`define MEM_WORD  3'b010
`define MEM_UBYTE 3'b100
`define MEM_UHALF 3'b101

// ============================================================
// CSR Operation Selection
// ============================================================
`define CSR_INSTRET_HIGH  2'b11
`define CSR_INSTRET_LOW   2'b01
`define CSR_CYCLE_HIGH    2'b10
`define CSR_CYCLE_LOW     2'b00

// ============================================================
// Bubble Instruction Definitions
// ============================================================
`define BUBBLE_INST   32'h00000013
`define BUBBLE_OPCODE `OP_I_ARITH // Only opcode is needed; other fields are zero


`endif