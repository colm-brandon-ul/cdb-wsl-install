# May need to edit WSL Config file to allow max memory / cpu usage
# install / update WSL2
wsl.exe --update
# Global Variables
$distro = "Ubuntu-22.04"
$helm_repo = "https://colm-brandon-ul.github.io/cincodebio-helm-chart"
# Get system name
$systemName = $(hostname)
# apply regex to system name to make sure it's lowercase letters, numbers and hyphens only
$hostnameValid = $($systemName -match "[a-z0-9\-]+")

if (!$hostnameValid) {
    Write-Output "Hostname is invalid. Exiting."
    exit
    # Logic for changing the hostname
}

# Would you like to move the WSL VHD to the largest drive?
# check if input is Y/N in a while loop
$moveVHD = $null
$wslRoot = $null
$wslBackup = $null
while ($moveVHD -ne "Y" -and $moveVHD -ne "N") {
    $moveVHD = Read-Host "Would you like to move the WSL VHD to the largest drive? (Y/N)"
}
# check if the input is valid
if ($moveVHD -eq "Y") {
    $moveVHD = $true
}
else {
    $moveVHD = $false
}

if ($moveVHD) {
    Write-Output "Moving the WSL VHD to the largest drive"
    # Find the Drive with most available space
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }
    $largestDrive = $drives | Sort-Object -Property Free -Descending | Select-Object -First 1
    # Get the root of the largest drive
    Write-Output $largestDrive.Root

    # Make folder(s) for WSL VHD migration
    $wslRoot = "$($largestDrive.Root)wsl"
    $wslBackup = "$($largestDrive.Root)wsl-backup"
    # make the folder if it doesn't exist
    if (!(Test-Path -Path $wslRoot)) {
        New-Item -Path $wslRoot -ItemType Directory
    }
    if (!(Test-Path -Path $wslBackup)) {
        New-Item -Path $wslBackup -ItemType Directory
    }
}
else {
    Write-Output "Not moving the WSL VHD to the largest drive"
}




# Installing Ubuntu # wait for the above to finish
wsl.exe --install -d $distro

Write-Output "WSL will open a separate window to complete the $distro installation"
Write-Output "Navigate to other window to complete. This requires setting a Username and Password"
Write-Output "When you have completed that step, return to this window and press Enter to continue"
# wait for input
# sleep for 20 seconds
Start-Sleep -Seconds 20
Read-Host "Press Enter to continue"
wsl.exe --update
wsl.exe --set-version $distro 2
wsl.exe --set-default-version 2
wsl.exe --set-default $distro
Write-Output "You will be prompted to enter the password for the user you created in the Ubuntu installation"
wsl.exe -d $distro sudo sh -c 'apt update && apt upgrade -y && echo \"[boot] \nsystemd=true\" > /etc/wsl.conf && apt-get update && apt-get install -y conntrack'

$serviceDefinition = @"
[Unit]
Description=Load nf_conntrack module and set nf_conntrack_max
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe nf_conntrack
ExecStart=/sbin/sysctl -w net.netfilter.nf_conntrack_max=131072
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
"@

# configure the nf_conntrack_max value and create the systemd service, also install containerd and start it as a service
wsl.exe -d $distro sudo bash -c "sysctl -w net.netfilter.nf_conntrack_max=131072 && echo 'net.netfilter.nf_conntrack_max=131072' | sudo tee -a /etc/sysctl.conf && sysctl -p && cat /etc/sysctl.conf | grep nf_conntrack_max && echo '$serviceDefinition' | sudo tee /etc/systemd/system/load-conntrack.service && systemctl enable load-conntrack.service && systemctl start load-conntrack.service && apt-get update && sudo apt-get install -y containerd && systemctl enable containerd && systemctl start containerd"
wsl.exe --shutdown

# assume input is invalid
$valid_username = 0
$valid_password = 0

