#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "WARNING: This script will remove the CincoDeBio cluster."
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Stop and delete the microk8s VM if it exists
if multipass list | grep -q "microk8s-vm"; then
    echo "Stopping and removing microk8s-vm..."
    multipass stop microk8s-vm
    multipass delete microk8s-vm
    multipass purge
    echo "CincoDeBio cluster has been removed."
else
    echo "No microk8s-vm found."
fi