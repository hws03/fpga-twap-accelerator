#generate random prices and valid ticks/pulses
#copy twap_input_data.txt into xsim
import os
import random

num_samples = 255  #must be a power of 2 (256-1 because last line adds an extra empty line)

directory = r"..\sv\fpga-twap-engine.sim\sim_1\behav\xsim"
os.makedirs(directory, exist_ok=True)

save_file_to = os.path.join(directory, "twap_input_data.txt")

with open(save_file_to, "w") as f:
    for i in range(num_samples):
        price = int((i + 50) * 100)
        price_hex = f"{price:08X}"

        valid = 1 if random.random() > 0.45 else 0
        
        f.write(f"{valid} {price_hex}\n")

print("data file generated and saved to vivado project sim_1/behav/xsim folder")