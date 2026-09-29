//top-level

module twap #(
    parameter set_window_size = 32
)
(
    input logic clk,
    input logic reset,
    input logic start,
    input logic [31:0] top_price,
    input logic top_price_valid,
    input logic [($clog2(set_window_size + 1)-1):0] top_window_size,

    output logic [63:0] final_twap,
    output logic twap_valid
);

// top level signals
logic start_window;
logic start_accumulator;
logic start_divider;
logic top_window_pulse;
logic [63:0] top_accumulated_price;
logic [31:0] top_accumulator_count;
logic top_accumulator_done;
logic [63:0] top_divider_output;
logic top_divider_done;
logic top_twap_result_valid;
logic top_raw_isvalid;
logic top_syncd_isvalid;
logic top_syncd_start;
logic [31:0] pipelined_accumulated_count;
logic [63:0] pipelined_accumulated_price;
logic pipelined_accumulator_done;
logic [63:0] pipelined_divider_output;
logic pipelined_divider_done;

logic top_window_is_one;

logic top_accumulator_window_is_one;

logic pipelined_accumulator_window_is_one;


//input_shift_reg is two flops in series, so top_price_valid reaches the accumulator 2 cycles late. 
//price_d1 and price_d2 give top_price the same 2-cycle delay, so each price arrives in the same cycle as its valid bit.
//Input Synchronization: Since start and top_price_valid enter at the top-level boundary, using input_shift_reg there safely synchronizes them to clk. 
//Data Alignment: Because control/valid signal is delayed by 2 cycles through the synchronizer, delaying top_price by 2 cycles using price_d1 and price_d2 correctly keeps the data and its valid signal aligned.
logic [31:0] price_d1, price_d2;

always_ff @(posedge clk) begin
    if (reset) begin
        price_d1 <= '0;
        price_d2 <= '0;
    end
    else begin
        price_d1 <= top_price;
        price_d2 <= price_d1;
    end
end



fsm twap_fsm_instance (
    .clk(clk),
    .reset(reset),
    .start(top_syncd_start),
    .pulse_window(top_window_pulse),
    .accumulator_done(top_accumulator_done),
    .divider_done(top_divider_done),

    .window_state_start(start_window),
    .window_state_done(), // open
    .accumulator_state_start(start_accumulator),
    .accumulator_state_done(), // open
    .divider_state_start(start_divider),
    .twap_result_valid(top_twap_result_valid)
);


window #(
    .set_window_size(set_window_size)
) 
twap_window_instance (
    .fsm_start(start_window),
    .clk(clk),
    .reset(reset),
    .window_size(top_window_size),

    .window_is_one(top_window_is_one),
    .pulse_window(top_window_pulse)
);


accumulator twap_accumulator_instance (
    .fsm_start(start_accumulator),
    .clk(clk),
    .reset(reset),
    .pulse_window(top_window_pulse),
    .is_valid(top_syncd_isvalid),
    .price(price_d2),
    .window_is_one(top_window_is_one),

    .accumulator_window_is_one(top_accumulator_window_is_one),
    .accumulator_sample_count(top_accumulator_count),
    .accumulated_price(top_accumulated_price),
    .accumulator_done(top_accumulator_done)
);


acc_to_divider acc_to_divider_pipeline_instance (
    .clk(clk),
    .reset(reset),
    .accumulator_sample_count(top_accumulator_count),
    .accumulated_price(top_accumulated_price),
    .accumulator_window_is_one(top_accumulator_window_is_one),
    .accumulator_done(top_accumulator_done),
    
    .acc_to_divider_window_is_one(pipelined_accumulator_window_is_one),
    .acc_to_divider_count(pipelined_accumulated_count),
    .acc_to_divider_out(pipelined_accumulated_price),
    .acc_to_divider_done(pipelined_accumulator_done)
);


divider twap_divider_instance (
    .fsm_start(start_divider),
    .clk(clk),
    .reset(reset),
    .accumulator_sample_count(pipelined_accumulated_count),
    .accumulated_price(pipelined_accumulated_price),
    .accumulator_window_is_one(pipelined_accumulator_window_is_one),
    .accumulator_done(pipelined_accumulator_done),

    .divider_output(top_divider_output),
    .divider_done(top_divider_done)
);


div_to_resreg div_to_latch_pipeline_instance (
    .clk(clk),
    .reset(reset),
    .divider_output(top_divider_output),
    .divider_done(top_divider_done),

    .div_to_latch_out(pipelined_divider_output),
    .div_to_latch_done(pipelined_divider_done)
);


result_register twap_result_register_instance (
    .clk(clk),
    .reset(reset),
    .twap_valid(top_twap_result_valid),
    .divider_output(pipelined_divider_output),

    .twap_latched(final_twap),
    .twap_valid_latched(twap_valid)
);


input_shift_reg twap_input_shift_reg_instance1 (
    .clk(clk),
    .reset(reset),
    .raw_isvalid_input(start),

    .syncd_isvalid_output(top_syncd_start)
);


input_shift_reg twap_input_shift_reg_instance2 (
    .clk(clk),
    .reset(reset),
    .raw_isvalid_input(top_price_valid),

    .syncd_isvalid_output(top_syncd_isvalid)
);

endmodule