# Prerequisites 
DockerHub Account (The repository for storing services is currently docker hub), therefore need credentials to authenticate to avoid rate limiting.m

## Validate Systename
<!-- Windows System Name only contains lowercase letters, numbers and hyphens -->
Need to use a regex for validating current hostname (i.e. system name)
<!-- You may need to restart the machine -->

<!-- Don't forget to wrap file-paths in quotes in case there are spaces, etc. -->

<!-- WSL --install will install Ubuntu -->
## Installing WSL
wsl --install 
wsl --update
wsl --set-default-version 2

<!-- You may need to restart the machine -->

<!-- Update Ubuntu dependencies -->
wsl sudo apt update
wsl sudo apt upgrade -y

<!-- If wsl does not launch Linux installation in new window, complete the process as normal the hit CTRL-D (to return to rest of deployment) -->

<!-- Turn on Systemd (so that snap will work) -->
<!-- have to escape newline as it's being passed via powershell -->
wsl echo -e "[boot]\\nsystemd=true" | wsl sudo tee /etc/wsl.conf
<!-- This will cause the systemd Changes to take effect -->
wsl --shutdown
<!-- You may need to restart the machine -->

<!-- Assume running on root -->
## Install microk8s
<!-- Use snap to install microk8s -->
wsl sudo snap install microk8s --classic
<!-- Wait till cluster ready -->
wsl sudo microk8s status --wait-ready
<!-- Verify it is using WSL kernel -->
wsl sudo microk8s kubectl get node -o wide

## Get the IP address of the WSL instance
<!-- Get IP address of cluster -->
<!-- needs to be done before enable ingress addon -->
wsl hostname -I

<!-- If you restart the machine or WSL this IP address may change -->
<!-- run the above command to get the new one -->

<!-- Install necessary microk8s addons -->
sudo microk8s enable dns
sudo microk8s enable ingress
sudo microk8s enable metrics-server
sudo microk8s enable registry
sudo microk8s enable hostpath-storage
sudo microk8s enable storage

<!-- This must be down after microk8s is install or the systemd config doesn't work -->
## Move WSL VHD to another drive:
<!-- Make directory to export to and export VM -->
mkdir %DRIVENAME%\wsl-backup
wsl --export Ubuntu %DRIVENAME%\wsl-backup\ubuntu.tar

<!-- unregister current Ubuntu from wsl -->
wsl --unregister Ubuntu

<!-- Make directory for storing VHD -->
mkdir %DRIVENAME%\wsl

<!-- Import the VM and set VHD dir to new directory -->
wsl --import Ubuntu %DRIVENAME%\wsl %DRIVENAME%\wsl-backup\ubuntu.tar

<!-- The newly imported Ubuntu instance will use root as user  -->
<!-- While this is conveniant for install's etc.. -->
<!-- You may want to change the defulat user profile -->
cd %userprofile%\AppData\Local\Microsoft\WindowsApps (on windows machine)
ubuntu config --default-user <username> (this is the username set when setting up Ubuntu VM)

## Install CincoDeBio /w Cellmaps Ontology / Services Repo

