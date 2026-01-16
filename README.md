🧹 Clean Kernels

    A safe, intelligent Bash tool for identifying and removing old Linux kernel packages on Debian/Ubuntu systems.

    This script analyses:

        Kernels referenced in grub.cfg

        Installed kernel packages

        The running kernel

        The newest kernels not yet in GRUB

        All related packages (image, modules, headers)

    …and builds a safe removal list that never touches anything required for booting.

✨ Features

    Dry‑run mode (default) — shows what would be removed

    Protects the running kernel

    Protects all kernels referenced in GRUB

    Keeps two extra newest kernels for safety

    Detects all related packages (image, modules, headers)

    Calculates total removable size

    Colour‑coded output for clarity

    Fails safely if GRUB contains no kernel entries

📦 Requirements

    Bash

    Debian/Ubuntu‑based system

    dpkg, grep, awk, sed

    Root privileges only if you disable dry‑run

🚀 Usage

    1. Clone the repository

       git clone https://github.com/pedroadelino/cleankernels.git

    2. 
       cd cleankernels

    3. Make the script executable

       chmod +x clean_kernels.sh

    4. Run in dry‑run mode (default)

       ./clean_kernels.sh

   This shows:

    Kernels in GRUB

    Installed kernels

    Final keep list

    Packages that would be removed

    Total size that would be freed

5. Run for real (dangerous — be sure!)

   Edit the script: DRY_RUN=false

   Then run: sudo ./clean_kernels.sh

⚠️ Safety Notes

    Never run this script on a system with a broken GRUB configuration.

    Always review the dry‑run output before enabling removal.

    The script intentionally refuses to run if GRUB contains no kernel entries.

📁 Suggested .gitignore

    Create a .gitignore file with:
    *.swp
    *.bak
    *.tmp
    *.log
    .DS_Store

📜 License

    MIT License
