Bit-Sparsity-Aware FP4 MAC ASIC Accelerator

A complete RTL-to-GDSII implementation of a custom 4-bit floating-point Multiply-Accumulate (MAC) unit with bit-sparsity-aware zero-skipping, targeting the SKY130 open-source Process Design Kit (PDK) using the OpenLane automated ASIC flow.

Table of Contents

- Overview
- Key Results
- FP4 E2M1 Format
- Bit-Sparsity-Aware Zero-Skipping
- RTL Module Description
- Simulation Results
- ASIC Implementation Flow
- Physical Implementation Results
- Power Analysis
- Repository Structure
- Tools Used

Overview

This project implements a Bit-Sparsity-Aware FP4 Multiply-Accumulate (MAC) Accelerator as a complete ASIC design, from RTL development in Verilog to fabrication-ready GDSII layout generation. The design targets edge-AI and low-power machine learning inference workloads, where operand sparsity (zero-valued inputs) is common and can be exploited to reduce dynamic power consumption.

The arithmetic core uses a custom FP4 E2M1 floating-point format (1-bit sign, 2-bit exponent, 1-bit mantissa). FP4 operands are internally converted to a signed Q4.4 fixed-point representation for efficient multiply-accumulate operations. A two-stage pipeline separates multiplication and accumulation to improve timing closure and enable physical design optimization.

The key architectural innovation is a lightweight zero-skipping mechanism: whenever either operand is zero and sparsity mode is enabled, the multiplier output is dynamically gated to zero, preventing unnecessary switching activity in the accumulator. This directly reduces dynamic power without any logic overhead on the critical path.

The design was implemented using the OpenLane RTL-to-GDSII flow targeting the SKY130 HD standard-cell library and successfully achieved clean signoff with zero DRC, LVS, and antenna violations.

**Key Results**

| Metric                     | Value                    |
| -------------------------- | ------------------------ |
| Technology Node            | SKY130 (180 nm open PDK) |
| Standard Cell Library      | sky130_fd_sc_hd          |
| Clock Period               | 10 ns (100 MHz)          |
| Setup Slack (WNS)          | +3.85 ns                 |
| Hold Slack                 | +0.38 ns                 |
| Total Negative Slack (TNS) | 0.00ns                   |
| Die Area                   | 0.00923 mm²              |
| Core Area                  | 6277.27 µm²              |
| Synthesized Logic Cells    | 301                      |
| Total Cells (post-layout)  | 936                      |
| Placement Utilization      | 53.58%                   |
| Total Wire Length          | 6855 µm                  |
| Total Vias                 | 2267                     |
| Total Power                | 544 µW                   |
| DRC Violations             | 0                        |
| LVS Errors                 | 0                        |
| Antenna Violations         | 0                        |
| Setup Violations           | 0                        |
| Hold Violations            | 0                        |
| OpenLane Flow Status       | Completed Successfully   |
| Full Flow Runtime          | 1 min 4 sec              |

**FP4 E2M1 Format**

This design uses a custom 4-bit floating-point format with the following bit layout:

| Bit 3 | Bits 2:1 | Bit 0    |
| ----- | -------- | -------- |
| Sign  | Exponent | Mantissa |
| 1     | 2        | 1        |

- Bias = 1(for the 2-bit exponent field)
- Scaling factor = 16(Q4.4 fixed-point: 1.0 in real value maps to 16 in integer)

**Complete FP4 Value Table**

| FP4 Bits | Sign | Exponent | Mantissa | Real Value | Q4.4 Scaled |
| -------- | ---- | -------- | -------- | ---------- | ----------- |
| 0000     | +    | 0        | 0        | 0.0        | 0           |
| 0001     | +    | 0        | 1        | 0.5        | 8           |
| 0010     | +    | 1        | 0        | 1.0        | 16          |
| 0011     | +    | 1        | 1        | 1.5        | 24          |
| 0100     | +    | 2        | 0        | 2.0        | 32          |
| 0101     | +    | 2        | 1        | 3.0        | 48          |
| 0110     | +    | 3        | 0        | 4.0        | 64          |
| 0111     | +    | 3        | 1        | 6.0        | 96          |
| 1000     | -    | 0        | 0        | -0.0       | 0           |
| 1001     | -    | 0        | 1        | -0.5       | -8          |
| 1010     | -    | 1        | 0        | -1.0       | -16         |
| 1011     | -    | 1        | 1        | -1.5       | -24         |
| 1100     | -    | 2        | 0        | -2.0       | -32         |
| 1101     | -    | 2        | 1        | -3.0       | -48         |
| 1110     | -    | 3        | 0        | -4.0       | -64         |
| 1111     | -    | 3        | 1        | -6.0       | -96         |

