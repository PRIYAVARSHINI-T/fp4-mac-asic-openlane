`include "fp4_defines.v"

module fp4_to_scaled (
    input  [3:0]          fp4,
    output signed [15:0]  scaled
);

    wire       sign;
    wire [1:0] exp;
    wire       mant;
    wire       is_zero;

    assign sign = fp4[`FP4_SIGN];
    assign exp  = fp4[`FP4_EXP_MSB:`FP4_EXP_LSB];
    assign mant = fp4[`FP4_MANT];
    assign is_zero = (exp == 2'b00) && (mant == 1'b0);

    reg signed [15:0] val;

    always @(*) begin
        val = 16'd0;  // Default to zero

        if (!is_zero) begin
            case (exp)
                // Subnormal: 0.5  -> scaled = 8
                2'b00: val = 16'd8;   

                // Normal: 1.0 / 1.5 -> scaled = 16 / 24
                2'b01: val = (mant) ? 16'd24 : 16'd16; 

                // Normal: 2.0 / 3.0 -> scaled = 32 / 48
                2'b10: val = (mant) ? 16'd48 : 16'd32; 

                // Max: 4.0 / 6.0   -> scaled = 64 / 96 (we treat 1111 as -6.0 for deterministic HW)
                2'b11: val = (mant) ? 16'd96 : 16'd64; 

                default: val = 16'd0;
            endcase

            // Apply sign
            if (sign) val = -val;
        end
    end

    assign scaled = val;

endmodule
