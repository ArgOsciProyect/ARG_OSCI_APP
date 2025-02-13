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

% Moving Average Filter
window_size = 3;
ma_filtered = filter(ones(1, window_size)/window_size, 1, data);

% Exponential Filter
alpha = 0.5;
exp_filtered = filter(alpha, [1, -(1-alpha)], data, data(1));

% Low Pass Filter using filtfilt (zero-phase)
cutoff_freq = 5000;  % 5kHz cutoff
[b, a] = butter(2, cutoff_freq/(fs/2));
lp_filtered = filtfilt(b, a, data); % Changed to filtfilt

% Save results
csvwrite(fullfile(base_dir, 'ma_filtered_ref.csv'), ma_filtered);
csvwrite(fullfile(base_dir, 'exp_filtered_ref.csv'), exp_filtered);
csvwrite(fullfile(base_dir, 'lp_filtered_ref.csv'), lp_filtered);