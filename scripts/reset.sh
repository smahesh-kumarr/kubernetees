#!/bin/bash

set -e

echo "⚠️  Resetting and Reinitializing Kubernetes Single-Node Cluster..."

# Check prerequisites
echo "🔍 Checking prerequisites..."
if ! command -v kubeadm >/dev/null 2>&1 || ! command -v kubectl >/dev/null 2>&1 || ! command -v kubelet >/dev/null 2>&1; then
    echo "❌ Kubernetes tools (kubeadm, kubectl, kubelet) not installed. Please install them first."
    exit 1
fi
if ! command -v containerd >/dev/null 2>&1; then
    echo "❌ containerd not installed. Please install it first."
    exit 1
fi

# Check swap
if swapon --show | grep -q .; then
    echo "❌ Swap is enabled. Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
fi

# Step 1: Stop Kubernetes services
echo "🛑 Stopping kubelet and containerd services..."
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true

# Step 2: Reset kubeadm
echo "🧹 Running kubeadm reset..."
sudo kubeadm reset -f || true

# Step 3: Clean up Kubernetes and CNI directories
echo "🧼 Removing old config and CNI files..."
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/kubernetes
sudo rm -rf $HOME/.kube
sudo rm -rf /var/lib/etcd

# Step 4: Delete CNI network interfaces
echo "🧯 Deleting CNI interfaces (ignore errors if not present)..."
sudo ip link delete cni0 || true
sudo ip link delete flannel.1 || true
sudo ip link delete cali0 || true

# Step 5: Flush iptables
echo "🧹 Clearing iptables rules..."
sudo iptables -F
sudo iptables -X
sudo ip6tables -F
sudo ip6tables -X
sudo iptables-save > /dev/null
sudo ip6tables-save > /dev/null

# Step 6: Restart container runtime
echo "🔄 Restarting containerd..."
sudo systemctl daemon-reexec
sudo systemctl restart containerd
sudo systemctl enable containerd

# Step 7: Initialize Kubernetes master node
echo "🚀 Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Step 8: Set up kubeconfig for current user
echo "🔧 Configuring kubectl access..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Step 9: Remove control-plane taint for single-node cluster
echo "🔓 Making control plane node schedulable..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

# Step 10: Install Calico CNI plugin
echo "🌐 Checking internet connectivity for Calico..."
if ! ping -c 3 google.com >/dev/null 2>&1; then
    echo "❌ No internet connectivity. Please check network and retry."
    exit 1
fi
echo "🌐 Installing Calico CNI plugin (v3.28.2)..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# Step 11: Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready (up to 120 seconds)..."
sleep 10
for i in {1..12}; do
    if kubectl get nodes | grep -q "Ready"; then
        echo "✅ Cluster is ready!"
        break
    fi
    echo "⌛ Waiting for nodes to be ready... ($i/12)"
    sleep 10
done

# Final status
echo "✅ Kubernetes single-node cluster reinitialized successfully!"
kubectl get nodes
kubectl get pods -n kube-system -o wide

echo "🎉 Cluster setup complete! You can now deploy applications."
