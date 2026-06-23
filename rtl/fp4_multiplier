// fp4_multiplier.v
// Multiplies two FP4 numbers and returns the Q4.4 scaled product.
// product = (a_val * b_val) * 16.

`include "fp4_defines.v"

module fp4_multiplier (
    input  [3:0]          a,
    input  [3:0]          b,
    output signed [15:0]  product
);

    wire signed [15:0] a_scaled, b_scaled;

    fp4_to_scaled u_a (.fp4(a), .scaled(a_scaled));
    fp4_to_scaled u_b (.fp4(b), .scaled(b_scaled));

    // (a_val*16)*(b_val*16) = a_val*b_val * 256.
    // Divide by 16 to bring back to Q4.4 (a_val*b_val * 16).
    // Synthesis tools infer an arithmetic shift for /16.
    assign product = (a_scaled * b_scaled) / `SCALE_Q4_4;

endmodule
