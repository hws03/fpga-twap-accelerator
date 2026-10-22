/* 
a running sum (accumulation) of incoming *valid* prices

LOGIC:
 take in a new price at every rising edge of the clock, if "is_valid" is 1: then do that "price" + "accumulated_price_signal".
 everytime one addition is done, do "accumulator_sample_count" + 1
 when "pulse_window" pulses (telling us we've reached the end of this TWAP period), set "done" to 1, asserting that the operation is finished
 take a snapshot of current final values and store them in buffers before resetting values of accumulation and sample count
 set the output ports to current stored buffer values (snapshot)

OUTPUT:
 output is fed as input into twap_divider
*/

module accumulator (
    input logic fsm_start,
    input logic clk,
    input logic reset,
    input logic pulse_window,
    input logic is_valid,
    input logic[31:0] price,
    input logic window_is_one,

    output logic accumulator_window_is_one,
    output logic[31:0] accumulator_sample_count,
    output logic[63:0] accumulated_price,
    output logic accumulator_done
);

logic[31:0] accumulator_sample_count_signal = 32'b0;
logic[63:0] accumulated_price_signal = 64'b0;
logic accumulator_done_signal = 1'b0;

logic executing = 1'b0;

logic[31:0] sample_count_buffer;
logic[63:0] price_signal_buffer;

logic window_is_one_buffer;

always_ff @(posedge clk) begin
    accumulator_done_signal <= 1'b0;

    if (reset) begin
        executing <= 1'b0;
        accumulated_price_signal <= 64'b0;
        accumulator_sample_count_signal <= 32'b0;
        sample_count_buffer <= 32'b0;
        price_signal_buffer <= 64'b0;
        accumulator_done_signal <= 1'b0;
        window_is_one_buffer <= 1'b0;
    end

    else if (fsm_start || executing) begin
        executing <= 1'b1;
        
        if (pulse_window) begin
            executing <= 1'b0;
            accumulator_done_signal <= 1'b1;
            window_is_one_buffer <= window_is_one;
            
            //if a valid sample arrives on the same clock cycle as pulse_window, include it in the final snapshot
            if (is_valid) begin
                sample_count_buffer <= accumulator_sample_count_signal + 1'b1;
                price_signal_buffer <= accumulated_price_signal + price;
            end else begin
                sample_count_buffer <= accumulator_sample_count_signal;
                price_signal_buffer <= accumulated_price_signal;
            end

            //reset internal accumulators for next run
            accumulated_price_signal <= 64'b0;
            accumulator_sample_count_signal <= 32'b0;
        end
        
        else if (is_valid) begin
            accumulated_price_signal <= accumulated_price_signal + price;
            accumulator_sample_count_signal <= accumulator_sample_count_signal + 1'b1;
        end
    end
end


assign accumulator_sample_count = sample_count_buffer;
assign accumulated_price = price_signal_buffer;
assign accumulator_window_is_one = window_is_one_buffer;
assign accumulator_done = accumulator_done_signal;


endmodule