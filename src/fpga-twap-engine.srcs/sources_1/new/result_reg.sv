/* 
when a final twap is calculated, hold it until a new one is calculated. this way we can latch onto the result until a new one is calcualted
without losing the previous one just yet
*/

module result_register (
    input logic clk,
    input logic reset,
    input logic twap_valid,
    input logic[63:0] divider_output,

    output logic[63:0] twap_latched,
    output logic twap_valid_latched
);


always_ff @(posedge clk) begin
    if (reset) begin
        twap_latched <= 64'b0;
        twap_valid_latched <= 1'b0;
    end
    
    else begin
        twap_valid_latched <= twap_valid;
        
        if (twap_valid) begin
            twap_latched <= divider_output;
        end
    end
end

endmodule