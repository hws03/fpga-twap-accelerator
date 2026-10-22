//register stage inserted between the accumulator and divider modules. 


module acc_to_divider (
    input logic clk,
    input logic reset,
    input logic[31:0] accumulator_sample_count,
    input logic[63:0] accumulated_price,
    input logic accumulator_window_is_one,
    input logic accumulator_done,
    
    output logic acc_to_divider_window_is_one,
    output logic[31:0] acc_to_divider_count,
    output logic[63:0] acc_to_divider_out,
    output logic acc_to_divider_done
);

logic[31:0] count_reg;
logic[63:0] acc_reg;
logic done_reg;
logic window_is_one_reg;

always_ff @(posedge clk) begin
    if (reset) begin
        count_reg <= 32'b0;
        acc_reg <= 64'b0;
        window_is_one_reg <= 0;
        done_reg <= 1'b0;
    end
    
    else begin
        count_reg <= accumulator_sample_count;
        acc_reg <= accumulated_price;
        window_is_one_reg <= accumulator_window_is_one;
        done_reg <= accumulator_done;
    end
end

assign acc_to_divider_count = count_reg;
assign acc_to_divider_out = acc_reg;
assign acc_to_divider_window_is_one = window_is_one_reg;
assign acc_to_divider_done = done_reg;

endmodule