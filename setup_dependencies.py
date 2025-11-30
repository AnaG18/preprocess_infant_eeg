import subprocess
import os

# List of repositories to clone
repos = {
    "APICE-preprocessing-pipeline": "https://github.com/neurokidslab/eeg_preprocessing.git",
    "HAPPE-preprocessing-pipeline": "https://github.com/lcnhappe/happe.git",
    "iMARA":                        "https://github.com/Ira-marriott/iMARA.git",
}

# Folder where dependencies will be placed
dest_folder = "external_libs"

os.makedirs(dest_folder, exist_ok=True)

for name, url in repos.items():
    repo_path = os.path.join(dest_folder, name)

    if not os.path.exists(repo_path):
        print(f"Cloning {name}...")
        subprocess.check_call(["git", "clone", url, repo_path])
    else:
        print(f"{name} already exists. Skipping.")
