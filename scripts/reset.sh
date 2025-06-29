#!/bin/bash

set -e

echo "⚠️  Resetting Kubernetes Cluster..."

# Step 1: Reset kubeadm
echo "🧹 Running kubeadm reset..."
sudo kubeadm reset -f

# Step 2: Clean up Kubernetes and CNI related directories
echo "🧼 Removing old config and CNI files..."
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /etc/kubernetes

# Step 3: Delete any old CNI network interfaces
echo "🧯 Deleting CNI interfaces (ignore errors if not present)..."
sudo ip link delete cni0 || true
sudo ip link delete flannel.1 || true

# Step 4: Restart container runtime and kubelet
echo "🔄 Restarting container runtime and kubelet..."
sudo systemctl daemon-reexec
sudo systemctl restart containerd || sudo systemctl restart docker
sudo systemctl restart kubelet

# Step 5: Initialize Kubernetes master node
echo "🚀 Re-initializing the Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Step 6: Setup kubeconfig for current user
echo "🔧 Configuring kubectl access..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Step 7: Install Calico CNI plugin
echo "🌐 Installing Calico CNI plugin..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Final status
echo "✅ Kubernetes cluster reset and reinitialized successfully!"
kubectl get nodes

kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule- 
