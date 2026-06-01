import numpy as np
import sigmf
import os
import sys

def convert_sigmf_file(filename):
    firstpart_filename = filename.split('.')[0]
    bit_filename = firstpart_filename+"_iq_bitpacked.dat"
    dibit_filename = firstpart_filename+"_iq_dibitpacked.dat"
    print(f"Writing bit packed to {bit_filename}")
    print(f"Writing dibit packed to {dibit_filename}")
    handle = sigmf.sigmffile.fromfile(filename)
    # reading data
    handle.read_samples(autoscale=False)  # read all timeseries data
    num_samples = np.shape(handle)[0]
    print(f"Number of Samples: {num_samples}")
    num_bits = num_samples * 2 #one bits per sample, complex samples
    if(num_bits % 8 != 0):
        print("error number of samples inconsistent")
        return 0
    num_bytes = int(num_bits / 8)
    print(f"Resulting single bit IQ length (bytes): {num_bytes}")
    packed_dibit = np.zeros(num_bytes*2, dtype="uint8")
    packed_bit = np.zeros(num_bytes, dtype="uint8")
    offset_idx = 0
    percent_counter = 0
    one_percent_count = int(num_bytes/100)
    for i in range(10): #was numbytes
        if(percent_counter > one_percent_count):
            percent_counter = 0
            print(f"Completed {i} of {num_bytes}: {int((i/num_bytes)*100)}%")
        else:
            percent_counter = percent_counter + 1
        byte_val = 0x00
        di_byte_val = 0x00
        for j in range(4): #num of complex pairs per byte 
            complex_val = handle[offset_idx:offset_idx+1]
            print(f"For index {offset_idx} val {complex_val}")
            if(np.real(complex_val) < 0): #bit as per https://gnss-sdr.org/docs/sp-blocks/signal-source/
                byte_val = byte_val | 0x01
                di_byte_val = di_byte_val | 0x03
            byte_val = byte_val << 1
            di_byte_val = di_byte_val << 2
            if(np.imag(complex_val) < 0):
                byte_val = byte_val | 0x01
                di_byte_val = di_byte_val | 0x03
            if(j == 3):
                packed_bit[i] = byte_val
                print(hex(byte_val))
                packed_dibit[(i*2)+1] = di_byte_val
            else:
                byte_val = byte_val << 1
                if(j == 1):
                    packed_dibit[i*2] = di_byte_val
                    di_byte_val = 0x00
                else:
                    di_byte_val = di_byte_val << 2
            offset_idx = offset_idx+1
    #packed_bit.tofile(bit_filename)
    #packed_dibit.tofile(dibit_filename)
    
    bit_interleaved_array = np.packbits(np.array(handle[0:].view('float32')) < 0)
    dibit_interleaved_array = np.packbits(np.repeat(np.array(handle[0:].view('float32')) < 0,2))
    
    bit_interleaved_array.tofile(bit_filename)
    dibit_interleaved_array.tofile(dibit_filename)
    
    check_bits_file = open(bit_filename, "rb")
    bits_array = check_bits_file.read(10)
    for i in range(10):
        print(f"First {i} byte from bit packed file {hex(bits_array[i])}")
    check_bits_file.close()
    check_dibits_file = open(dibit_filename, "rb")
    dibits_array = check_dibits_file.read(10)
    for i in range(10):
        print(f"First {i} bytes from dibit packed file {hex(dibits_array[i])}")
    check_dibits_file.close()
    
    return 0
    
if __name__ == "__main__":
    convert_sigmf_file(sys.argv[1])