**The Q4.4 multiply is computed as:**

This keeps the result in Q4.4 representation and is implemented as an arithmetic right shift by 4, which synthesis tools infer automatically.

Architecture

The design is organized as a two-stage pipeline:

Pipeline stages:

- Stage 1- FP4-to-Q4.4 conversion → multiplication → sparsity gating → pipeline register

- Stage 2- Conditional accumulation into \`acc_reg\` on \`enable\`, clearable via \`acc_clear\`

Port Description:  

| Port      | Dir    | Width | Description                                   |
| --------- | ------ | ----- | --------------------------------------------- |
| clk       | Input  | 1     | System clock (100 MHz)                        |
| rst_n     | Input  | 1     | Active-low asynchronous reset                 |
| a         | Input  | 4     | FP4 operand A                                 |
| b         | Input  | 4     | FP4 operand B                                 |
| enable    | Input  | 1     | Enable accumulation for one cycle             |
| sparse_en | Input  | 1     | Enable bit-sparsity zero-skipping             |
| acc_clear | Input  | 1     | Synchronous accumulator clear                 |
| acc_out   | Output | 16    | Accumulated result in signed Q4.4 fixed-point |

**Bit-Sparsity-Aware Zero-Skipping**

In neural network inference and signal processing workloads, a large fraction of weights and activations are zero (due to ReLU activations, pruning and quantization). A conventional MAC unit computes (0 × x) through the full multiplier and adder, consuming dynamic power due to switching activity even though the result is always zero.

This design addresses that inefficiency with a zero-skipping gate:

assign zero_skip = sparse_en && (a == 4'b0000 || b == 4'b0000);

assign mul_gated = zero_skip ? 16'd0 : mul_raw;

**How it works:**

- When \`sparse_en = 1\` and either \`A\` or \`B\` is zero, \`mul_gated\` is forced to zero

- This prevents the non-zero raw product from being loaded into the pipeline register

- The accumulator sees a stable zero input, producing \*\*zero toggle activity\*\* in the adder

- The gate adds no logic to the critical path (it is a simple MUX before a pipeline register)

- When \`sparse_en = 0\`, the mechanism is fully bypassed for non-sparse workloads

Hardware cost:1 MUX-16 (implemented as \`sky130*fd_sc_hd*\_mux2\` standard cells)

Benefit:Reduces dynamic power proportionally to input sparsity level

This is demonstrated in Test 3 of the simulation, where \`A = 0000\` and \`sparse_en = 1\` correctly skips the multiplication and leaves the accumulator unchanged at 64.

**RTL Module Description**

The design consists of four Verilog source files in:

- fp4_defines.v

Header file defining all FP4 format constants as Verilog macros.

- fp4_to_scaled.v

Purely combinational converter. Takes a 4-bit FP4 value and outputs its signed 16-bit Q4.4 fixed-point equivalent using a case statement on the exponent field. Handles the subnormal case (\`exp = 00, mant = 1\`) and applies the sign bit via negation.

- fp4_multiplier.v

Instantiates two \`fp4_to_scaled\` converters for operands A and B, then computes the product where the division by 16 is synthesized as an arithmetic right shift, producing a compact and timing-efficient multiplier.

- fp4_mac.v

Instantiates \`fp4_multiplier\`, applies the sparsity gate, and implements the two-stage pipeline with active-low asynchronous reset. The \`acc_clear\` signal provides a synchronous accumulator flush without resetting the pipeline register, enabling back-to-back MAC sequences.

**Simulation Results**

RTL functionality was verified using a self-checking testbench in Vivado 2025.2.

Test Cases

| Test | A (FP4) | B(FP4) | A Value | B Value | Expected (Q4.4)  | Result | Status |
| ---- | ------- | ------ | ------- | ------- | ---------------- | ------ | ------ |
| 1    | 0010    | 0010   | +1.0    | +1.0    | 16 (1.0)         | 16     | Pass   |
| 2    | 0011    | 0100   | +1.5    | +2.0    | 64 (4.0, accum)  | 64     | Pass   |
| 3    | 0000    | 0010   | 0.0     | +1.0    | 64 (skip, accum) | 64     | Pass   |
| 4    | 1010    | 0011   | \-1.0   | +1.5    | \-24 (-1.5)      | \-24   | pass   |

**ASIC Implementation Flow**

The design was implemented using OpenLane v1 targeting the SKY130 HD standard-cell library. The complete flow ran in 1 minute 4 seconds.

| Step | Stage                      | Tool        | Key Configuration                         |
| ---- | -------------------------- | ----------- | ----------------------------------------- |
| 1    | Logic Synthesis            | Yosys       | Strategy: AREA 0                          |
| 2    | Post-Synthesis STA         | OpenSTA     | Clock: 10 ns, WNS: 0.0 ns                 |
| 3    | Floorplanning              | OpenROAD    | Core util: 50%, Aspect ratio: 1:1         |
| 4    | I/O Placement              | OpenROAD    | Equidistant I/O placement                 |
| 5    | Power Distribution Network | OpenROAD    | PDN H-pitch: 19.72 µm, V-pitch: 19.895 µm |
| 6    | Global Placement           | RePlace     | Target density: 55%                       |
| 7    | Detailed Placement         | OpenDP      | Final utilization: 53.58%                 |
| 8    | Clock Tree Synthesis       | TritonCTS   | Clock buffers inserted                    |
| 9    | Global Routing             | FastRoute   | GRT adjustment: 0.3                       |
| 10   | Detailed Routing           | TritonRoute | 0 DRC violations post-routing             |
| 11   | GDSII Generation           | Magic       | Via KLayout and Magic                     |
| 12   | DRC                        | Magic       | 0 violations                              |
| 13   | LVS                        | Netgen      | 0 errors, 363 nets matched                |
| 14   | Antenna Check              | OpenROAD    | 0 pin/net violations                      |
| 15   | Signoff STA                | OpenSTA     | Setup WNS: +3.85 ns, Hold: +0.38 ns       |

**Physical Implementation Results**

**Area Breakdown**

| Category                        | Count |
| ------------------------------- | ----- |
| Synthesized logic cells         | 301   |
| Flip-flops                      | 28    |
| Standard cells (post-placement) | 346   |
| Decap cells                     | 324   |
| Welltap cells                   | 93    |
| Diode cells                     | 1     |
| Filler cells                    | 172   |
| Total cells (incl. physical)    | 936   |

**Routing Statistics**

| Metric            | Value   |
| ----------------- | ------- |
| Total wire length | 6855 µm |
| Total vias        | 2267    |
| Metal 2 usage     | 20.12%  |
| Metal 3 usage     | 26.32%  |
| Metal 4 usage     | 1.44%   |
| Metal 5 usage     | 0.52%   |

**Signoff Summary**

Magic DRC Summary:

-Total Magic DRC violations: 0

LVS Summary:

-Number of nets: 363 | Number of nets: 363

-Design is LVS clean.

-Total errors = 0

Antenna Summary:

-Pin violations: 0

-Net violations: 0

Timing Summary:

-WNS (Setup): 0.00 ns → Worst slack: +3.85 ns

-WNS (Hold): 0.00 ns → Worst slack: +0.38 ns

-TNS: 0.00 ns

**Power Analysis**

Post-synthesis power analysis at the typical corner (25°C, 1.8V):

| Power Domain  | Internal Power | Switching power | Total power | Share |
| ------------- | -------------- | --------------- | ----------- | ----- |
| Sequential    | 144 µW         | 65 µW           | 209 µW      | 38.3% |
| Combinational | 202 µW         | 133 µW          | 335 µW      | 61.7% |
| Total         | 346 µW         | 198 µW          | 544 µW      | 100%  |

The bit-sparsity zero-skipping mechanism directly reduces the switching power component of the combinational logic by suppressing toggle activity in the multiplier output and accumulator input during sparse operations.

**Tools Used**

| **Tool**   | **Purpose**                                | **Version**    |
| ---------- | ------------------------------------------ | -------------- |
| Vivado     | RTL simulation                             | 2025.2         |
| OpenLane   | RTL-to-GDSII automated ASIC flow           | v1             |
| Yosys      | Logic synthesis                            | (via OpenLane) |
| OpenROAD   | Floorplan, placement, CTS, routing, STA    | (via OpenLane) |
| Magic      | GDSII generation, DRC, SPICE extraction    | (via OpenLane) |
| Netgen     | Layout versus Schematic (LVS) verification | (via OpenLane) |
| KLayout    | GDSII viewing and DRC cross-check          | (via OpenLane) |
| SKY130 PDK | Open-source 180 nm process design kit      | sky130B        |

Key Takeaways

This project demonstrates a complete end-to-end ASIC design methodology covering:

- Custom arithmetic format design (FP4 E2M1) for low-bit-width AI inference

- RTL coding best practices: parameterization, pipelining, and reset strategy

- Architectural power optimization through sparsity-aware computation

- Full physical design flow: synthesis, floorplan, PDN, placement, CTS, routing

- Signoff verification: STA, DRC, LVS, and antenna checks

- Open-source ASIC tooling proficiency (OpenLane, OpenROAD, Yosys, Magic, Netgen)

The design achieved \*\*clean signoff\*\* (0 DRC, 0 LVS, 0 antenna violations) with positive timing slack at 100 MHz, validating it as a fabrication-ready design on the SKY130 open PDK.
