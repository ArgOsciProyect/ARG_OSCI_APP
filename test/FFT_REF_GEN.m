% Script para calcular la FFT y guardar resultados en múltiples archivos CSV
clear; clc;

% Parámetros
filename = '/home/jotalora/Tesis/ARG_OSCI_APP/test/test_signal.csv';  % Nombre del archivo de entrada
fs = 1650000;                      % Frecuencia de muestreo (1.65 MHz)

% Leer los datos del archivo CSV
data = csvread(filename);

% Número de muestras
N = length(data);

% Calcular la FFT
fft_data = fft(data);

% Escala de frecuencia
frequencies = (0:N-1) * (fs / N);  

% Obtener la parte Real e Imaginaria, Magnitud
real_part = real(fft_data);
imag_part = imag(fft_data);
magnitude = abs(fft_data / N);

% Encontrar el máximo valor absoluto en los datos de entrada
max_value = max(abs(data));

% Convertir Magnitud a dB usando max_value como referencia
db_values = zeros(size(magnitude));
for i = 1:length(magnitude)
    if magnitude(i) == 0
        db_values(i) = -160;
    else
        % Use 1V as reference instead of max_value
        db_values(i) = 20 * log10(magnitude(i));
    end
end

% Limitar al espectro positivo
half_N = floor(N / 2);
frequencies = frequencies(1:half_N)';
real_part = real_part(1:half_N);
imag_part = imag_part(1:half_N);
magnitude = magnitude(1:half_N);
db_values = db_values(1:half_N);

% Guardar archivos
csvwrite('/home/jotalora/Tesis/ARG_OSCI_APP/test/Ref_real_img.csv', [real_part, imag_part]);
csvwrite('/home/jotalora/Tesis/ARG_OSCI_APP/test/Ref_magnitude.csv', [magnitude]);
csvwrite('/home/jotalora/Tesis/ARG_OSCI_APP/test/Ref_db.csv', [db_values]);

% Mostrar mensaje de éxito
disp('Resultados guardados en:');
disp('  Ref_real_img.csv (Real e Imaginario)');
disp('  Ref_magnitude.csv (Magnitud)');
disp('  Ref_db.csv (dB)');