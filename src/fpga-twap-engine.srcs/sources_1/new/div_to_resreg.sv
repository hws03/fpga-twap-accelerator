/* 
A register stage inserted between the divider and result_reg modules. 
*/

module div_to_resreg (
    input logic clk,
    input logic reset,
    input logic[63:0] divider_output,
    input logic divider_done,
    
    output logic[63:0] div_to_latch_out,
    output logic div_to_latch_done
);

logic[63:0] div_reg;
logic done_reg;

always_ff @(posedge clk) begin
    if (reset) begin
        div_reg <= 64'b0;
        done_reg <= 1'b0;
    end
    
    else begin
        div_reg <= divider_output;
        done_reg <= divider_done;
    end
end

assign div_to_latch_out = div_reg;
assign div_to_latch_done = done_reg;

endmodule