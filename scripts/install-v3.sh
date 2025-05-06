#!/bin/bash

# Step 1: Disable Swap
echo "🔧 Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Step 2: Set Hostname
echo "🔧 Setting hostname..."
sudo hostnamectl set-hostname k8s-master

# Step 3: Load Kernel Modules & Set Sysctl Params
echo "🔧 Loading kernel modules and setting sysctl parameters..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Step 4: Remove duplicate/old Kubernetes repositories and fix
echo "⚙️ Fixing Kubernetes repo..."
sudo rm /etc/apt/sources.list.d/archive_uri-https_apt_kubernetes_io_-jammy.list
sudo rm /etc/apt/sources.list.d/kubernetes.list

# Add Kubernetes repo for Ubuntu 22.04 (Jammy)
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# Step 5: Install Container Runtime (containerd)
echo "🐳 Installing containerd runtime..."
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Step 6: Install Kubernetes Tools (kubeadm, kubelet, kubectl)
echo "🔧 Installing Kubernetes tools..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Step 7: Enable Kubelet Service
echo "🔧 Enabling kubelet service..."
sudo systemctl enable kubelet.service
sudo systemctl start kubelet.service

# Step 8: Initialize the Kubernetes Cluster (Single Node)
echo "⚙️ Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Step 9: Set up kubeconfig
echo "🔧 Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Step 10: Install Pod Network Add-on (Calico Recommended)
echo "🔧 Installing Calico network plugin..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Step 11: Allow Scheduling Pods on Control Plane (for single-node setup)
echo "🔧 Allowing scheduling of pods on the control plane..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Step 12: Verify the installation
echo "🔧 Verifying installation..."
kubectl get nodes
kubectl get pods -A

echo "🎉 Kubernetes installation complete!"

