# FPGA TWAP Accelerator
Time-Weighted Average Price (TWAP) calculation pipeline, written in SystemVerilog using Xilinx Vivado.

TWAP is the average price of an asset over a specific period, calculated by taking samples at equal intervals and finding their mean.

- **Modules:** `twap` (top level), `fsm`, `input_shift_reg`, `window`, `accumulator`, `acc_to_divider`, `divider`, `div_to_resreg`, `result_reg`. 