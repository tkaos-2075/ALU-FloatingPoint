# Floating Point ALU (FP16 / FP32)

Design and implementation of a modular Arithmetic Logic Unit (ALU) for floating-point operations under the IEEE 754 standard, optimized for the **Basys 3 FPGA** (Artix-7).

## Key Features
- **Multi-format Support:** Parameterized processing for Half Precision (FP16) and Single Precision (FP32).
- **Operations:** Addition, Subtraction, Multiplication, and Division.
- **Exception Handling:** Full implementation of IEEE 754 flags: Invalid Operation, Division by Zero, Overflow, Underflow, and Inexact.
- **Rounding Modes:** Configurable between Truncation and Round-to-nearest-even.

## System Architecture
The project uses a hierarchical modular approach coordinated by the `top_alu` module:

1. **Arithmetic Units (`fadd`, `fsub`, `fmul`, `fdiv`):** Independent modules executing calculations in parallel based on the selected format.
2. **Unpacker/Packer:** Generic components that decompose operands into sign, exponent, and mantissa, and reconstruct the result applying normalization and rounding.
3. **Peripheral Control:**
    - `Concat_In`: Manages incremental 32-bit operand loading using the 8 physical switches.
    - `Display_Driver`: Multiplexed 7-segment display management to show operands and results.
    - `Debouncer`: Digital filtering for control signals (`start`, `rst`).

## Control Signals (Basys 3)
| Signal | Description |
| :--- | :--- |
| `clk` | 100 MHz Main Clock. |
| `rst` | Synchronous active-high reset. |
| `op_code [1:0]` | Operation select (00: Add, 01: Sub, 10: Div, 11: Mul). |
| `mode_fp` | Precision selector (0: FP16, 1: FP32). |
| `round_mode` | Rounding mode (0: Truncation, 1: Round-to-nearest-even). |
| `chrg_part [7:0]` | 8-bit bus for partial operand loading. |

## Requirements
- **Software:** Xilinx Vivado (Synthesis and Simulation).
- **Hardware:** Digilent Basys 3 FPGA.

---
*Project developed by Group r2d2 - UTEC.*
