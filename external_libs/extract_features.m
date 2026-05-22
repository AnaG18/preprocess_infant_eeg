function [powers, powers_norm, EEG] = extract_features(EEG, win_len, win_advance)
% EXTRACT_FEATURES Compute energy features from EEG data
%
% Usage:
%   [powers, powers_norm, EEG] = extract_features(EEG, win_len, win_advance)
%
% Inputs:
%   EEG          - EEGLAB EEG structure (continuous data)
%   win_len      - Window length in seconds (default = 0.5)
%   win_advance  - Window advance (step) in seconds (default = 0.5)
%
% Outputs:
%   powers       - Raw power features [nWindows x nChannels]
%   powers_norm  - Normalized power features [nWindows x nChannels]
%   EEG          - Original EEG structure

    % Default parameters
    if nargin < 2 || isempty(win_len)
        win_len = 0.5; % seconds
    end
    if nargin < 3 || isempty(win_advance)
        win_advance = 0.5; % seconds
    end

    % Sampling rate
    fs = EEG.srate;
    window_length_samples = round(fs * win_len);
    window_advance_samples = round(fs * win_advance);

    % Get data (channels x samples)
    data = EEG.data;
    nsamples = size(data, 2);

    % Initialize storage
    powers = [];
    powers_norm = [];

    % Sliding window
    window_start = 1; % MATLAB is 1-indexed
    while window_start <= (nsamples - window_length_samples + 1)

        % Extract segment
        X = data(:, window_start : window_start + window_length_samples - 1);

        % Compute power
        p = sum(X .^ 2, 2);                % per channel
        p_norm = p / window_length_samples;

        % Append
        powers = [powers; p'];
        powers_norm = [powers_norm; p_norm'];

        % Advance window
        window_start = window_start + window_advance_samples;
    end
end
