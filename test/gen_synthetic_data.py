import numpy as np
import random
import ca_code_gen

def generate_synthetic_data(num_svs_range = [1, 1], snr_range_db = [-10, -20], code_phase_error_range = [0, 1023], freq_error_range_hz = [0, 0], sv_search_range = [1, 1]):
    oversample_ratio = 4.0
    num_symbols = 4*4100
    phase_flip = 20 #BPSK every 20
    chip_rate = 1.023e6

    #for testing, lets constrain options

    #num_svs_range = [1, 4]
    #snr_range_db = [-10, -20]
    #code_phase_error_range = [0, 1023];
    #freq_error_range_hz = [-5000, 5000];
    #sv_search_range = [1, ca_code_gen.num_sv()]

    #num_svs_range = [1, 1]
    #snr_range_db = [-10, -20]
    #code_phase_error_range = [0, 1023];
    #freq_error_range_hz = [0, 0];
    #sv_search_range = [1, 1]

    num_svs = random.randint(num_svs_range[0], num_svs_range[1])
    print(f"Number sats for test: {num_svs}")
    sv_array = np.zeros(num_svs)
    target_snr_db_array = np.zeros(num_svs)
    target_snr_lin_array = np.zeros(num_svs)
    code_phase_error_array = np.zeros(num_svs)
    freq_error_hz_array = np.zeros(num_svs)
    for i in range(num_svs):
        if(i == 0):
            new_sv = random.randint(1, sv_search_range[1])
        else:
            #simulation allow multiple to speed up simulation (just test sv 1)
            #should only have one of each sv, make sure we don't have duplicates
            #while True:
                new_sv = random.randint(1, sv_search_range[1])    
                #check to see if it's unique
            #    if(np.size(np.where(sv_array == new_sv)) == 0):
            #        break
        sv_array[i] = new_sv
        target_snr_db_array[i] = random.randint(snr_range_db[1], snr_range_db[0])
        target_snr_lin_array[i] = 10.0**(target_snr_db_array[i]/10)
        code_phase_error_array[i] = random.randint(code_phase_error_range[0], int(code_phase_error_range[1]* oversample_ratio))
        freq_error_hz_array[i] = random.randint(freq_error_range_hz[0], freq_error_range_hz[1])
        print(f"Selected target SNR (db) : {target_snr_db_array[i]}")
        print(f"Target Code Phase Error (chips): {code_phase_error_array[i]/oversample_ratio}")
        print(f"Target Freq Error (Hz): {freq_error_hz_array[i]}" )
    
    upsampled_sym_len = 1023*int(oversample_ratio)

    synthetic_data_array = np.zeros((num_svs, upsampled_sym_len*(num_symbols)), dtype=complex)

    for sat_idx in range(num_svs):
        original_prn_biphase = np.array(ca_code_gen.PRN(int(sv_array[sat_idx])), dtype=complex)*2 -1
        oversampled_prn_cmplx = np.repeat(original_prn_biphase, int(oversample_ratio))
        phase_state = 1.0;
        for i in range(num_symbols):
            if i % phase_flip == 0:
                if(phase_state == 1):
                    phase_state=-1.0
                else:
                    phase_state=1.0
                #print(f"At symbol {i} phase state {phase_state}")
            synthetic_data_array[sat_idx][i*upsampled_sym_len:(i*upsampled_sym_len)+upsampled_sym_len] = oversampled_prn_cmplx*phase_state
        total_num_samples = len(synthetic_data_array[sat_idx])

        code_error_prefix = synthetic_data_array[sat_idx][0:int(code_phase_error_array[sat_idx])]
        modulated_osamp_prn_error = np.concatenate((synthetic_data_array[sat_idx][int(code_phase_error_array[sat_idx]):], code_error_prefix))

        #cross_correlate_check = np.correlate(synthetic_data_array[sat_idx], oversampled_prn_cmplx)
        #cross_correlate_check_error = np.correlate(modulated_osamp_prn_error, oversampled_prn_cmplx)
        
        synthetic_data_array[sat_idx] = modulated_osamp_prn_error
        #fig, ((ax0, ax1, ax2),(ax3, ax4, ax5)) = plt.subplots(2, 3, layout='constrained')
        #ax0.plot(np.real(cross_correlate_check/oversample_ratio)[:int(len(original_prn_biphase)/20)],'.') #dividing by the osamp ratio here.
        #ax1.plot(np.real(cross_correlate_check/oversample_ratio)[:int(len(original_prn_biphase)*oversample_ratio)]) #dividing by the osamp ratio here.
        #ax2.plot(np.real(cross_correlate_check/oversample_ratio))

        #ax3.plot(np.real(cross_correlate_check_error/oversample_ratio)[:int(len(original_prn_biphase)/20)],'.') #dividing by the osamp ratio here.
        #ax4.plot(np.real(cross_correlate_check_error/oversample_ratio)[:int(len(original_prn_biphase)*oversample_ratio)]) #dividing by the osamp ratio here.
        #ax5.plot(np.real(cross_correlate_check_error/oversample_ratio))

        #plt.show()

    chip_period = 1/chip_rate
    sample_period = chip_period/oversample_ratio
    synthetic_freq_array = np.zeros((num_svs, upsampled_sym_len*(num_symbols)), dtype=complex)
    #generate frequency phasor for each frequency error term
    time_array = np.arange(upsampled_sym_len*num_symbols, dtype=complex) * sample_period
    for sat_idx in range(num_svs):
        synthetic_freq_array[sat_idx] = np.cos(2*np.pi*freq_error_hz_array[sat_idx]*time_array) + 1j*np.sin(2*np.pi*freq_error_hz_array[sat_idx]*time_array)
        #fig, (ax0,ax1) = plt.subplots(1, 2, layout='constrained')
        #ax0.plot(np.real(synthetic_freq_array[sat_idx][0:1000]))
        #ax0.plot(np.imag(synthetic_freq_array[sat_idx][0:1000]))
        
        #ax1.plot(np.real(synthetic_freq_array[sat_idx]))
        #ax1.plot(np.imag(synthetic_freq_array[sat_idx]))
        #plt.show()
    
    #signal_power = np.mean(np.abs(modulated_osamp_prn)**2)
    #print(f"Signal Power: {signal_power}")
    synthetic_noise_array = np.zeros((num_svs, upsampled_sym_len*(num_symbols)), dtype=complex)
    for sat_idx in range(num_svs):
        noise_real = np.random.normal(0, np.sqrt(2)/2, total_num_samples) 
        noise_imag = np.random.normal(0, np.sqrt(2)/2, total_num_samples) 
        noise_signal = noise_real + 1j*noise_imag
        noise_signal_scaled = noise_signal * np.sqrt(1/target_snr_lin_array[sat_idx])
        #noise_power = np.mean(np.abs(noise_signal)**2)
        #noise_power_scaled = np.mean(np.abs(noise_signal_scaled)**2)
        synthetic_noise_array[sat_idx] = noise_signal_scaled
        #power_fft = np.abs(np.fft.fftshift(np.fft.fft(synthetic_data_array[sat_idx])))
        #noise_fft = np.abs(np.fft.fftshift(np.fft.fft(synthetic_noise_array[sat_idx])))
        #fig, (ax0) = plt.subplots(1, 1, layout='constrained')
        #ax0.plot(power_fft)
        #ax0.plot(noise_fft)
        #plt.show()
    
    #apply freq offset to base signals
    time_freq_signal_array = synthetic_data_array * synthetic_freq_array
    #for each satellite, add the noise, then normalise (so that when we sum everything, the signal + noise is all around the same power)
    combined_noisy_signal = np.zeros(upsampled_sym_len*(num_symbols), dtype=complex)

    for sv_idx in range(num_svs):
        print(f"SV IDX: {sv_idx}")
        signal_power = np.mean(np.abs(time_freq_signal_array[sv_idx])**2)
        noise_power = np.mean(np.abs(synthetic_noise_array[sv_idx])**2)
        sv_noisy_signal = time_freq_signal_array[sv_idx] + synthetic_noise_array[sv_idx]
        combined_sv_power = np.mean(np.abs(sv_noisy_signal)**2)
        norm_sv_noisy_signal = sv_noisy_signal * np.sqrt(1/combined_sv_power)
        combined_noisy_signal += norm_sv_noisy_signal;
        norm_power = np.mean(np.abs(norm_sv_noisy_signal)**2)
        print(f"Signal Power: {10*np.log10(signal_power)} Noise Power: {10*np.log10(noise_power)}")
        print(f"S+N Signal Power: {10*np.log10(combined_sv_power)} Norm Signal Power: {10*np.log10(norm_power)}")

    total_signal_power = np.mean(np.abs(combined_noisy_signal)**2)
    print(f"Total Signal Power: {total_signal_power}")

    return (combined_noisy_signal, num_svs, sv_array, target_snr_db_array, code_phase_error_array, freq_error_hz_array)