/*
Calculates average price (X / N) in 3 pipelined clock cycles by using fixed-point multiplication instead of slow division:

LOGIC:
1. Core concept (X / N = X * (1 / N))
	-division on fpga is slow and uses heavy logic.
	 instead, this looks up the 32-bit Q0.32 fixed-point reciprocal 1/N in the 
	 LUT (reciprocal_lut, generated using python) and multiplies X * (1/N).

2. Pipelines
	Stage 1 (LUT lookup and latch):
	-reads accumulated_price (X) and retrieves 1/N from the lookup table based on sample_count (N).

	Stage 2 (split multiplication):
	-to keep DSP clock speeds high, split the 64-bit sum into low and high 32-bit halves and multiply both
	 by the 32-bit reciprocal simultaneously:
	   -low_reg = price[31:0] * (1/N)
	   -high_reg = price * (1/N)

	Stage 3 (combine & realign):
	-shift and add the partial products (final_reg).
	-the final result is extracted from bits to drop the 32 fractional fixed-point bits.

3. N=1 (instead of approximating with Q0.32)
	If N=1 (accumulator_window_is_one), it bypasses the multiplier entirely and 
	passes accumulated_price straight to the output (divider_output). 
	instead of using the approximated Q0.32 1
	
OUTPUT:
    Output goes to a div_to_resreg
*/

module divider (
    input logic fsm_start,
    input logic clk,
    input logic reset,
    input logic[31:0] accumulator_sample_count,
    input logic[63:0] accumulated_price,
    input logic accumulator_window_is_one,
    input logic accumulator_done,
    
    output logic[63:0] divider_output,
    output logic divider_done
);

