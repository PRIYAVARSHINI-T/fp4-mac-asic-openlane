// fp4_mac.v
// Top-level FP4 Multiply-Accumulate unit with Bit-Sparsity-Aware Zero-Skipping.
// Pipeline: Stage 1 = Multiplication, Stage 2 = Accumulation.
// If sparse_en=1 and (A==0 or B==0), the multiplication is skipped via output gating.

`include "fp4_defines.v"

module fp4_mac (
    input  wire          clk,
    input  wire          rst_n,

    input  wire [3:0]    a,           // FP4 operand A
    input  wire [3:0]    b,           // FP4 operand B

    input  wire          enable,      // Enable the accumulation
    input  wire          sparse_en,   // 1 = Enable bit-sparsity aware skipping
    input  wire          acc_clear,   // 1 = Clear accumulator

    output wire signed [15:0] acc_out // Final accumulated value (Q4.4)
);

    // ------------------------------------------------------------------
    // Stage 1: Multiplication & Sparsity Gating
    // ------------------------------------------------------------------
    wire signed [15:0] mul_raw;       // Raw product from multiplier
    wire signed [15:0] mul_gated;     // Product after zero-skipping
    wire               zero_skip;     // Flag to skip multiplication

    // Instantiate the FP4 multiplier
    fp4_multiplier u_mult (
        .a      (a),
        .b      (b),
        .product(mul_raw)
    );

    // --- NOVEL BIT-SPARSITY LOGIC ---
    // If the input is exactly zero, we dynamically gate the multiplier output to 0.
    // This reduces switching activity in the adder/accumulator, saving dynamic power.
    assign zero_skip = sparse_en && (a == 4'b0000 || b == 4'b0000);
    assign mul_gated = zero_skip ? 16'd0 : mul_raw;

    // ------------------------------------------------------------------
    // Pipeline Registers
    // ------------------------------------------------------------------
    reg signed [15:0] mul_pipe;       // Pipeline stage 1 output
    reg signed [15:0] acc_reg;        // Accumulator register

    // Stage 1 Register (improves timing for physical design)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mul_pipe <= 16'd0;
        else
            mul_pipe <= mul_gated;     // Capture the (possibly gated) product
    end

    // Stage 2: Accumulator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg <= 16'd0;
        end else if (acc_clear) begin
            acc_reg <= 16'd0;
        end else if (enable) begin
            acc_reg <= acc_reg + mul_pipe;  // Perform the MAC operation
        end
    end

    // ------------------------------------------------------------------
    // Output
    // ------------------------------------------------------------------
    assign acc_out = acc_reg;

endmodule
