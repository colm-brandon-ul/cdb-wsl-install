#!/bin/bash

# Take the user input for the dockerhub username (in a while loop with regex validation)
while true; do
  read -p "Enter your DockerHub username: " dockerhub_username
  if echo "$dockerhub_username" | grep -Eq '^[a-zA-Z0-9](?:[a-zA-Z0-9-]{3,})$'; then
    break
  else
    echo "Invalid Username. Please try again."
  fi
done

# Take the user input for the dockerhub password (in a while loop with regex validation)
while true; do
  read -p "Enter your DockerHub password: " dockerhub_password
  if echo "$dockerhub_password" | grep -Eq '^.{8,}$'; then
    break
  else
    echo "Invalid password. Please try again."
  fi
done

# Check number of CPU cores
total_cpu_cores=$(nproc)
echo "Number of CPU cores: $total_cpu_cores"

# Check memory (in GB)
total_memory=$(free -g | awk '/^Mem:/{print $2}')
total_memory_gb=$total_memory

# Check disk space
total_disk_space=$(df -h / | tail -1 | awk '{print $4}')

# Get inputs from user for resource allocation
echo "Enter the number of CPU cores to allocate to the CincoDeBio Cluster (Total Available = $total_cpu_cores): "
while true; do
    read cpu_cores
    if [ $cpu_cores -ge 2 ] && [ $cpu_cores -le $total_cpu_cores ]; then
        break
    else
        echo "Invalid input. Please enter a value between 2 and $total_cpu_cores: "
    fi
done

echo "Enter the amount of memory to allocate to the CincoDeBio Cluster (Total Available = $total_memory_gb GB): "
while true; do
    read memory_gb
    if (( $(echo "$memory_gb >= 4" | bc -l) )) && (( $(echo "$memory_gb <= $total_memory_gb" | bc -l) )); then
        break
    else
        echo "Invalid input. Please enter a value between 4 and $total_memory_gb: "
    fi
done

echo "Enter the amount of disk space to allocate to the CincoDeBio Cluster (Total Available = $total_disk_space): "
while true; do
    read disk_space
    # Remove 'G' from the input and total disk space
    disk_space_int=${disk_space%G}
    total_disk_space_int=${total_disk_space%G}
    if [ $disk_space_int -ge 20 ] && [ $disk_space_int -le $total_disk_space_int ]; then
        break
    else
        echo "Invalid input. Please enter a value between 20 and $total_disk_space: "
    fi
done

echo "Disk space to allocate: $disk_space_int"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Install required packages
echo "Installing required packages..."
apt update
apt install -y snapd multipass

# Enable and start snap service
systemctl enable snapd
systemctl start snapd

# Install MicroK8s
if which microk8s >/dev/null; then
    echo "MicroK8s is already installed."
else
    echo "Installing MicroK8s..."
    snap install microk8s --classic
fi

# Configure MicroK8s
echo "Configuring MicroK8s..."
microk8s stop
multipass launch --name microk8s-vm --cpus $cpu_cores --mem ${memory_gb}G --disk ${disk_space_int}G 22.04
multipass exec microk8s-vm -- sudo snap install microk8s --classic
multipass exec microk8s-vm -- sudo microk8s status --wait-ready

# Get the IP address of the VM
VM_IP=$(multipass info microk8s-vm | grep IPv4 | awk '{print $2}')

# Enable required addons
microk8s enable dns
microk8s enable ingress
microk8s enable metrics-server
microk8s enable registry
microk8s enable hostpath-storage
microk8s enable storage

# Add dockerhub credentials to microk8s cluster
multipass exec microk8s-vm -- bash -c "echo '[plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"registry-1.docker.io\".auth]
username = \"$dockerhub_username\"
password = \"$dockerhub_password\"' | sudo tee -a /var/snap/microk8s/current/args/containerd-template.toml > /dev/null"

# Restart cluster
microk8s stop
microk8s start

microk8s status --wait-ready

# Adding the CincoDeBio Helm Chart Repo
microk8s helm repo add scce https://colm-brandon-ul.github.io/cincodebio-helm-chart
microk8s helm repo update

# Installing CincoDeBio Core Services
echo "Installing CincoDeBio Core Services, this may take a few minutes"

# Set the Dockerhub username and password via --set flag
microk8s helm install --wait my-cinco-de-bio scce/cinco-de-bio \
    --set global.containers.docker_hub_username=$dockerhub_username \
    --set global.containers.docker_hub_password=$dockerhub_password

echo "CincoDeBio Cluster is ready for use. IP Address: $VM_IP (Copy this into the CincoDeBio Preferences)"
echo "URL to Upload Portal (Copy this URL into your browser): http://$VM_IP/data-manager/"
echo "The Application may take a few minutes to start up. \n Happy Modelling!"