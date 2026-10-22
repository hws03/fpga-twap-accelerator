/*
prevents metastability by connecting two flip-flops to allow the first flip-flop to stablise the input before it reaches the 
second flip-flop, fully stable
*/


module input_shift_reg (
    input logic clk,
    input logic reset,
    input logic raw_isvalid_input,

    output logic syncd_isvalid_output
);

logic ff1 = 1'b0;

always_ff @(posedge clk) begin
    if (reset) begin
        ff1 <= 1'b0;
        syncd_isvalid_output <= 1'b0;
    end

    else begin
        ff1 <= raw_isvalid_input;
        syncd_isvalid_output <= ff1;
    end
end

endmodule