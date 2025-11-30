# preprocess_infant_eeg

Main codebase to manually check and preprocess infant EEG.
Built from a modified version of the APICE and HAPPE pipelines, adapted for the HBN dataset and a 129-channel HydroCel montage.

## 🚀 Getting Started
### 1. Clone the repository
``` bash
git clone <your-repo-url>
cd preprocess_infant_eeg
```

### 2. Install Dependencies

This project relies on several external Git repositories (e.g., HAPPE, iMARA).
To make setup easy, all dependencies are installed automatically.

#### Install
Run the following command in the root folder of the repository:

`python setup_dependencies.py`

This script will:
- create an external_libs/ directory (if it doesn’t already exist)
- clone all required external Git repositories into that folder
- prepare all dependencies for use by the MATLAB code

After installation, the MATLAB script (main.m) will automatically detect and add these dependencies to the MATLAB path using relative paths—no manual path editing required.

### 3. Setting parameters
Open MATLAB and edit your own parameters in 'main.m'. You can decide to do a manual inspection of every single EEG by batches for safety and comodity of the user. 

This will launch the preprocessing workflow for infant EEG data, leveraging the installed dependencies.
