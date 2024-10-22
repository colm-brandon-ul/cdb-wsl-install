#!/bin/bash

echo "Starting CincoDeBio uninstall process..."

# Check if multipass is installed
if ! which multipass >/dev/null; then
    echo "Multipass is not installed. Nothing to uninstall."
    exit 0
fi

# Check if the microk8s VM exists
if multipass list | grep -q "microk8s-vm"; then
    echo "Found MicroK8s VM. Stopping and deleting..."
    
    # Stop the VM if it's running
    if multipass list | grep "microk8s-vm" | grep -q "Running"; then
        echo "Stopping MicroK8s VM..."
        multipass stop microk8s-vm
    fi
    
    # Delete the VM and purge all associated data
    echo "Deleting MicroK8s VM..."
    multipass delete microk8s-vm
    multipass purge
else
    echo "No MicroK8s VM found."
fi

# Check if microk8s is installed via brew
if brew list | grep -q "microk8s"; then
    echo "Uninstalling MicroK8s via Homebrew..."
    brew uninstall ubuntu/microk8s/microk8s
fi

# Optional: Uninstall multipass if user wants to
read -p "Do you want to uninstall Multipass as well? (y/n): " remove_multipass
if [ "$remove_multipass" = "y" ] || [ "$remove_multipass" = "Y" ]; then
    echo "Uninstalling Multipass..."
    brew uninstall --cask multipass
fi

echo "CincoDeBio uninstallation completed successfully."