with open("lut_reciprocal_data.txt", "w") as f:
    f.write("0: 32'h00000000,\n")
    
    for i in range(1, 257):

        #2**32 scaled for Q0.32 fixed-point
        val = round((2**32) / i) if i > 1 else 0xFFFFFFFF

        #pad to 8 hex digits
        f.write(f"{i}: 32'h{val:08x},\n")