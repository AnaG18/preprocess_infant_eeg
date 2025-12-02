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

### 3. Setting parameters
Open MATLAB and edit your own parameters in 'main.m'. You can decide to do a manual inspection of every single EEG by batches for safety and comodity of the user. 

This will launch the preprocessing workflow for infant EEG data, leveraging the installed dependencies.

## Access to data
Download the data in [this link](https://livejohnshopkins-my.sharepoint.com/:f:/g/personal/agarc124_jh_edu/IgCoASa15es6SbEjMcfJ65BdAfYfzbvJD-alia2NIP0dj18?e=zjnEtE) and make sure that the folder is under the same folder of this project. The final directory tree should look like this:  

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
