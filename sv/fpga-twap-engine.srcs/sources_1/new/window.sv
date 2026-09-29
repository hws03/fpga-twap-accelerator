// sets the time boundary for the twap window

//LOGIC:
// every rising edge of the clock, increment a counter by 1 until it reaches the set window size.
//when it does reach, pulse a signal (pulse_window) for 1 clock cycle and then reset the counter
//if counter is exactly 1, pulse a "window_is_one" signal high for one clock cycle

//OUTPUT: 
// output is input into twap_accumulator


module window #(
    parameter set_window_size = 256 
)
(
    input logic fsm_start,
    input logic clk,
    input logic reset,
    input logic[($clog2(set_window_size)+1)-1:0] window_size, //calculates the minimum bit-width required to hold values up to set_window_size inclusively (9 bits for 256)

    output logic window_is_one,
    output logic pulse_window
);


logic[($clog2(set_window_size)+1)-1:0] window_counter_signal = '0;
logic pulse_window_signal = 1'b0;

logic executing = 1'b0;

logic window_is_one_sig;


always_ff @(posedge clk) begin
    
    window_is_one_sig <= 1'b0;     //clear after one pulse
    pulse_window_signal <= 1'b0;   //clear after one pulse

    if (reset) begin
        executing <= 1'b0;
        window_counter_signal <= '0;
        window_is_one_sig <= 1'b0;
        pulse_window_signal <= 1'b0;
    end

    else if (fsm_start || executing) begin
        executing <= 1'b1;
//        window_counter_signal <= window_counter_signal + 1;

        if (window_size == 1) begin
            executing           <= 1'b0;
            pulse_window_signal <= 1'b1;
            window_is_one_sig   <= 1'b1;
            window_counter_signal <= '0;
        end
//        if (window_size == 0 || window_counter_signal == (window_size-1'b1)) begin
        else if ((window_counter_signal + 1'b1) == window_size || window_size == 0) begin
            executing <= 1'b0;
            pulse_window_signal <= 1'b1;
            window_counter_signal <= '0;
        end
        
        else begin
            window_counter_signal <= window_counter_signal + 1;
        end
            
    end
end 

assign window_is_one = window_is_one_sig;
assign pulse_window = pulse_window_signal;

endmodule