# loop the input until it's valid
while (-not $valid_username) {
    # read username input
    $dockerhub_username = Read-Host "Enter your DockerHub username"
    # check if the username is valid
    $valid_username = $dockerhub_username -match "^[a-zA-Z0-9]([a-zA-Z0-9-]{3,})$"
}

while (-not $valid_password) {
    # read password input
    $dockerhub_password = Read-Host "Enter your DockerHub password"
    # check if the password is valid
    $valid_password = $dockerhub_password -match "^.{8,}$"
}

# perhaps should do a test auth here
$command = @"
echo '[plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"registry-1.docker.io\".auth]
username = \"{0}\"
password = \"{1}\"' >> /var/snap/microk8s/current/args/containerd-template.toml
"@ -f $dockerhub_username, $dockerhub_password

# install microk8s
wsl.exe -d $distro sudo bash -c "snap install microk8s --classic --channel=1.28/stable && microk8s status --wait-ready && microk8s kubectl get node -o wide && echo '# Docker Hub Credentials' >> /var/snap/microk8s/current/args/containerd-template.toml && $command && microk8s stop && microk8s start"
Write-Output "Microk8s is now installed. Waiting for it to be ready"

if ($moveVHD -and $wslRoot -ne $null -and $wslBackup -ne $null) {
    Write-Output "Now migrating the WSL VHD to the largest drive - $($largestDrive.Root)"
    # Make this optional (as it may not work on some machines)
    wsl.exe --export $distro "$wslBackup\$distro.tar"
    # delete the distro and reimport it to the new location
    wsl.exe --unregister $distro
    wsl.exe --import $distro $wslRoot "$wslBackup\$distro.tar"
}

Write-Output "Restarting Microk8s. Waiting for it to be ready"
Write-Output "Installing CincoDeBio Cores Services, this may take a few minutes"
wsl.exe -d $distro sudo bash -c "microk8s stop && microk8s start && microk8s enable dns && microk8s enable ingress && microk8s enable metrics-server && microk8s enable registry && microk8s enable hostpath-storage && microk8s enable storage && microk8s status --wait-ready && microk8s helm repo add scce $helm_repo && microk8s helm repo update && microk8s helm install --wait my-cinco-de-bio scce/cinco-de-bio --set global.containers.docker_hub_username=$dockerhub_username --set global.containers.docker_hub_password=$dockerhub_password"
# The IP address of the windows bridge adapter for wsl2 (which is used to access the k8s cluster) 
# is the first IP address of the distro, the second IP address is for internal traffic
wsl.exe -d $distro bash -c '
while true; do
  # Get the total number of pods (regardless of their status)
  total_pods_count=$(microk8s kubectl get pods --all-namespaces -o jsonpath="{.items[*].metadata.name}" | wc -w)

  # Get the number of pods not in the Running state
  pods_not_running_count=$(microk8s kubectl get pods --all-namespaces --field-selector=status.phase!=Running -o jsonpath="{.items[*].metadata.name}" | wc -w)

  # If there are no pods at all, wait until some pods are deployed
  if [ "$total_pods_count" -eq 0 ]; then
    echo "No pods found. Waiting for pods to be deployed..."
    sleep 10
    continue
  fi

  # If all pods are running, exit the loop
  if [ "$pods_not_running_count" -eq 0 ]; then
    echo "All $total_pods_count pods are running."
    break
  else
    echo "There are $pods_not_running_count Services not yet running out of $total_pods_count total pods. Checking again in 10 seconds..."
    sleep 10
  fi
done
'
# Clear Output from Shell
Clear-Host
$ip_address = $(wsl -d $distro hostname -I | ForEach-Object { ($_ -split ' ')[0] })
# Write Outputs
Write-Output "URL to Upload Portal (Copy this URL into your browser): http://$ip_address/data-manager/"
Write-Output "The CincoDeBio Cluster has started. IP Address: $ip_address (Copy this IP Address into the CincoDeBio Preferences in the Modelling Application)"
Write-Output "The CincoDeBio Cores Services are now being installed, this may take a few minutes"
Read-Host "Press Enter to Quit"