#!/bin/bash

# Step 1: Stop and Disable Kubernetes Services
echo "Stopping Kubernetes services..."
sudo systemctl stop kubelet
sudo systemctl stop containerd
sudo systemctl disable kubelet
sudo systemctl disable containerd

# Step 2: Remove Kubernetes Packages
echo "Removing Kubernetes packages..."
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni
sudo apt-get autoremove -y

# Step 3: Remove Docker (if installed) or other container runtimes
echo "Removing container runtime..."
sudo apt-get purge -y docker.io containerd
sudo apt-get autoremove -y

# Step 4: Clean up Kubernetes Configuration and Data Files
echo "Cleaning up Kubernetes configuration files..."
sudo rm -rf ~/.kube
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/etcd

# Step 5: Clean up Network CNI Files
echo "Cleaning up network CNI files..."
sudo rm -rf /etc/cni

# Step 6: Reset iptables rules and network interfaces
echo "Resetting iptables and network settings..."
sudo ip link set cni0 down
sudo ip link delete cni0
sudo ip link set flannel.1 down
sudo ip link delete flannel.1
sudo ip link set docker0 down
sudo ip link delete docker0
sudo ip link set br-xxxx down
sudo ip link delete br-xxxx

# Step 7: Clean up Residual Directories
echo "Removing residual directories..."
sudo rm -rf /etc/containerd
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# Step 8: Optionally, Remove any remaining Docker images (if Docker was installed)
# Uncomment the line below to clean Docker images, containers, and volumes
# sudo docker system prune -a -f

# Step 9: Clean apt cache
echo "Cleaning apt cache..."
sudo apt-get clean

# Step 10: Reboot System
echo "Rebooting system..."
sudo reboot
