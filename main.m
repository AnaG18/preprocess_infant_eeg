%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


clear, close all
restoredefaultpath
clc

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PATHS - DO NOT CHANGE
%
% Specify the paths to the different relevant folders
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Path0 = fileparts(mfilename('fullpath')); % Main project path 
Path2SAVE = fullfile(project_root, 'data', 'processed'); % A new subfolder in the data folder will be created unless specified otherwise
Path2Data = fullfile(Path0, 'data\raw\raw_BIDS\sub-*\'); % Folder where the data is

if ~exist(Path2SAVE, 'dir')
    mkdir(Path2SAVE)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Path2EEGLAB = 'C:\Users\NCSL-Workstation\Downloads\eeglab2025.0.0'; % Folder where EEGLAB is 
Path2APICE = fullfile(project_root, 'external_libs', 'APICE-preprocessing-pipeline'); % Folder where the function for APICE are
Path2iMARA = fullfile(project_root, 'external_libs', 'iMARA'); % Folder where iMARA is
Path2HAPPE = fullfile(project_root, 'external_libs', 'HAPPE-preprocessing-pipeline'); % Folder where HAPPE functions are
Path2Parameters = fullfile(Path2APICE, '\examples\example_CuttingEEG\parameters'); % Folder where the scripts with the parameters are 
filechanloc = fullfile(Path2APICE, 'examples\example_CuttingEEG\ElectrodesLayout\GSN-HydroCel-129.sfp'); % File with the channels layout 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ADD TOOLBOXES AND PATHS TO USEFUL FOLDERS
%
% Add to the path the required toolboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Add EEGLAB to the path
cd(Path2EEGLAB)
eeglab
close all

addpath(genpath(Path2APICE)) % Add the functions for APICE
addpath(genpath(Path2iMARA)) % Add iMARA
addpath(Path2Parameters) % Add the path to the folder with the parameters

addpath('C:\Users\NCSL-Workstation\OneDrive - Johns Hopkins\NCSL\code');

cd(Path0) % Got to the path where the main scripts are

%%%%%%
%% Channel locations YOU WANT TO KEEP
% chan_IDs={'FP1' 'FP2' 'F3' 'F4' 'F7' 'F8' 'C3' 'C4' 'T3' 'T4' 'PZ' 'O1' 'O2' ...
%     'T5' 'T6' 'P3' 'P4' 'Fz' 'E27' 'E23' 'E19' 'E20' 'E28' 'E13' 'E41' 'E40' 'E46'...
%     'E47' 'E75' 'E3' 'E4' 'E123' 'E118' 'E112' 'E117' 'E109' 'E102' 'E98' 'E103'};
chan_IDs = {'FP1' 'FP2' 'F3' 'F4' 'F7' 'F8' 'C3' 'C4' 'T3' 'T4' 'PZ' 'O1' 'O2' 'T5' 'T6' 'P3' 'P4' 'Fz'};
chan_locations = [Path2HAPPE filesep 'acquisition_layout_information' filesep 'GSN-HydroCel-129.sfp'];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOGGING SYSTEM SETUP
%
% Setup for tracking processed and bad files with detailed metrics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Create log file path
logFilePath = fullfile(Path2SAVE, 'processing_log.mat');

% Initialize or load processing log
if exist(logFilePath, 'file')
    load(logFilePath, 'processingLog');
    fprintf('Loaded existing processing log with %d entries\n', length(processingLog.files));
else
    processingLog = struct();
    processingLog.files = {};
    processingLog.processed = [];
    processingLog.isBad = [];
    processingLog.timestamp = {};
    processingLog.notes = {};
    processingLog.batch = {};
    
    % Add detailed metrics fields
    processingLog.file_length_secs = [];
    processingLog.num_channels_selected = [];
    processingLog.num_segments_post_rejection = [];
    processingLog.num_good_channels = [];
    processingLog.percent_good_channels = [];
    processingLog.interpolated_channel_ids = {};
    processingLog.num_ics_rejected = [];
    processingLog.percent_ics_rejected = [];
    processingLog.percent_variance_kept = [];
    processingLog.median_artifact_prob = [];
    processingLog.mean_artifact_prob = [];
    processingLog.range_artifact_prob = [];
    processingLog.min_artifact_prob = [];
    processingLog.max_artifact_prob = [];
    
    fprintf('Created new processing log with detailed metrics\n');
end

% Create a function to update the log with detailed metrics
updateLogWithMetrics = @(filename, isProcessed, isBad, notes, metrics, currentBatch) updateProcessingLogWithMetrics(...
    logFilePath, filename, isProcessed, isBad, notes, metrics, currentBatch);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PARAMETERS - CHANGES CAN BE MADE FROM HERE ON 
%
% Define all the required parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

path = fullfile(project_root, 'data', 'participants.tsv'); % Define the path to the TSV file with BIDS format 
df = readtable(path, 'FileType', 'text', 'Delimiter', '\t'); % Read the TSV file into a table 
disease_rows = ~strcmp(df.diagnosis, 'No Diagnosis'); % Find IDS that do have a diagnosis
disease_ids = unique(df.EID(disease_rows)); % Get the unique EID values

% .........................................................................
% Manual inspection and rejection parameters TODO!!!!!! 
% .........................................................................
ENABLE_MANUAL_BADCHANS = true;  % Enable manual bad channel selection
ENABLE_VISUAL_INSPECTION = true; % Enable visual inspection at key steps
PLOT_WINLENGTH = 30;             % Window length for plots (seconds)
PLOT_DISPCHANS = 40;            % Number of channels to display
SELECT_SUBSET = 1;              % Choose only a subset of the channels. 
ENABLE_MANUAL_BADSEGS = false; 

% Default cutting behavior
CUT_EEG = true; % Set to false to skip cutting
DEFAULT_CUT = false; % Set to false to specify custom time range
CUT_FIRST_SECONDS = 15; % Seconds to cut from beginning (if default)
CUT_LAST_SECONDS = 15; % Seconds to cut from end (if default)

% Custom time range (if DEFAULT_CUT is false)
CUSTOM_START_TIME = 0; % Start time in seconds
CUSTOM_END_TIME = 300; % End time in seconds

% .........................................................................
% Raw files names
% .........................................................................
rawfiles = 'sub-*_task-RestingState_eeg.set';

% .........................................................................
% Parameters for resampling 
% .........................................................................
do_resample = 1; 
new_srate = 250; % Select new sample rate
% .........................................................................
% Parameters dealing with events 
% .........................................................................
do_arreangeevents = 0;
Ppp.events = ex2_Ppp_Events;

% .........................................................................
% Parameters for filtering
% .........................................................................
Ppp.filt = ex2_Ppp_Filtering;

% .........................................................................
% Parameters for artifacts detection
% .........................................................................
Ppp.Art.BadEl = ex2_Ppp_Art_BadEl;
Ppp.Art.Jump = ex2_Ppp_Art_Jump;
Ppp.Art.Mot1 = ex2_Ppp_Art_Mot1;
Ppp.Art.Mot2 = ex2_Ppp_Art_Mot2;

% .........................................................................
% Parameters for transient artifacts interpolation using target PCA
% .........................................................................
Ppp.Int.pca = ex2_Ppp_Int_tPCA;

% .........................................................................
% Parameters for artifacts interpolation using spherical spline
% .........................................................................
Ppp.Int.spl = ex2_Ppp_Int_Spl;

options_interspatialsegments = {...
    Ppp.Int.spl.p,...
    'pneigh', Ppp.Int.spl.pneigh,...
    'splicemethod', Ppp.Int.spl.splicemethod,...
    'mingoodtime', Ppp.Int.spl.minGoodTime,...
    'minintertime', Ppp.Int.spl.minInterTime,...
    'masktime', Ppp.Int.spl.maskTime};

options_targetPCA = {...
    Ppp.Int.pca.nSV,...
    Ppp.Int.pca.vSV,...
    'maxTime', Ppp.Int.pca.maxTime,...
    'maskTime', Ppp.Int.pca.maskTime,...
    'splicemethod', Ppp.Int.pca.splicemethod};

% .........................................................................
% Parameters to define Bad Times (BT) and Bad Channels (BC) 
% .........................................................................
Ppp.BTBC = ex2_Ppp_DefBTBC;

options_BTBC = {...
    Ppp.BTBC.BT.nbc,...
    Ppp.BTBC.BC.nbt,...
    Ppp.BTBC.BC.nbt,...
    'minBadTime', Ppp.BTBC.BT.minBadTime,...
    'minGoodTime', Ppp.BTBC.BT.minGoodTime,...
    'maskTime', Ppp.BTBC.BT.maskTime,...
    'keeppre', 0};

% .........................................................................
% Parameters for W-ICA
% .........................................................................
Ppp.ica = ex2_Ppp_wICA;
do_applyICA = 1;

options_ica = {...
    'filthighpass',Ppp.ica.filthighpass,...
    'filtlowpass', Ppp.ica.filtlowpass,...
    'npc', 24,...
    'classifyIC', Ppp.ica.classifyIC,...
    'classifyICfun', Ppp.ica.classifyICfun,...
    'changelabelch',Ppp.ica.changelabelch,...
    'labelch',Ppp.ica.labelch,...
    'saveica',Ppp.ica.saveica,...
    'icaname',Ppp.ica.icaname,...
    'icapath',Ppp.ica.icapath};

% .........................................................................
% Plotting
% .........................................................................
do_plotrejection = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PRE-PROCESSING
%
% Run the pre-processing for all subjects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

filesPerBatch = 11;  % Number of files per batch

% Generate a list of files to analyze 
SBJs = eega_getfilesinfolders(Path2Data, rawfiles);
nFiles = numel(SBJs);
totalBatches = ceil(nFiles / filesPerBatch);

% Load/create processing log
logFilePath = fullfile(Path2SAVE, 'processing_log.mat');
if exist(logFilePath, 'file')
    load(logFilePath, 'processingLog');
else
    processingLog = struct();
    processingLog.files = {};                 % cellstr of filenames like 'prp_xxx.set'
    processingLog.processed = [];             % numeric/logical vector (1 processed, 0 not)
    processingLog.isBad = [];                 % numeric/logical vector
    processingLog.timestamp = {};             % cellstr
    processingLog.notes = {};                 % cellstr
    processingLog.batch = [];                 % numeric vector (keep numeric for easier indexing)
    save(logFilePath, 'processingLog');
end

% Normalize types (helpful if previous runs mixed types)
if ~isfield(processingLog,'batch'), processingLog.batch = []; end
if iscell(processingLog.batch), processingLog.batch = cellfun(@double, processingLog.batch); end

batchProcessed = zeros(1, totalBatches);  % 0 = not fully processed, 1 = fully processed

% Canonical key builder: basename (name+ext), lowercase, strip leading prefixes
get_key = @(p) lower( regexprep( ...
                    [ get_basename(p) ], ...
                    '^(prp_|raw_|preproc_)', '' ) );

function b = get_basename(p)
    [~, n, e] = fileparts(p);
    b = [n e];
end


for batchIdx = 1:totalBatches
    startFile   = (batchIdx-1)*filesPerBatch + 1;
    endFile     = min(batchIdx*filesPerBatch, nFiles);
    filesInBatch = SBJs(startFile:endFile);

    filesToProcess = {};  % reset per batch

    for i = 1:numel(filesInBatch)
        % Build expected processed filename in Path2SAVE
        [~, sbjname, ext] = fileparts(filesInBatch{i});
        subjFileName = ['prp_' sbjname ext];
        filePath = fullfile(Path2SAVE, subjFileName);
        onDisk = (exist(filePath, 'file') == 2 || exist(filePath, 'file') == 7);

        % Build the key for the current subject (processed name)
        subjKey = get_key(subjFileName);
        
        % Build keys for everything in the log (once per batch for speed if you want)
        logKeys = cellfun(@(p) get_key(p), processingLog.files, 'UniformOutput', false);
        
        % Match by canonical key
        logIndex = find(strcmp(logKeys, subjKey), 1);

        % If known and marked bad -> skip entirely (doesn't block the batch)
        if ~isempty(logIndex) && logIndex <= numel(processingLog.isBad) ...
                && processingLog.isBad(logIndex)
            continue
        end

        if onDisk
            % Exists on disk
            if isempty(logIndex)
                % Not logged yet -> add as processed
                processingLog.files{end+1}      = subjFileName;
                processingLog.processed(end+1)  = 1;
                processingLog.isBad(end+1)      = 0;
                processingLog.timestamp{end+1}  = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                processingLog.notes{end+1}      = 'Processed, added to log (found on disk)';
                processingLog.batch(end+1)      = batchIdx;
            else
                % Logged but maybe marked unprocessed -> fix it
                if logIndex <= numel(processingLog.processed) && ~processingLog.processed(logIndex)
                    processingLog.processed(logIndex) = 1;
                    processingLog.timestamp{logIndex} = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                    processingLog.notes{logIndex}     = 'Processed (already on disk); status synced';
                end
                if logIndex <= numel(processingLog.batch) && (isempty(processingLog.batch(logIndex)) || processingLog.batch(logIndex) == 0)
                    processingLog.batch(logIndex) = batchIdx;
                end
            end
        else
            % Not on disk -> needs processing unless bad (handled above)
            filesToProcess{end+1} = subjFileName; %#ok<AGROW>
        end
    end

    % Batch status: complete if no good files remain to process (bad files are ignored)
    batchProcessed(batchIdx) = isempty(filesToProcess);

    fprintf('Batch %d: %d/%d files to process (bad files skipped)\n', ...
            batchIdx, numel(filesToProcess), numel(filesInBatch));
end


% Find the first batch that is not fully processed

 currentBatch = find(batchProcessed == 0, 1);
if isempty(currentBatch)
    fprintf('All batches have been processed. Nothing to do.\n');
    return;
  end

fprintf('Processing batch %d of %d\n', currentBatch, totalBatches);

% --- pick the current batch window ---
startIdx     = (currentBatch-1)*filesPerBatch + 1;
endIdx       = min(currentBatch*filesPerBatch, numel(SBJs));
SBJs_batch   = SBJs(startIdx:endIdx);

% --- build the to-do list *within* the current batch ---
filesToProcessBatch = {};
logKeys = cellfun(@(p) get_key(p), processingLog.files, 'UniformOutput', false);  % precompute once

% --- pick the current batch window ---
startIdx     = (currentBatch-1)*filesPerBatch + 1;
endIdx       = min(currentBatch*filesPerBatch, numel(SBJs));
SBJs_batch   = SBJs(startIdx:endIdx);

% --- build the to-do list *within* the current batch ---
filesToProcessBatch = {};
logKeys = cellfun(@(p) get_key(p), processingLog.files, 'UniformOutput', false);  % precompute once

for i = 1:numel(SBJs_batch)
    rawFilePath = SBJs_batch{i};   % <-- this is the full raw path
    [~, sbjname, ext] = fileparts(rawFilePath);
    subjFileName = ['prp_' sbjname ext];   % processed name used in Path2SAVE

    % check if processed file exists in Path2SAVE
    procPath = fullfile(Path2SAVE, subjFileName);
    onDisk = (exist(procPath, 'file') == 2 || exist(procPath, 'file') == 7);

    % canonical key for log lookup
    subjKey  = get_key(subjFileName);
    logIndex = find(strcmp(logKeys, subjKey), 1);

    % flags from log
    isBad = ~isempty(logIndex) && logIndex <= numel(processingLog.isBad) ...
            && logical(processingLog.isBad(logIndex));
    isLoggedProcessed = ~isempty(logIndex) && logIndex <= numel(processingLog.processed) ...
            && logical(processingLog.processed(logIndex));

    % a file is "done" if it exists on disk OR it’s marked processed in the log
    isDone = onDisk || isLoggedProcessed;

    % queue only if NOT bad and NOT done
    if ~isBad && ~isDone
        filesToProcessBatch{end+1} = rawFilePath; %#ok<AGROW>
    end
end

% --- optionally start at the first pending file (by slicing SBJs_batch) ---
if ~isempty(filesToProcessBatch)
    % Find the first pending file's position to report (not required for processing)
    firstPending = filesToProcessBatch{1};
    fprintf('Batch %d: %d files pending (starting at first pending).\n', ...
            currentBatch, numel(filesToProcessBatch));
else
    fprintf('Batch %d: nothing pending (all processed or marked bad).\n', currentBatch);
end

uiwait(msgbox(['Processing batch: ' num2str(currentBatch)]));

batchLog = struct();
batchLog.files = {};
batchLog.processed = [];
batchLog.isBad = [];
batchLog.timestamp = {};
batchLog.notes = {};
batchLog.batch = {};

% Add detailed metrics fields
batchLog.file_length_secs = [];
batchLog.num_channels_selected = [];
batchLog.num_segments_post_rejection = [];
batchLog.num_good_channels = [];
batchLog.percent_good_channels = [];
batchLog.interpolated_channel_ids = {};
batchLog.num_ics_rejected = [];
batchLog.percent_ics_rejected = [];
batchLog.percent_variance_kept = [];
batchLog.median_artifact_prob = [];
batchLog.mean_artifact_prob = [];
batchLog.range_artifact_prob = [];
batchLog.min_artifact_prob = [];
batchLog.max_artifact_prob = [];

for sbj = 1:length(filesToProcessBatch)
    filePath = filesToProcessBatch{sbj};
     [sbjfolder, txt, ext] = fileparts(filePath);

    parts = split(txt, '_');       % split by underscore
    sbjname = parts{1};  

    isOCD = ismember(sbjname, disease_ids);

    % Check if file should be processed based on logBatchLog, filePath, saveFolder
    [shouldProcess, isMarkedBad, logIndex] = checkFileStatus(batchLog, filePath, Path2SAVE, currentBatch);
    
    if ~shouldProcess
        if isMarkedBad
            fprintf('Skipping file %s: Marked as BAD in log%s\n', sbjname, ternary(ismember(sbjname, disease_ids), ' (OCD)', ''));
            SBJs_bad{sbj} = [sbjname '_bad'];
            SBJs_prp{sbj} = [];

            % BAD file case
            batchLog = addToBatchLog(batchLog, filePath, false, true, 'Marked as bad file', struct(), currentBatch);
        else
            fprintf('Skipping file %s: Already processed and saved\n', sbjname);
            SBJs_skp{sbj} = [sbjname '_skipped'];
            batchLog = addToBatchLog(batchLog, filePath, true, false, 'Skipped (already processed)', struct(), currentBatch);
        end
        continue;
    end
    
    fprintf('\nProcessing file: %s\n', sbjname);
    
    % ---------------------------------------------------------------------
    % Load the data

    EEG = pop_loadset(filePath);

    if all(EEG.data(:) == 0)
        batchLog = addToBatchLog(batchLog, filePath, false, true, 'Marked as bad file', struct(), currentBatch); 
        continue; 
    end

    subjID = num2str(EEG.subject);
    % Check if the subject ID matches the filepath
    if contains(filePath, subjID)
        uiwait(msgbox(['Processing subject: ' subjID char(isOCD*' (OCD)')]));
    else
        warning('Subject name does NOT match the file path! File: %s, Subject: %s', filePath, subjID);
        uiwait(msgbox(['WARNING: Subject name does NOT match file path!' newline ...
                       'File: ' filePath newline 'Subject: ' subjID]));
    end

    % ---------------------------------------------------------------------
    % Import the channels location file
    EEG = pop_chanedit(EEG, 'load', {filechanloc 'filetype' 'autodetect'});
    EEG = eeg_checkset( EEG );

    %load 10-20 EEG system labels for electrode names (for MARA to reference)
    load('C:\Users\NCSL-Workstation\OneDrive - Johns Hopkins\NCSL\code\HAPPE-preprocessing-pipeline\acquisition_layout_information\happe_netdata_lib.mat')
    %for 128 channel nets:
    if EEG.nbchan >65
        for i=1:length(netdata_lib.net128.lead_nums_sub)
            EEG=pop_chanedit(EEG, 'changefield',{netdata_lib.net128.lead_nums_sub(i)  'labels' netdata_lib.net128.lead_list_sub{i}});
        end
        %for 64 channel nets
    elseif EEG.nbchan > 50
        for i=1:length(netdata_lib.net64.lead_nums_sub)
            EEG=pop_chanedit(EEG, 'changefield',{netdata_lib.net64.lead_nums_sub(i)  'labels' netdata_lib.net64.lead_list_sub{i}});
        end
    end

    if SELECT_SUBSET
        EEG = pop_select( EEG,'channel', chan_IDs);
        EEG = eeg_checkset( EEG );
        full_selected_channels = EEG.chanlocs;
    end
    EEG = eeg_checkset( EEG );

        % ---------------------------------------------------------------------
    % Resample
    if do_resample == 1
        EEG = pop_resample(EEG, new_srate); % resample
        srate = new_srate; 
    end

    % ---------------------------------------------------------------------
    % Filter
    % remove the mean
    EEG = eega_demean(EEG);
    
    % low-pass
    EEG = pop_eegfiltnew(EEG, [], Ppp.filt.lowpass,  [], 0, [], [], 0);
    
    % high-pass
    EEG = pop_eegfiltnew(EEG, Ppp.filt.highpass, [], [], 0, [], [], 0);
    
    % notch 
    EEG = pop_eegfiltnew(EEG, Ppp.filt.notch(1), Ppp.filt.notch(2), [], 1, [], [], 0);

    if all(EEG.data(:) == 0)
        batchLog = addToBatchLog(batchLog, filePath, false, true, 'Marked as bad file', struct(), currentBatch); 
        continue; 
    end
    % ---------------------------------------------------------------------
    % VISUAL INSPECTION 1: Raw data
    if ENABLE_VISUAL_INSPECTION
        fprintf('\n=== VISUAL INSPECTION: Raw Data ===\n');

        % --- Spectral plot on the right ---
        pop_spectopo(EEG, 1, [0 EEG.xmax*1000], 'EEG', ...
            'freq', [2 50], 'freqrange', [2 50], 'percent', 100);
        spectFig = gcf;
        eega_plot_rejection(EEG, 1, 1, 1, 120)
        rawFig = gcf;

        arrangeFiguresSideBySide([spectFig, rawFig], isOCD);

        uiwait(msgbox('Look at spectral plots to reject channels'));
        % Ask user if this file should be marked as bad
        answer = questdlg('Should this file be marked as COMPLETELY BAD?', ...
            'File Quality Assessment', ...
            'Yes, mark as BAD', 'No, continue processing', 'Cancel processing', ...
            'No, continue processing');
        
        switch answer
            case 'Yes, mark as BAD'
                fprintf('File %s marked as COMPLETELY BAD by user\n', sbjname);
                SBJs_bad{sbj} = [sbjname '_bad'];
                batchLog = addToBatchLog(batchLog, filePath, true, true, 'Marked as bad file', struct(), currentBatch);
                close all;
                continue; % Skip to next file
            case 'Cancel processing'
                fprintf('Processing cancelled by user\n');
                close all;
                return;
            otherwise
                % Continue processing
        end
        close all; 
    end

    % ---------------------------------------------------------------------
    % TIME SELECTION: Cut EEG data if requested
    % ---------------------------------------------------------------------
    cutTimes = struct();
    if CUT_EEG
        fprintf('=== TIME SELECTION ===\n');
        
        if DEFAULT_CUT
            % Default cutting: first and last 15 seconds
            startTime = CUT_FIRST_SECONDS;
            endTime = EEG.xmax - CUT_LAST_SECONDS;
            fprintf('Using default cutting: first %d sec and last %d sec\n', ...
                CUT_FIRST_SECONDS, CUT_LAST_SECONDS);
        else
            % Custom time range
            % Prompt user for custom time range
            pop_eegplot(EEG, 1, 1, 1, [], 'winlength', PLOT_WINLENGTH, 'dispchans', min(PLOT_DISPCHANS, EEG.nbchan));
            set(gcf, 'Name', 'Raw Data - Before Processing');
            uiwait(msgbox('Select custom time range to cut (if nothing is selected it will default to 15s). Click OK to continue.'));
            prompt = {sprintf('Start time (0 - %.1f seconds):', EEG.xmax), ...
                     sprintf('End time (0 - %.1f seconds):', EEG.xmax)};
            dlgtitle = 'Custom Time Selection';
            dims = [1 35];
            definput = {num2str(CUSTOM_START_TIME), num2str(CUSTOM_END_TIME)};
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            close(gcf);
            
            if ~isempty(answer)
                startTime = str2double(answer{1});
                endTime = str2double(answer{2});
            else
                % User canceled, use default values
                startTime = CUT_FIRST_SECONDS;
                endTime = EEG.xmax - CUT_LAST_SECONDS;
                fprintf('Using predefined custom time range: %.1f to %.1f seconds\n', ...
                    startTime, endTime);
            end
        end
        
        % Validate time range
        if startTime < 0
            startTime = 0;
            fprintf('Warning: Start time adjusted to 0 (minimum)\n');
        end
        if endTime > EEG.xmax
            endTime = EEG.xmax;
            fprintf('Warning: End time adjusted to %.1f (maximum)\n', EEG.xmax);
        end
        if startTime >= endTime
            fprintf('Error: Invalid time range (%.1f to %.1f). Skipping cutting.\n', ...
                startTime, endTime);
        else
            % Cut the EEG data
            originalLength = EEG.xmax;
            EEG = pop_select(EEG, 'time', [startTime endTime]);
            fprintf('Cut EEG from %.1f to %.1f seconds (%.1f seconds total)\n', ...
                startTime, endTime, EEG.xmax);
            
            % Store cut information
            cutTimes.originalLength = originalLength;
            cutTimes.startTime = startTime;
            cutTimes.endTime = endTime;
            cutTimes.duration = EEG.xmax;
        end
    else
        fprintf('Skipping EEG cutting (CUT_EEG = false)\n');
    end

    % ---------------------------------------------------------------------
    % MANUAL BAD SEGMENT REJECTION
    if ENABLE_MANUAL_BADSEGS
        fprintf('\n=== MANUAL BAD SEGMENT REJECTION ===\n');
        
    
        % Open interactive plot (scrolling window)
        pop_eegplot(EEG, 1, 1, 1, [], 'winlength', PLOT_WINLENGTH, 'dispchans', min(PLOT_DISPCHANS, EEG.nbchan));
    
        uiwait(msgbox('After marking segments, click REJECT in the EEG plot and then press OK here','Info','modal'));
        % Make sure EEG.artifacts exists
        if ~isfield(EEG, 'artifacts') || isempty(EEG.artifacts)
            EEG.artifacts = struct();
        end
        % Make sure BCmanual exists
        if ~isfield(EEG.artifacts, 'BCmanual') || isempty(EEG.artifacts.BCmanual)
            EEG.artifacts.BCmanual = false(size(EEG.data)); % same shape as BCT
        end
        
        nChans  = size(EEG.data,1);
        nSamps  = size(EEG.data,2);
        srate   = EEG.srate;
        
        for k = 1:size(TMPREJ,1)
            % --- get time window in samples
            startSmp = round(TMPREJ(k,1) * srate);
            endSmp   = round(TMPREJ(k,2) * srate);
            startSmp = max(startSmp,1);
            endSmp   = min(endSmp,nSamps);
        
            % --- quick plot of this time window
            figure; 
            t = (0:nSamps-1)/srate;
            plot(t, EEG.data'); 
            hold on;
            yl = ylim;
            patch([startSmp endSmp endSmp startSmp]/srate, ...
                  [yl(1) yl(1) yl(2) yl(2)], ...
                  [1 0.8 0.8], 'FaceAlpha',0.4, 'EdgeColor','none');
            title(sprintf('Marked interval %d: %.2f–%.2f sec', k, TMPREJ(k,1), TMPREJ(k,2)));
        
            % --- ask user: all channels or subset?
            applyAll = input('Apply to ALL channels? (y/n): ','s');
            
            if strcmpi(applyAll,'y')
                EEG.artifacts.BCmanual(:, startSmp:endSmp, :) = true;
            else
                chans = input(sprintf('Enter channel indices (1–%d) as vector: ', nChans));
                % validate input
                if isnumeric(chans) && all(chans >= 1) && all(chans <= nChans)
                    EEG.artifacts.BCmanual(chans, startSmp:endSmp, :) = true;
                else
                    warning('Invalid channel selection. Skipping interval %d.', k);
                end
            end
            close(gcf); % close plot after decision
        end


        close all
    end

    % ---------------------------------------------------------------------
    % Detect artifacts
    
    % Detect bad channels
    EEG = eega_tArtifacts(EEG, Ppp.Art.BadEl, 'KeepRejPre', 1);
    
    % ---------------------------------------------------------------------
    % MANUAL BAD CHANNEL SELECTION
    if ENABLE_MANUAL_BADCHANS
        % --- Spectral plot on the right ---
        pop_spectopo(EEG, 1, [0 EEG.xmax*1000], 'EEG', ...
            'freq', [2 100], 'freqrange', [2 100], 'percent', 100);
        spectFig = gcf;

        eega_plot_rejection(EEG, 1, 1, 1, 120)
        rawFig = gcf;

        arrangeFiguresSideBySide([spectFig, rawFig], isOCD);

        fprintf('\n=== MANUAL BAD CHANNEL SELECTION ===\n');
        EEG = eega_manualbadchannels(EEG,...
            'title', sprintf('Manual Bad Channel Selection - %s', sbjname),...
            'winlength', PLOT_WINLENGTH,...
            'dispchans', PLOT_DISPCHANS);
    
        % --- NEW: update EEG.artifacts.BC with manual bad channels ---
        if isfield(EEG.reject,'rejmanual') && any(EEG.reject.rejmanual)
            bad_ch_manual = find(EEG.reject.rejmanual);
            EEG.artifacts.BC(bad_ch_manual,:) = 1; % mark all time points as bad
        end
        % -----------------------------------------------------------------
        close all
    end

    % Detect motion artifacts
    EEG = eega_tArtifacts(EEG, Ppp.Art.Mot1, 'KeepRejPre', 1);
    
    % Detect jumps in the signal
    EEG = eega_tArtifacts(EEG, Ppp.Art.Jump, 'KeepRejPre', 1);
    
    % Define Bad Times (BT) and Bad Channels (BC)
    EEG = eega_tDefBTBC(EEG, Ppp.BTBC.BT.nbc, Ppp.BTBC.BC.nbt, Ppp.BTBC.BC.nbt,...
        'minBadTime', Ppp.BTBC.BT.minBadTime,'minGoodTime', Ppp.BTBC.BT.minGoodTime,...
        'maskTime', Ppp.BTBC.BT.maskTime, 'keeppre', 0);

    bad_channels = find(any(EEG.artifacts.BC, 2));  % any epoch
    disp('Bad channels:');
    disp(bad_channels);

    uiwait(msgbox('LOOK AT ALL REJECTED CHANNELS'));

    % ---------------------------------------------------------------------
    % VISUAL INSPECTION 3: After artifact detection
    if ENABLE_VISUAL_INSPECTION
        fprintf('\n=== VISUAL INSPECTION: After Artifact Detection ===\n');
        eega_plot_artifacts(EEG);
        set(gcf, 'Name', 'Artifacts Detection');
        
        % Ask user if this file should be marked as bad
        answer = questdlg('Should this file be marked as COMPLETELY BAD?', ...
            'File Quality Assessment', ...
            'Yes, mark as BAD', 'No, continue processing', 'Cancel processing', ...
            'No, continue processing');
        
        switch answer
            case 'Yes, mark as BAD'
                fprintf('File %s marked as COMPLETELY BAD by user\n', sbjname);
                SBJs_bad{sbj} = [sbjname '_bad'];
                batchLog = addToBatchLog(batchLog, filePath, true, true, 'Marked as bad file', struct(), currentBatch);
                close all; 
                continue; % Skip to next file
            case 'Cancel processing'
                fprintf('Processing cancelled by user\n');
                close all; 
                return;
            otherwise
                % Continue processing
        end
        
        eega_plot_rejection(EEG, 1, 1, 1, 120);
        set(gcf, 'Name', 'Data with Artifact Rejection');
        uiwait(msgbox('Inspect data with artifact rejection. Click OK to continue.'));
        
        close all
    end
    
    % Plot the rejection matrix   
    if do_plotrejection      
        eega_plot_artifacts(EEG)
        artFig = gcf;

        eega_plot_rejection(EEG, 1, 1, 1, 120)
        rejFig = gcf; 

        arrangeFiguresSideBySide([artFig, rejFig], isOCD);

        uiwait(msgbox('Inspect data rejection matrix. Click OK to continue.'));
        close all; 
    end

     % ---------------------------------------------------------------------
    % Correct brief jumps in the signal using target PCA

    EEG = eega_tTargetPCAxElEEG(EEG, Ppp.Int.pca.nSV, Ppp.Int.pca.vSV,...
        'maxTime', Ppp.Int.pca.maxTime,'maskTime',...
        Ppp.Int.pca.maskTime,'splicemethod', Ppp.Int.pca.splicemethod);
    
    % High-pass filter the data to remove drifts
    EEG = eega_demean(EEG);
    EEG = pop_eegfiltnew(EEG, Ppp.filt.highpass, [], [], 0, [], [], 0);

    % Define Bad Times (BT) and Bad Channels (BC)
    EEG = eega_tDefBTBC(EEG, Ppp.BTBC.BT.nbc, Ppp.BTBC.BC.nbt, Ppp.BTBC.BC.nbt,...
        'minBadTime', Ppp.BTBC.BT.minBadTime,'minGoodTime', Ppp.BTBC.BT.minGoodTime,...
        'maskTime', Ppp.BTBC.BT.maskTime, 'keeppre', 0);
    
    % ---------------------------------------------------------------------
    % Correct channels not working during some time using spherical spline

    EEG = eega_tInterpSpatialSegmentEEG(EEG, Ppp.Int.spl.p, 'pneigh',...
        Ppp.Int.spl.pneigh, 'splicemethod', Ppp.Int.spl.splicemethod,...
        'mingoodtime', Ppp.Int.spl.minGoodTime,...
        'minintertime', Ppp.Int.spl.minInterTime, 'masktime', Ppp.Int.spl.maskTime);

    % High-pass filter the data to remove drifts 
    EEG = eega_demean(EEG);
    EEG = pop_eegfiltnew(EEG, Ppp.filt.highpass, [], [], 0, [], [], 0);
    
    if all(EEG.data(:) == 0)
        batchLog = addToBatchLog(batchLog, filePath, false, true, 'Marked as bad file', struct(), currentBatch); 
        continue; 
    end
    % ---------------------------------------------------------------------
    % Perform ICA

    % Determine number of good channels
    if isfield(EEG, 'artifacts') && isfield(EEG.artifacts, 'BC')
        % Assume EEG.reject.badch is a logical vector (1=bad, 0=good)
        badChMask = EEG.artifacts.BC;
        numGoodChannels = EEG.nbchan - sum(badChMask);
    else
        % Fallback: assume all channels are good
        numGoodChannels = EEG.nbchan;
    end
    
    % Adjust npc if necessary
    npc_to_use = Ppp.ica.npc;
    
    if numGoodChannels - 1 < Ppp.ica.npc
        npc_to_use = numGoodChannels - 1;
        fprintf('Reducing npc to %d because number of good channels is %d\n', ...
            npc_to_use, numGoodChannels);
    end
    
    % Optional: skip ICA if too few channels left
    if npc_to_use < 2
        warning('Not enough good channels for ICA. Skipping ICA step.');
        do_applyICA = false;
    end

    if do_applyICA
        % Apply ICA
        EEG = eega_pcawtica(EEG, ...
            'filthighpass', Ppp.ica.filthighpass, ...
            'filtlowpass', Ppp.ica.filtlowpass, ...
            'npc', npc_to_use, ...
            'classifyIC', Ppp.ica.classifyIC, ...
            'classifyICfun', Ppp.ica.classifyICfun, ...
            'changelabelch', Ppp.ica.changelabelch, ...
            'labelch', Ppp.ica.labelch, ...
            'saveica', Ppp.ica.saveica, ...
            'icaname', Ppp.ica.icaname, ...
            'icapath', Ppp.ica.icapath);
    end

    
    % ---------------------------------------------------------------------
    % Spatially interpolate channels not working during the whole recording

    EEG = eega_tInterpSpatialEEG(EEG, Ppp.Int.spl.p, 'pneigh', Ppp.Int.spl.pneigh);

    % ---------------------------------------------------------------------
    % Detect artifacts

    EEG = eega_tArtifacts(EEG, Ppp.Art.Mot2, 'KeepRejPre', 1);
    
    EEG = eega_tDefBTBC(EEG, Ppp.BTBC.BT.nbc, Ppp.BTBC.BC.nbt, Ppp.BTBC.BC.nbt,...
        'minBadTime', Ppp.BTBC.BT.minBadTime,'minGoodTime', Ppp.BTBC.BT.minGoodTime,...
        'maskTime', Ppp.BTBC.BT.maskTime, 'keeppre', 0);
    
    % ---------------------------------------------------------------------
    % VISUAL INSPECTION 6: Final result
    if ENABLE_VISUAL_INSPECTION
        fprintf('\n=== VISUAL INSPECTION: Final Result ===\n');

        eega_plot_artifacts(EEG);
        set(gcf, 'Name', 'Final Artifacts Detection');
        artFig = gcf;
        eega_plot_rejection(EEG, 1, 1, 1, 120);
        rejFig = gcf; 
        arrangeFiguresSideBySide([artFig, rejFig], isOCD);
        
        % Final chance to mark as bad
        answer = questdlg('Final assessment: Should this file be marked as COMPLETELY BAD?', ...
            'Final File Quality Assessment', ...
            'Yes, mark as BAD', 'No, save as good', 'Cancel', ...
            'No, save as good');
        
        switch answer
            case 'Yes, mark as BAD'
                fprintf('File %s marked as COMPLETELY BAD by user (final assessment)\n', sbjname);
                SBJs_bad{sbj} = [sbjname '_bad'];
                batchLog = addToBatchLog(batchLog, filePath, true, true, 'Marked as bad file', struct(), currentBatch);
                close(gcf);
                continue; % Skip to next file
            case 'Cancel'
                fprintf('Processing cancelled by user\n');
                close(gcf);
                return;
            otherwise
                % Continue to sa 
                % ve
        end
        
        close all;
    end

    keepProcessing = true;

    while keepProcessing
        if all(EEG.data(:) == 0)
            batchLog = addToBatchLog(batchLog, filePath, false, true, 'Marked as bad file', struct(), currentBatch); 
            continue; 
        end
        % -------------------------------
        % Compute feature matrix & plot
        pop_spectopo(EEG, 1, [0 EEG.xmax*1000], 'EEG', ...
            'freq', [1 50], 'freqrange', [1 50], 'percent', 100);

        [powers, powers_norm, EEG] = extract_features(EEG, 0.5, 0.25);
        figMatrix = plot_powers_heatmap(powers, {EEG.chanlocs.labels}, 'jet');
    
        % Plot current artifact rejection
        figRej = eega_plot_rejection(EEG, 1, 1, 1, 15 );
        arrangeFiguresSideBySide([figMatrix, figRej], isOCD)

        uiwait(msgbox(['Processing subject: ' subjID char(isOCD*' (OCD)')]));
    
        % Ask user if they want to cut the marked segments
        answer = questdlg('Do you want to cut out the  marked segments before saving?', ...
            'Manual Cut Confirmation', 'Yes, cut them', 'No, keep them', 'Cancel', 'No, keep them');
    
        switch answer
            case 'Yes, cut them'
                % -------------------------------
                % Cut marked intervals
                [nEl, nSm, nEp] = size(EEG.data);
                if isfield(EEG.artifacts,'BCT')
                    bct = reshape(EEG.artifacts.BCT,[nEl nSm*nEp]);
                    all_intervals = [];
    
                    for el = 1:nEl
                        btel = bct(el,:);
                        btel_ini = find([btel(1) diff(btel,1,2)==1])';
                        btel_fin = find([diff(btel,1,2)==-1 btel(end)])';
    
                        btel_ini_sec = (btel_ini-1)/EEG.srate;
                        btel_fin_sec = (btel_fin-1)/EEG.srate;
    
                        all_intervals = [all_intervals; [btel_ini_sec(:) btel_fin_sec(:)]];
                    end
    
                    % Merge overlapping intervals
                    all_intervals = sortrows(all_intervals);
                    merged_intervals = [];
                    if ~isempty(all_intervals)
                        current = all_intervals(1,:);
                        for i = 2:size(all_intervals,1)
                            if all_intervals(i,1) <= current(2)
                                current(2) = max(current(2), all_intervals(i,2));
                            else
                                merged_intervals = [merged_intervals; current];
                                current = all_intervals(i,:);
                            end
                        end
                        merged_intervals = [merged_intervals; current];
                    end
    
                    % Cut EEG
                    EEG = pop_select(EEG, 'notime', merged_intervals);
    
                    % Update artifacts
                    [nEl_new, nSm_new, nEp_new] = size(EEG.data);
                    EEG.artifacts.BCT = false(nEl_new, nSm_new, nEp_new);
                    if isfield(EEG.artifacts,'BT')
                        EEG.artifacts.BT = false(1, nSm_new*nEp_new);
                    end
                end
    
                % -------------------------------
                % Re-run automatic artifact detection after manual cut
                EEG = eega_tArtifacts(EEG, Ppp.Art.Mot1, 'KeepRejPre', 1);
                EEG = eega_tArtifacts(EEG, Ppp.Art.Jump, 'KeepRejPre', 1);
                EEG = eega_tDefBTBC(EEG, Ppp.BTBC.BT.nbc, Ppp.BTBC.BC.nbt, Ppp.BTBC.BC.nbt,...
                    'minBadTime', Ppp.BTBC.BT.minBadTime,'minGoodTime', Ppp.BTBC.BT.minGoodTime,...
                    'maskTime', Ppp.BTBC.BT.maskTime, 'keeppre', 0);
    
                close all
                continue % go back to while-loop to review artifacts again
    
            case 'No, keep them'
                keepProcessing = false; % exit loop and continue saving
    
            case 'Cancel'
                fprintf('Processing cancelled by user\n');
                return
        end
    end
    
    % -------------------------------
    % Final check: mark as completely bad
    figRej = eega_plot_rejection(EEG, 1, 1, 1, 120);
    arrangeFiguresSideBySide([figMatrix, figRej], isOCD)
    
    answer = questdlg('Final assessment: Should this file be marked as COMPLETELY BAD?', ...
        'Final File Quality Assessment', ...
        'Yes, mark as BAD', 'No, save as good', 'Cancel', 'No, save as good');
    
    switch answer
        case 'Yes, mark as BAD'
            fprintf('File %s marked as COMPLETELY BAD by user (final assessment)\n', sbjname);
            SBJs_bad{sbj} = [sbjname '_bad'];
            batchLog = addToBatchLog(batchLog, filePath, true, true, 'Marked as bad file', struct(), currentBatch);
            close all
            continue
        case 'Cancel'
            fprintf('Processing cancelled by user\n');
            close(gcf);
            return;
        otherwise
            % Save EEG as cleaned
    end


    % ---------------------------------------------------------------------
    % Collect detailed metrics for logging
    metrics = struct();
    
    % File length in seconds
    metrics.file_length_secs = EEG.xmax;
    
    % Number of channels user selected
    metrics.num_channels_selected = EEG.nbchan;
    
    % Number of segments post segment rejection
    % This would need to be calculated based on your segmentation approach
    metrics.num_segments_post_rejection = NaN; % Placeholder
    
    % Number and percentage of good channels selected
    if isfield(EEG, 'reject') && isfield(EEG.reject, 'rejmanual')
        bad_chans = find(EEG.reject.rejmanual);
        metrics.num_good_channels = EEG.nbchan - length(bad_chans);
        metrics.percent_good_channels = (metrics.num_good_channels / EEG.nbchan) * 100;
    else
        metrics.num_good_channels = EEG.nbchan;
        metrics.percent_good_channels = 100;
    end
    
    % Interpolated channel IDs
    if isfield(EEG, 'etc') && isfield(EEG.etc, 'interpolatedchannels')
        metrics.interpolated_channel_ids = {EEG.chanlocs(EEG.etc.interpolatedchannels).labels};
    else
        metrics.interpolated_channel_ids = {};
    end
    
    % ICA metrics
    if do_applyICA && isfield(EEG, 'etc') && isfield(EEG.etc, 'ic_classification') && isfield(EEG.etc.ic_classification, 'MARA')
        mara_info = EEG.etc.ic_classification.MARA;
        metrics.num_ics_rejected = length(mara_info.rejected_components);
        metrics.percent_ics_rejected = (metrics.num_ics_rejected / size(EEG.icaweights, 1)) * 100;
        
        % Calculate artifact probability metrics for kept ICs
        kept_ics = setdiff(1:size(EEG.icaweights, 1), mara_info.rejected_components);
        artifact_probs = mara_info.artifact_probabilities(kept_ics);
        
        metrics.median_artifact_prob = median(artifact_probs);
        metrics.mean_artifact_prob = mean(artifact_probs);
        metrics.range_artifact_prob = range(artifact_probs);
        metrics.min_artifact_prob = min(artifact_probs);
        metrics.max_artifact_prob = max(artifact_probs);
        
        % Percent variance kept (this would need to be calculated during ICA)
        metrics.percent_variance_kept = NaN; % Placeholder
    else
        metrics.num_ics_rejected = NaN;
        metrics.percent_ics_rejected = NaN;
        metrics.median_artifact_prob = NaN;
        metrics.mean_artifact_prob = NaN;
        metrics.range_artifact_prob = NaN;
        metrics.min_artifact_prob = NaN;
        metrics.max_artifact_prob = NaN;
        metrics.percent_variance_kept = NaN;
    end
    
    % ---------------------------------------------------------------------
    % Update log with detailed metrics
    batchLog = addToBatchLog(batchLog, filePath, true, false, 'Successfully processed and saved', metrics, currentBatch);

    % ---------------------------------------------------------------------
    % Save the continuos pre-process data
    newsbjname = ['prp_' sbjname '_task-RestingState_eeg.set'];
    SBJs_prp{sbj} = fullfile(Path2SAVE,newsbjname);
    pop_saveset(EEG, newsbjname, Path2SAVE);
    
    fprintf('Completed processing file: %s\n', sbjname);

    % Live plot update (optional)
    plotBatchProgress(batchLog, SBJs_batch, true);
    mergeBatchLogToMaster(batchLog, [Path2SAVE filesep 'processing_log.mat']);

    close all hidden % close all of the finished patient
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% UNIFIED REPORTING
%
% Generate a comprehensive report from the processing log with detailed metrics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mergeBatchLogToMaster(batchLog, [Path2SAVE filesep 'processing_log.mat']);

% Final static plot
% plotBatchProgress(processingLog, SBJs_batch, false);

% Reload log to be safe
load(logFilePath, 'processingLog');

% Identify which files were processed in THIS batch
% (assuming you stored current batch filenames in `batchFileList`)
[~, ia, ib] = intersect(processingLog.files, SBJs_batch);
batchIdx = sort(ia);

% Summary counts
numProcessed = sum([processingLog.processed(batchIdx)]);
numBad       = sum([processingLog.isBad(batchIdx)]);
numSkipped   = numel(batchIdx) - numProcessed - numBad;

fprintf('\n===== BATCH REPORT =====\n');
fprintf('Files in batch:      %d\n', numel(batchIdx));
fprintf('Processed:           %d\n', numProcessed);
fprintf('Marked bad:          %d\n', numBad);
fprintf('Skipped (pre-done):  %d\n', numSkipped);
fprintf('=========================\n\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GLOBAL REPORT (all batches so far)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

numAllProcessed = sum([processingLog.processed]);
numAllBad       = sum([processingLog.isBad]);
numAllFiles     = numel(processingLog.files);

fprintf('\n===== GLOBAL REPORT =====\n');
fprintf('Total files seen:    %d\n', numAllFiles);
fprintf('Processed:           %d\n', numAllProcessed);
fprintf('Marked bad:          %d\n', numAllBad);
fprintf('Remaining:           %d\n', numAllFiles - numAllProcessed - numAllBad);
 fprintf('==========================\n\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOGGING FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [shouldProcess, isMarkedBad, logIndex, batchLog] = checkFileStatus(batchLog, filePath, saveFolder, currentBatch)
    % Check if a file should be processed based on batchLog and existing files
    % Also updates batchLog if file exists but wasn't logged
    
    % Default outputs
    shouldProcess = true;
    isMarkedBad = false;
    logIndex = [];

    % Check if file is already in log
    logIndex = find(strcmp(batchLog.files, filePath));
    
    if ~isempty(logIndex)
        % Take the last entry if duplicates exist
        logIndex = logIndex(end);
        isMarkedBad = batchLog.isBad(logIndex);
        isProcessed = batchLog.processed(logIndex);
        
        if isMarkedBad
            shouldProcess = false;
            return;
        elseif isProcessed
            % Check if processed file actually exists
            [~, sbjname, ~] = fileparts(filePath);
            processedFile = fullfile(saveFolder, ['prp_' sbjname '.set']);
            if exist(processedFile, 'file')
                shouldProcess = false;
                return;
            else
                % Logged as processed but missing - reprocess
                shouldProcess = true;
                return;
            end
        end
    end
    
    % File not in log or not processed - check if processed file exists
    [~, sbjname, ~] = fileparts(filePath);
    processedFile = fullfile(saveFolder, ['prp_' sbjname '.set']);
    
    if exist(processedFile, 'file')
        % File exists but not in log → add entry to batchLog
        idx = length(batchLog.files) + 1;
        batchLog.files{idx} = filePath;
        batchLog.processed(idx) = true;
        batchLog.isBad(idx) = false;
        batchLog.timestamp{idx} = datestr(now);
        batchLog.notes{idx} = 'Auto-detected as processed';
        batchLog.batch{idx} = currentBatch;
        
        shouldProcess = false;
        isMarkedBad = false;
        logIndex = idx;
    else
        % File should be processed
        shouldProcess = true;
        isMarkedBad = false;
    end
end



function updateProcessingLog(logFilePath, filename, isProcessed, isBad, notes, batch)
    % Update the processing log
    
    persistent logData
    persistent logPath
    
    % Initialize persistent variables
    if isempty(logData) || (nargin > 0 && ~isempty(logFilePath))
        if nargin > 0 && ~isempty(logFilePath)
            logPath = logFilePath;
            if exist(logPath, 'file')
                load(logPath, 'processingLog');
                logData = processingLog;
            else
                logData = struct();
                logData.files = {};
                logData.processed = [];
                logData.isBad = [];
                logData.timestamp = {};
                logData.notes = {};
                logData.batch = [];
            end
        end
        return;
    end
    
    % Find if file already exists in log
    idx = find(strcmp(logData.files, filename));
    
    if isempty(idx)
        % Add new entry
        idx = length(logData.files) + 1;
        logData.files{idx} = filename;
    end
    
    % Update entry
    logData.processed(idx) = isProcessed;
    logData.isBad(idx) = isBad;
    logData.timestamp{idx} = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    logData.notes{idx} = notes;
    logData.batch(idx) = batch; 
    
    % Save log
    processingLog = logData;
    save(logPath, 'processingLog');
    
    fprintf('Log updated: %s - Processed: %d, Bad: %d, Note: %s\n', ...
        filename, isProcessed, isBad, notes);
end

function EEG = eega_manualbadchannels(EEG, varargin)
% EEG = eega_manualbadchannels(EEG, varargin)
% Manually select bad channels using EEGLab's pop_chansel
% Automatically updates artifacts.BC for interpolation/rejection
%
% Input:
%   EEG - EEG structure
%   Optional parameters:
%       'title' - dialog title
%       'winlength' - window length for eegplot
%       'dispchans' - number of channels to display
%
% Output:
%   EEG - EEG structure with manually selected bad channels marked

% Parse optional parameters
p = inputParser;
addParameter(p, 'title', 'Select Bad Channels', @ischar);
addParameter(p, 'winlength', 5, @isnumeric);
addParameter(p, 'dispchans', 20, @isnumeric);
parse(p, varargin{:});

fprintf('=== MANUAL BAD CHANNEL SELECTION ===\n');

% Get current bad channels
current_bad = [];
if isfield(EEG.reject, 'rejmanual') && any(EEG.reject.rejmanual)
    current_bad = find(EEG.reject.rejmanual);
end

if ~isempty(current_bad)
    fprintf('Current bad channels: %s\n', strjoin({EEG.chanlocs(current_bad).labels}, ', '));
end

% Show data for visual inspection
fprintf('Showing data for visual inspection...\n');

uiwait(msgbox('Inspect the data. Click OK to proceed to channel selection.'));

% Use pop_chansel to select bad channels
[chanlist, ~, ~] = pop_chansel({EEG.chanlocs.labels}, ...
    'selectionmode', 'multiple', ...
    'select', current_bad, ...
    'withindex', 'on', ...
    'field', 'labels');

% Update rejection information
if ~isempty(chanlist)
    % Update manual rejection field
    EEG.reject.rejmanual = zeros(1, EEG.nbchan);
    EEG.reject.rejmanual(chanlist) = 1;

    % Update etc.badchannels field
    if ~isfield(EEG, 'etc') || ~isfield(EEG.etc, 'badchannels')
        EEG.etc.badchannels = struct();
    end
    EEG.etc.badchannels.manual = chanlist;

    % Update artifacts.BC for all epochs (so they will be interpolated)
    if ~isfield(EEG.artifacts,'BC') || isempty(EEG.artifacts.BC)
        EEG.artifacts.BC = false(EEG.nbchan, 1, EEG.trials);
    end
    EEG.artifacts.BC(chanlist,1,:) = true;  

    % Also store manual selection separately
    EEG.artifacts.BCmanual = chanlist;

    fprintf('Selected bad channels: %s\n', strjoin({EEG.chanlocs(chanlist).labels}, ', '));
    fprintf('Total bad channels: %d/%d\n', length(chanlist), EEG.nbchan);
else
    fprintf('No channels selected as bad.\n');
end

fprintf('=== MANUAL SELECTION COMPLETE ===\n\n');

end


function updateProcessingLogWithMetrics(logFilePath, filename, isProcessed, isBad, notes, metrics, currentBatch)
    if exist(logFilePath, 'file')
        load(logFilePath, 'processingLog');
    else
        error('Log file does not exist at %s', logFilePath);
    end
    
    idx = find(strcmp(processingLog.files, filename), 1);
    if isempty(idx)
        % New entry
        idx = length(processingLog.files) + 1;
        processingLog.files{idx} = filename;
    end
    
    % Update basic fields
    processingLog.processed(idx) = isProcessed;
    processingLog.isBad(idx) = isBad;
    processingLog.timestamp{idx} = datestr(now);
    processingLog.notes{idx} = notes;
    processingLog.batch{idx} = currentBatch; 
    
    % Update metrics (fill missing fields if needed)
    fns = fieldnames(metrics);
    for f = 1:numel(fns)
        fname = fns{f};
        if ~isfield(processingLog, fname)
            processingLog.(fname) = cell(1, length(processingLog.files));
        end
        processingLog.(fname){idx} = metrics.(fname);
    end
    
    % Save immediately so log persists batch-to-batch
    save(logFilePath, 'processingLog');
end

function plotBatchProgress(processingLog, batchFileList, liveUpdate)
    % Find batch indices
    [~, ia] = intersect(processingLog.files, batchFileList, 'stable');
    batchIdx = sort(ia);

    % Collect status
    status = zeros(1, numel(batchIdx));
    for i = 1:numel(batchIdx)
        if processingLog.isBad(batchIdx(i))
            status(i) = -1;   % bad
        elseif processingLog.processed(batchIdx(i))
            status(i) = 1;    % processed
        else
            status(i) = 0;    % skipped
        end
    end

    % Extract subject names (file basename = subject ID)
    [~, subjectNames, ~] = cellfun(@fileparts, processingLog.files(batchIdx), 'UniformOutput', false);

    % Create/Update figure
    if liveUpdate
        figure(100); clf; % fixed figure handle for live updates
    else
        figure('Name','Batch Progress','Color','w');
    end

    b = bar(status, 'FaceColor','flat');
    xticks(1:numel(subjectNames));
    xticklabels(subjectNames);
    xtickangle(45);
    ylabel('Status');
    title('Batch Processing Progress');
    ylim([-1.5 1.5]);

    % Color bars
    for i = 1:numel(status)
        if status(i) == 1
            b.CData(i,:) = [0 0.6 0];     % green = processed
        elseif status(i) == -1
            b.CData(i,:) = [0.8 0 0];     % red = bad
        else
            b.CData(i,:) = [0.5 0.5 0.5]; % gray = skipped
        end
    end

    if ~liveUpdate
        legend({'Processed','Bad','Skipped'}, 'Location','bestoutside');
    end

    drawnow; % force redraw immediately
end

function arrangeFiguresSideBySide(figHandles, isOCD)
   % Arrange up to 2 figures side by side at the top of the screen
% figHandles - array of figure handles
% isOCD      - logical, true if patient is OCD (adds label)

    if nargin < 2
        isOCD = false;
    end

    screenSize = get(0,'ScreenSize'); % [left bottom width height]
    nFigs = length(figHandles);
    nFigs = min(nFigs,2); % max 2 figures

    spacing = 10;         % pixels between figures
    titleOffset = 50;     % space for window title bar
    maxWidth = (screenSize(3) - (nFigs+1)*spacing) / nFigs; % per figure width
    maxHeight = screenSize(4)*0.5 - titleOffset;            % top half height

    for i = 1:nFigs
        % Preserve aspect ratio
        figUnits = get(figHandles(i), 'Units');
        set(figHandles(i), 'Units', 'pixels');
        pos = get(figHandles(i), 'Position'); % [x y width height]
        set(figHandles(i), 'Units', figUnits);

        aspectRatio = pos(3)/pos(4);

        winHeight = min(maxHeight, maxWidth / aspectRatio);
        winWidth  = winHeight * aspectRatio;

        % Compute position
        xPos = spacing + (i-1)*(winWidth + spacing);
        yPos = screenSize(4) - winHeight - titleOffset; % flush top

        % Apply position
        set(figHandles(i), 'Units', 'pixels', 'Position', [xPos, yPos, winWidth, winHeight]);

        % Update figure title with OCD label if needed
        figName = get(figHandles(i), 'Name');
        if isOCD
            set(figHandles(i), 'Name', [figName ' - OCD Patient']);
        end
    end
end


%% Function to update batch log in memory
function batchLog = addToBatchLog(batchLog, filename, isProcessed, isBad, notes, metrics, currentBatch)
    idx = find(strcmp(batchLog.files, filename), 1);
    if isempty(idx)
        idx = length(batchLog.files) + 1;
        batchLog.files{idx} = filename;
    end
    
    batchLog.processed(idx) = isProcessed;
    batchLog.isBad(idx) = isBad;
    batchLog.timestamp{idx} = datestr(now);
    batchLog.notes{idx} = notes;
    batchLog.batch{idx} = currentBatch;
    
    % Add metrics
    fns = fieldnames(metrics);
    for f = 1:numel(fns)
        fname = fns{f};
        if ~isfield(batchLog, fname)
            batchLog.(fname) = cell(1, length(batchLog.files));
        end
        batchLog.(fname){idx} = metrics.(fname);
    end
end

function mergeBatchLogToMaster(batchLog, logFilePath)
    % Load or initialize processingLog
    if exist(logFilePath, 'file')
        load(logFilePath, 'processingLog');
    else
        processingLog = struct();
    end

    % Merge batchLog into processingLog
    for i = 1:length(batchLog.files)
        filename = batchLog.files{i};
        
        % Find or create index
        if isfield(processingLog, 'files')
            idx = find(strcmp(processingLog.files, filename), 1);
        else
            processingLog.files = {};
            idx = [];
        end

        if isempty(idx)
            idx = length(processingLog.files) + 1;
            processingLog.files{idx} = filename;
        end

        % Direct assignments
        processingLog.processed(idx) = batchLog.processed(i);
        processingLog.isBad(idx) = batchLog.isBad(i);
        
        fieldsToEnsure = {'timestamp', 'notes', 'batch'};
        n = length(processingLog.files);
        for f = 1:numel(fieldsToEnsure)
            field = fieldsToEnsure{f};
        
            % Initialize or fix type
            if ~isfield(processingLog, field)
                processingLog.(field) = cell(1, n);
            elseif ~iscell(processingLog.(field))
                processingLog.(field) = num2cell(processingLog.(field));
            elseif length(processingLog.(field)) < n
                processingLog.(field){n} = [];
            end
        
            % Assign the value
            processingLog.(field){idx} = batchLog.(field){i};
        end
        
                % Merge additional metrics
        metricFields = setdiff(fieldnames(batchLog), {'files','processed','isBad','timestamp','notes','batch'});
        for f = 1:numel(metricFields)
            fname = metricFields{f};

            % Get the current value from batchLog
            blField = batchLog.(fname);

            % Determine required length
            requiredLength = max(idx, length(processingLog.files));

            % Initialize field if it doesn't exist
            if ~isfield(processingLog, fname)
                if iscell(blField)
                    processingLog.(fname) = cell(1, requiredLength);
                else
                    processingLog.(fname) = nan(1, requiredLength);  % default for numeric fields
                end
            end

            % Grow field if needed
            currentLength = length(processingLog.(fname));
            if currentLength < requiredLength
                if iscell(processingLog.(fname))
                    processingLog.(fname){requiredLength} = [];
                else
                    processingLog.(fname)(requiredLength) = nan;
                end

            end
        end
        
    end

    % Save updated log
    save(logFilePath, 'processingLog');
end