//lut array       
localparam logic [31:0] reciprocal_lut [0:256] = 
'{  
    0: 32'h00000000, 1: 32'hffffffff,  2: 32'h80000000,  3: 32'h55555555,  4: 32'h40000000,  5: 32'h33333333,  6: 32'h2aaaaaab,  7: 32'h24924925,  8: 32'h20000000,  
    9: 32'h1c71c71c,  10: 32'h1999999a,  11: 32'h1745d174,  12: 32'h15555555,  13: 32'h13b13b14,  14: 32'h12492492,  15: 32'h11111111,  16: 32'h10000000,  17: 32'h0f0f0f0f,  
    18: 32'h0e38e38e,  19: 32'h0d79435e,  20: 32'h0ccccccd,  21: 32'h0c30c30c,  22: 32'h0ba2e8ba,  23: 32'h0b21642d,  24: 32'h0aaaaaab,  25: 32'h0a3d70a4,  26: 32'h09d89d8a,  
    27: 32'h097b425f,  28: 32'h09249249,  29: 32'h08d3dcb1,  30: 32'h08888889,  31: 32'h08421084,  32: 32'h08000000,  33: 32'h07c1f07c,  34: 32'h07878788,  35: 32'h07507507,  
    36: 32'h071c71c7,  37: 32'h06eb3e45,  38: 32'h06bca1af,  39: 32'h06906907,  40: 32'h06666666,  41: 32'h063e7064,  42: 32'h06186186,  43: 32'h05f417d0,  44: 32'h05d1745d,  
    45: 32'h05b05b06,  46: 32'h0590b216,  47: 32'h0572620b,  48: 32'h05555555,  49: 32'h0539782a,  50: 32'h051eb852,  51: 32'h05050505,  52: 32'h04ec4ec5,  53: 32'h04d4873f,  
    54: 32'h04bda12f,  55: 32'h04a7904a,  56: 32'h04924925,  57: 32'h047dc11f,  58: 32'h0469ee58,  59: 32'h0456c798,  60: 32'h04444444,  61: 32'h04325c54,  62: 32'h04210842,  
    63: 32'h04104104,  64: 32'h04000000,  65: 32'h03f03f04,  66: 32'h03e0f83e,  67: 32'h03d22635,  68: 32'h03c3c3c4,  69: 32'h03b5cc0f,  70: 32'h03a83a84,  71: 32'h039b0ad1,  
    72: 32'h038e38e4,  73: 32'h0381c0e0,  74: 32'h03759f23,  75: 32'h0369d037,  76: 32'h035e50d8,  77: 32'h03531dec,  78: 32'h03483483,  79: 32'h033d91d3,  80: 32'h03333333,  
    81: 32'h03291620,  82: 32'h031f3832,  83: 32'h03159722,  84: 32'h030c30c3,  85: 32'h03030303,  86: 32'h02fa0be8,  87: 32'h02f14990,  88: 32'h02e8ba2f,  89: 32'h02e05c0c,  
    90: 32'h02d82d83,  91: 32'h02d02d03,  92: 32'h02c8590b,  93: 32'h02c0b02c,  94: 32'h02b93105,  95: 32'h02b1da46,  96: 32'h02aaaaab,  97: 32'h02a3a0fd,  98: 32'h029cbc15,  
    99: 32'h0295fad4,  100: 32'h028f5c29,  101: 32'h0288df0d,  102: 32'h02828283,  103: 32'h027c4598,  104: 32'h02762762,  105: 32'h02702702,  106: 32'h026a439f,  
    107: 32'h02647c69,  108: 32'h025ed098,  109: 32'h02593f6a,  110: 32'h0253c825,  111: 32'h024e6a17,  112: 32'h02492492,  113: 32'h0243f6f0,  114: 32'h023ee090,  
    115: 32'h0239e0d6,  116: 32'h0234f72c,  117: 32'h02302302,  118: 32'h022b63cc,  119: 32'h0226b902,  120: 32'h02222222,  121: 32'h021d9ead,  122: 32'h02192e2a,  
    123: 32'h0214d021,  124: 32'h02108421,  125: 32'h020c49ba,  126: 32'h02082082,  127: 32'h02040810,  128: 32'h02000000,  129: 32'h01fc07f0,  130: 32'h01f81f82,  
    131: 32'h01f4465a,  132: 32'h01f07c1f,  133: 32'h01ecc07b,  134: 32'h01e9131b,  135: 32'h01e573ad,  136: 32'h01e1e1e2,  137: 32'h01de5d6e,  138: 32'h01dae607,  
    139: 32'h01d77b65,  140: 32'h01d41d42,  141: 32'h01d0cb59,  142: 32'h01cd8569,  143: 32'h01ca4b30,  144: 32'h01c71c72,  145: 32'h01c3f8f0,  146: 32'h01c0e070,  
    147: 32'h01bdd2b9,  148: 32'h01bacf91,  149: 32'h01b7d6c4,  150: 32'h01b4e81b,  151: 32'h01b20364,  152: 32'h01af286c,  153: 32'h01ac5702,  154: 32'h01a98ef6,  
    155: 32'h01a6d01a,  156: 32'h01a41a42,  157: 32'h01a16d40,  158: 32'h019ec8e9,  159: 32'h019c2d15,  160: 32'h0199999a,  161: 32'h01970e50,  162: 32'h01948b10,  
    163: 32'h01920fb5,  164: 32'h018f9c19,  165: 32'h018d3019,  166: 32'h018acb91,  167: 32'h01886e5f,  168: 32'h01861862,  169: 32'h0183c978,  170: 32'h01818182,  
    171: 32'h017f4060,  172: 32'h017d05f4,  173: 32'h017ad221,  174: 32'h0178a4c8,  175: 32'h01767dce,  176: 32'h01745d17,  177: 32'h01724288,  178: 32'h01702e06,  
    179: 32'h016e1f77,  180: 32'h016c16c1,  181: 32'h016a13cd,  182: 32'h01681681,  183: 32'h01661ec7,  184: 32'h01642c86,  185: 32'h01623fa7,  186: 32'h01605816,  
    187: 32'h015e75bc,  188: 32'h015c9883,  189: 32'h015ac057,  190: 32'h0158ed23,  191: 32'h01571ed4,  192: 32'h01555555,  193: 32'h01539095,  194: 32'h0151d07f,  
    195: 32'h01501501,  196: 32'h014e5e0a,  197: 32'h014cab88,  198: 32'h014afd6a,  199: 32'h0149539e,  200: 32'h0147ae14,  201: 32'h01460cbc,  202: 32'h01446f86,  
    203: 32'h0142d662,  204: 32'h01414141,  205: 32'h013fb014,  206: 32'h013e22cc,  207: 32'h013c995a,  208: 32'h013b13b1,  209: 32'h013991c3,  210: 32'h01381381,  
    211: 32'h013698df,  212: 32'h013521d0,  213: 32'h0133ae46,  214: 32'h01323e35,  215: 32'h0130d190,  216: 32'h012f684c,  217: 32'h012e025c,  218: 32'h012c9fb5,  
    219: 32'h012b404b,  220: 32'h0129e413,  221: 32'h01288b01,  222: 32'h0127350c,  223: 32'h0125e227,  224: 32'h01249249,  225: 32'h01234568,  226: 32'h0121fb78,  
    227: 32'h0120b471,  228: 32'h011f7048,  229: 32'h011e2ef4,  230: 32'h011cf06b,  231: 32'h011bb4a4,  232: 32'h011a7b96,  233: 32'h01194538,  234: 32'h01181181,  
    235: 32'h0116e069,  236: 32'h0115b1e6,  237: 32'h011485f1,  238: 32'h01135c81,  239: 32'h0112358e,  240: 32'h01111111,  241: 32'h010fef01,  242: 32'h010ecf57,  
    243: 32'h010db20b,  244: 32'h010c9715,  245: 32'h010b7e6f,  246: 32'h010a6811,  247: 32'h010953f4,  248: 32'h01084211,  249: 32'h01073261,  250: 32'h010624dd,  
    251: 32'h0105197f,  252: 32'h01041041,  253: 32'h0103091b,  254: 32'h01020408,  255: 32'h01010101,  256: 32'h01000000  
};

