function figHandle = plot_powers_heatmap(powers, chanLabels, cmap)
% PLOT_POWERS_HEATMAP Plot normalized powers as a covariance heatmap
%
% Usage:
%   figHandle = plot_powers_heatmap(powers, chanLabels, cmap)
%
% Inputs:
%   powers     - Matrix [nWindows x nChannels] from extract_features
%   chanLabels - Cell array of channel labels {1 x nChannels}
%   cmap       - Colormap name (default = 'parula')
%
% Outputs:
%   figHandle  - Handle to the created figure

    if nargin < 3 || isempty(cmap)
        cmap = 'parula'; % Default colormap
    end

    % Normalize powers across windows
    powers_norm = powers ./ max(powers(:));

    % Compute covariance matrix across channels (channels x channels)
    cov_m = cov(powers_norm, 1); % 1 for normalization by N
    cov_m = cov_m / max(cov_m(:)); % normalize to [0,1]

    % Create figure
    figHandle = figure('Name','Powers Covariance Heatmap','NumberTitle','off');
    imagesc(cov_m);
    colormap(cmap);
    colorbar;

    % Axes labels
    xlabel('Channel');
    ylabel('Channel');

    % Channel labels
    if exist('chanLabels','var') && ~isempty(chanLabels)
        nCh = length(chanLabels);
        xticks(1:nCh);
        yticks(1:nCh);
        xticklabels(chanLabels);
        yticklabels(chanLabels);
        xtickangle(45); % rotate X labels for readability
    end

    % Make plot square
    axis square;
    set(gca, 'FontSize', 10, 'TickDir', 'out');
    title('Normalized Covariance of Channel Powers');
end
