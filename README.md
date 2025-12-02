# preprocess_infant_eeg

Main codebase to manually check and preprocess infant EEG.
Built from a modified version of the APICE and HAPPE pipelines, adapted for the HBN dataset and a 129-channel HydroCel montage.

## 🚀 Getting Started
### 1. Clone the repository
``` bash
git clone https://github.com/AnaG18/preprocess_infant_eeg.git
cd preprocess_infant_eeg
```

### 2. Install Dependencies

This project relies on several external Git repositories (e.g., HAPPE, iMARA).
To make setup easy, all dependencies are installed automatically.

#### Install
Run the following command in the root folder of the repository:

``` bash
python setup_dependencies.py
```

This script will:
- create an external_libs/ directory (if it doesn’t already exist)
- clone all required external Git repositories into that folder
- prepare all dependencies for use by the MATLAB code

After installation, the MATLAB script (main.m) will automatically detect and add these dependencies to the MATLAB path using relative paths—no manual path editing required.

### 3. Setting parameters and EEGlab path 
Open MATLAB and make sure to edit the right path for EEGLAB into the variable Path2EEGLAB. Edit your own parameters in 'main.m'. You can decide to do a manual inspection of every single EEG by batches for safety and comodity of the user. 
```
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

...

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

...

% .........................................................................
% Parameters for W-ICA
% .........................................................................
Ppp.ica = ex2_Ppp_wICA;
do_applyICA = 1;

...
% .........................................................................
% Plotting
% .........................................................................
do_plotrejection = 1;

```
This will launch the preprocessing workflow for infant EEG data, leveraging the installed dependencies.

## 📌 Access to data
Download the data in [this link](https://livejohnshopkins-my.sharepoint.com/:f:/g/personal/agarc124_jh_edu/IgCoASa15es6SbEjMcfJ65BdAfYfzbvJD-alia2NIP0dj18?e=zjnEtE) and make sure that the folder is under the same folder of this project. **IMPORTANT! If less patients than in raw folder just make sure the sub-folders in raw match with the rows and ids of `participants.tsv`**

The final directory tree should look like this:  

```
preprocess_infant_eeg
│   README.md
│   main.m
|   setup_dependencies.py     
│
└───data
    │   README.md
    │   participants.tsv
    │
    └───raw
        │   
        └───sub-1
        │       sub-1_task-RestingState_channels.tsv
        │       sub-1_task-RestingState_coordsystem.json
        │       sub-1_task-RestingState_eeg.json
        │       sub-1_task-RestingState_eeg.set
        │       sub-1_task-RestingState_electrodes.tsv
        │       sub-1_task-RestingState_events.tsv
        │   
        └───sub-2
        ...
```
