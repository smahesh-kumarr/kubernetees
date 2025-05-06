#!/bin/bash

# Step 1: Reset Kubernetes Cluster
echo "Resetting Kubernetes cluster..."
sudo kubeadm reset -f
sudo rm -rf ~/.kube
sudo systemctl restart containerd

# Step 2: Reconfigure kubeconfig
echo "Reconfiguring kubeconfig..."
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Step 3: Restart Services
echo "Restarting required services..."
sudo systemctl restart kubelet
sudo systemctl restart containerd

# Step 4: Verify Kubernetes Cluster Status
echo "Verifying Kubernetes cluster status..."
kubectl get nodes
kubectl get pods -A
