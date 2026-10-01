/*
FSM that controls the movement of data and the activity of the pipelines

FSM path:
--idle: hold state unless start signals pulse high, which then sends state to accumulate and starts the window and accumulator modules.
--accumulate: waits until both the window and accumulator modules signal that they are done, then moves to the divide state and starts the divider
--divide: waits until the divider signals done, then moves to stop.
--stop: pulse "twap_result_valid" signal high to indicate the twap calcualtion is fully finished

OUTPUT:
-- controls/coordinates all modules
*/


module fsm (
    input logic clk,
    input logic reset,
    input logic start,
    input logic pulse_window,
    input logic accumulator_done,
    input logic divider_done,

    output logic window_state_start,
    output logic window_state_done,
    output logic accumulator_state_start,
    output logic accumulator_state_done,
    output logic divider_state_start,
    output logic twap_result_valid
);

    typedef enum logic [1:0] { IDLE, ACCUMULATE, DIVIDE, STOP } state_t;
    state_t state, next_state;


    //state register
    always_ff @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end


    //next_state logic (combinational)
    always_comb begin
        next_state = state; // default: hold
        case (state)
            IDLE: next_state = start ? ACCUMULATE : IDLE;
            ACCUMULATE: next_state = accumulator_done ? DIVIDE : ACCUMULATE;
            DIVIDE: next_state = divider_done ? STOP : DIVIDE;
            STOP: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end


    //output logic
    always_comb begin
        window_state_start <= 1'b0;
        window_state_done <= 1'b0;
        accumulator_state_start <= 1'b0;
        accumulator_state_done <= 1'b0;
        divider_state_start <= 1'b0;
        twap_result_valid <= 1'b0;

        case (state)

            IDLE: begin
                if (start) begin
                    window_state_start <= 1'b1;
                    accumulator_state_start <= 1'b1;
                end
            end

            ACCUMULATE: begin
                if (accumulator_done) begin
                    window_state_done <= 1'b1;
                    accumulator_state_done <= 1'b1;
                    divider_state_start <= 1'b1;
                end
            end

            DIVIDE: begin
                ; //wait for division to finish
            end

            STOP: begin
                twap_result_valid <= 1'b1;
            end
            
            default: ;
        
        endcase
end

endmodule