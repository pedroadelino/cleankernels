#!/bin/bash
set -e

########################
# Config
########################

DRY_RUN=true   # set to false to actually purge kernels

########################
# Colours
########################

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

########################
# Start
########################

echo -e "${CYAN}=== Extracting kernel identifiers from grub.cfg ===${RESET}"

# Extract full kernel identifiers (version + flavour + signing)
GRUB_KERNELS=$(grep -oE 'vmlinuz-[^ ]+' /boot/grub/grub.cfg \
    | sed 's/vmlinuz-//' \
    | sed 's/\.efi.signed//' \
    | sort -u)

echo -e "${BOLD}Kernels referenced in grub.cfg:${RESET}"
echo "$GRUB_KERNELS"
echo

readarray -t KEEP_FROM_GRUB <<< "$GRUB_KERNELS"

if [ ${#KEEP_FROM_GRUB[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No kernels found in grub.cfg. Aborting for safety.${RESET}"
    exit 1
fi

echo -e "${CYAN}=== Listing installed kernel packages ===${RESET}"
INSTALLED_KERNELS=$(dpkg --list | awk '/linux-image-[0-9]/{print $2}' | sort -u)
echo "$INSTALLED_KERNELS"
echo

readarray -t INSTALLED <<< "$INSTALLED_KERNELS"

echo -e "${CYAN}=== Determining removable kernels ===${RESET}"

# Sort installed kernels by version (oldest first, newest last)
SORTED_INSTALLED=($(printf '%s\n' "${INSTALLED[@]}" | sort -V))

########################
# Pick 2 extra newest kernels NOT already in grub.cfg
########################

EXTRA_KEEP=()
for (( idx=${#SORTED_INSTALLED[@]}-1 ; idx>=0 ; idx-- )); do
    K=${SORTED_INSTALLED[$idx]}

    # Skip meta-packages
    if [[ "$K" =~ linux-image-(generic|lowlatency|aws)$ ]]; then
        continue
    fi

    FULL_ID=${K#linux-image-}
    FULL_ID=${FULL_ID%.efi.signed}

    # Skip if already in grub.cfg
    if printf '%s\n' "${KEEP_FROM_GRUB[@]}" | grep -qx "$FULL_ID"; then
        continue
    fi

    EXTRA_KEEP+=("$FULL_ID")

    # Stop once we have 2 extra
    if [ ${#EXTRA_KEEP[@]} -ge 2 ]; then
        break
    fi
done

echo -e "${BOLD}Extra kernels to keep (newest not in grub.cfg, up to 2):${RESET}"
printf '%s\n' "${EXTRA_KEEP[@]}"
echo

########################
# Protect running kernel
########################

RUNNING_KERNEL=$(uname -r | sed 's/\.efi.signed//')
echo -e "${BOLD}Running kernel:${RESET} $RUNNING_KERNEL"
echo

########################
# Build final keep list
########################

ALL_KEEP=("${KEEP_FROM_GRUB[@]}" "${EXTRA_KEEP[@]}" "$RUNNING_KERNEL")
ALL_KEEP=($(printf '%s\n' "${ALL_KEEP[@]}" | sort -u))

echo -e "${BOLD}Final keep list (full identifiers):${RESET}"
printf '%s\n' "${ALL_KEEP[@]}"
echo

########################
# Decide what to remove
########################

REMOVABLE=()

for K in "${INSTALLED[@]}"; do

    # Skip meta-packages
    if [[ "$K" =~ linux-image-(generic|lowlatency|aws)$ ]]; then
        echo -e "${YELLOW}Skipping meta-package:${RESET} $K"
        continue
    fi

    FULL_ID=${K#linux-image-}
    FULL_ID=${FULL_ID%.efi.signed}

    if printf '%s\n' "${ALL_KEEP[@]}" | grep -qx "$FULL_ID"; then
        echo -e "${GREEN}Keeping kernel:${RESET} $FULL_ID"
        continue
    fi

    echo -e "${RED}Marking kernel for removal:${RESET} $FULL_ID"

    RELATED=$(dpkg --list | awk -v id="$FULL_ID" '
        /linux-(image|modules|headers)/ && $2 ~ id {print $2}
    ')

    for PKG in $RELATED; do
        echo -e "  ${RED}→ Related package to remove:${RESET} $PKG"
        REMOVABLE+=("$PKG")
    done
done

if [ ${#REMOVABLE[@]} -gt 0 ]; then
    mapfile -t REMOVABLE < <(printf '%s\n' "${REMOVABLE[@]}" | sort -u)
fi

echo
echo -e "${CYAN}=== Calculating total size of removable packages ===${RESET}"

TOTAL_SIZE=0
for PKG in "${REMOVABLE[@]}"; do
    SIZE=$(dpkg-query -W -f='${Installed-Size}' "$PKG" 2>/dev/null || echo 0)
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
done

TOTAL_MB=$((TOTAL_SIZE / 1024))
echo -e "${BOLD}Total removable size:${RESET} ${TOTAL_MB} MB"
echo

if [ ${#REMOVABLE[@]} -eq 0 ]; then
    echo -e "${GREEN}No kernel-related packages to remove. Exiting safely.${RESET}"
    exit 0
fi

echo -e "${CYAN}=== Packages to be removed (if not dry-run) ===${RESET}"
printf '%s\n' "${REMOVABLE[@]}"
echo

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN]${RESET} No packages will actually be removed."
    exit 0
fi

read -p "Proceed with removal? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "${CYAN}=== Removing old kernel-related packages ===${RESET}"
#sudo apt-get purge -y "${REMOVABLE[@]}"

echo -e "${CYAN}=== Updating grub ===${RESET}"
#sudo update-grub

