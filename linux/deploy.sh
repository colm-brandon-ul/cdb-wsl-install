#!/bin/sh

# Take the user input for the dockerhub username (in a while loop with regex validation)
while true; do
  read -p "Enter the username: " username
  if [[ $username =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{3,})$ ]]; then
    break
  else
    echo "Invalid username. Please try again."
  fi
done

# Take the user input for the dockerhub password (in a while loop with regex validation)
while true; do
  read -p "Enter the password: " password
  if [[ $password =~ ^.{8,}$ ]]; then
    break
  else
    echo "Invalid password. Please try again."
  fi
done

# Find the largest drive and store it as a variable (linux)
largest_drive=$(lsblk -bno SIZE,NAME | sort -nr | awk 'NR==1 {print $2}')

sudo snap install microk8s --classic --channel=1.30
sudo usermod -a -G microk8s $USER
mkdir -p ~/.kube
chmod 0700 ~/.kube
su - $USER
microk8s status --wait-ready

# add dockerhub credentials to containerd microk8s config


microk8s stop 
microk8s start


# Enable microk8s addons use for cinco-de-bio
sudo microk8s enable dns
sudo microk8s enable ingress
sudo microk8s enable metrics-server
sudo microk8s enable registry
sudo microk8s enable hostpath-storage
sudo microk8s enable storage
