% filter_ref_gen.m
clear; clc;

pkg load signal

% Parameters
base_dir = '/home/joaquin/Facu/Tesis/ARG_OSCI_APP/test/unit_test/models/';
input_file = '/home/joaquin/Facu/Tesis/ARG_OSCI_APP/test/unit_test/models/test_signal.csv';
fs = 1650000;  % Sampling frequency

% Read input signal
data = csvread(input_file);
t = (0:length(data)-1)' / fs;

% Moving Average Filter
window_size = 3;
b_ma = ones(1, window_size) / window_size;
a_ma = 1;
ma_filtered_double = filtfilt(b_ma, a_ma, data);
ma_filtered_single = filter(b_ma, a_ma, data);

% Exponential Filter
alpha = 0.5;
b_exp = alpha;
a_exp = [1, -(1 - alpha)];
exp_filtered_double = filtfilt(b_exp, a_exp, data);
exp_filtered_single = filter(b_exp, a_exp, data);

% Low Pass Filter
cutoff_freq = 5000;  % 5kHz cutoff
[b, a] = butter(2, cutoff_freq/(fs/2));
lp_filtered_double = filtfilt(b, a, data);
lp_filtered_single = filter(b, a, data);

% Save results - double filtered (zero-phase)
csvwrite(fullfile(base_dir, 'ma_filtered_double_ref.csv'), ma_filtered_double);
csvwrite(fullfile(base_dir, 'exp_filtered_double_ref.csv'), exp_filtered_double);
csvwrite(fullfile(base_dir, 'lp_filtered_double_ref.csv'), lp_filtered_double);

% Save results - single filtered (with phase shift)
csvwrite(fullfile(base_dir, 'ma_filtered_single_ref.csv'), ma_filtered_single);
csvwrite(fullfile(base_dir, 'exp_filtered_single_ref.csv'), exp_filtered_single);
csvwrite(fullfile(base_dir, 'lp_filtered_single_ref.csv'), lp_filtered_single);
