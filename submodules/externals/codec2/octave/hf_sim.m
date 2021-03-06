% hf_sim.m
% David Rowe March 2014
%
% HF channel simulation.

function sim_out = hf_sim(sim_in, snr3kHz)

    % Init HF channel model from stored sample files of spreading signal ----------------------------------

    % convert "spreading" samples from 1kHz carrier at Fs to complex
    % baseband, generated by passing a 1kHz sine wave through PathSim
    % with the ccir-poor model, enabling one path at a time.
    
    Fc = 1000; Fs=8000;
    fspread = fopen("../raw/sine1k_2Hz_spread.raw","rb");
    spread1k = fread(fspread, "int16")/10000;
    fclose(fspread);
    fspread = fopen("../raw/sine1k_2ms_delay_2Hz_spread.raw","rb");
    spread1k_2ms = fread(fspread, "int16")/10000;
    fclose(fspread);

    % down convert to complex baseband
    spreadbb = spread1k.*exp(-j*(2*pi*Fc/Fs)*(1:length(spread1k))');
    spreadbb_2ms = spread1k_2ms.*exp(-j*(2*pi*Fc/Fs)*(1:length(spread1k_2ms))');

    % remove -2000 Hz image
    b = fir1(50, 5/Fs);
    spread = filter(b,1,spreadbb);
    spread_2ms = filter(b,1,spreadbb_2ms);

    % discard first 1000 samples as these were near 0, probably as
    % PathSim states were ramping up

    spread    = spread(1000:length(spread));
    spread_2ms = spread_2ms(1000:length(spread_2ms));

    hf_gain = 1.0/sqrt(var(spread)+var(spread_2ms));

    % 300 - 3000 Hz filter

    b = fir1(100,[300/4000, 3000/4000], 'pass');
    
    % det power of unit variance noise passed through this filter
    
    filter_var = var(filter(b,1,randn(1000,1)));
    
    % Start simulation

    s = hilbert(filter(b,1,sim_in));
    n1 = length(s); n2 = length(spread);
    n = min(n1,n2);
    path1 = s(1:n) .* spread(1:n);
    path2 = s(1:n) .* spread_2ms(1:n);
    delay = floor(0.002*Fs);

    combined = path1(delay+1:n) + path2(1:n-delay);

    snr = 10 .^ (snr3kHz/10);
    variance = (combined'*combined)/(snr*n);
    noise = sqrt(variance*0.5/filter_var)*(randn(n-delay,1) + j*randn(n-delay,1));
    filtered_noise = filter(b,1,noise);
 
    sim_out = real(combined+filtered_noise);
    printf("measured SNR: %3.2fdB\n", 10*log10(var(real(combined))/var(real(filtered_noise))));

    figure(1);
    plot(s);
    figure(2)
    plot(real(combined))
    figure(2)
    plot(sim_out)

endfunction