logic[63:0] price_reg = 64'b0;
logic[31:0] specified_reciprocal = 32'b0;

logic[63:0] low_reg = 64'b0;
logic[63:0] high_reg = 64'b0;
logic[127:0] final_reg = 128'b0;
//logic[95:0] final_reg = 96'b0;

logic window_is_one_stg1 = 1'b0;
logic window_is_one_stg2 = 1'b0;
logic window_is_one_stg3 = 1'b0;
logic[63:0] passthrough_price_stg2 = 64'b0;
logic[63:0] passthrough_price_stg3 = 64'b0;

logic stage1_done = 1'b0;
logic stage2_done = 1'b0;
logic stage3_done = 1'b0;

logic executing = 1'b0;

always_ff @(posedge clk) begin
    if (reset) begin
        executing <= 1'b0;
        price_reg <= 64'b0;
        specified_reciprocal <= 32'b0;
        low_reg <= 64'b0;
        high_reg <= 64'b0;
        final_reg <= 128'b0;
        stage1_done <= 1'b0;
        stage2_done <= 1'b0;
        stage3_done <= 1'b0;
        window_is_one_stg1 <= 1'b0;
        window_is_one_stg2 <= 1'b0;
        window_is_one_stg3 <= 1'b0;
        passthrough_price_stg2 <= 64'b0;
        passthrough_price_stg3 <= 64'b0;
    end
    
    else begin
        executing <= 1'b1;
        
        //stage 1
        stage1_done <= accumulator_done;
        window_is_one_stg1 <= accumulator_window_is_one;
        
        if (accumulator_done) begin
            price_reg <= accumulated_price;
            
            if (accumulator_sample_count > 1 && accumulator_sample_count <= 256)
                specified_reciprocal <= reciprocal_lut[accumulator_sample_count];
            else
                specified_reciprocal <= 32'b0;
        end
    
    
        //stage 2
        stage2_done <= stage1_done;
        window_is_one_stg2 <= window_is_one_stg1;
        passthrough_price_stg2 <= price_reg;
        low_reg  <= price_reg[31:0] * specified_reciprocal;
        high_reg <= price_reg[63:32] * specified_reciprocal;
    
    
        //stage 3
        stage3_done <= stage2_done;
        window_is_one_stg3 <= window_is_one_stg2;
        passthrough_price_stg3 <= passthrough_price_stg2;
        final_reg <= {high_reg, 32'b0} + {{64{1'b0}}, low_reg};
    end
end


assign divider_output = window_is_one_stg3 ? passthrough_price_stg3 : final_reg[95:32]; //check if divisor is 1, pass output without division, otherwise final_reg (division)
assign divider_done = stage3_done;


endmodule