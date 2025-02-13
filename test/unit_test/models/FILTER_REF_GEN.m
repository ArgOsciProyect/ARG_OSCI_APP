% filter_ref_gen.m
clear; clc;

pkg load signal

% Parameters
base_dir = '/home/jotalora/Tesis/ARG_OSCI_APP/test/unit_test/models';
input_file = fullfile(base_dir, 'test_signal.csv');
fs = 1650000;  % Sampling frequency

% Read input signal
data = csvread(input_file);
t = (0:length(data)-1)' / fs;

% Moving Average Filter using filtfilt (zero-phase)
window_size = 3;
b_ma = ones(1, window_size) / window_size;
a_ma = 1;
ma_filtered = filtfilt(b_ma, a_ma, data);

% Exponential Filter using filtfilt (zero-phase)
alpha = 0.5;
b_exp = alpha;
a_exp = [1, -(1 - alpha)];
exp_filtered = filtfilt(b_exp, a_exp, data);

% Low Pass Filter using filtfilt (zero-phase)
cutoff_freq = 5000;  % 5kHz cutoff
[b, a] = butter(2, cutoff_freq/(fs/2));
lp_filtered = filtfilt(b, a, data);

% Save results
csvwrite(fullfile(base_dir, 'ma_filtered_ref.csv'), ma_filtered);
csvwrite(fullfile(base_dir, 'exp_filtered_ref.csv'), exp_filtered);
csvwrite(fullfile(base_dir, 'lp_filtered_ref.csv'), lp_filtered);