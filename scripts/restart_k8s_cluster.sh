#!/bin/bash

# Define the Kubernetes master IP address (use the correct IP if needed)
MASTER_IP=$(hostname -I | awk '{print $1}')

# Check system uptime
echo "System Uptime:"
uptime
echo

# Check if Kubernetes services are running (kubelet, containerd)
echo "Checking if Kubernetes services are running..."
sudo systemctl status kubelet | grep "Active"
sudo systemctl status containerd | grep "Active"
echo

# Restart Kubernetes services if they are not running
echo "Restarting Kubernetes services..."
sudo systemctl restart kubelet
sudo systemctl restart containerd
echo

# Check the IP address of the machine
echo "Checking the current IP address of the system..."
ip addr show | grep inet
echo

# Verify Kubernetes node status
echo "Checking the Kubernetes node status..."
kubectl get nodes
echo

# Verify the status of Kubernetes pods
echo "Checking the status of all Kubernetes pods..."
kubectl get pods --all-namespaces
echo

# Check for network plugin (Calico) status and apply if missing
echo "Checking if Calico networking plugin is installed..."
kubectl get pods -n kube-system | grep calico
if [ $? -ne 0 ]; then
    echo "Calico plugin not found, applying Calico network..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
    echo "Calico plugin applied."
fi
echo

# Check for disk space and memory issues
echo "Checking disk space..."
df -h
echo

echo "Checking memory usage..."
free -m
echo

# Check if Kubernetes API server is up and running
echo "Checking the Kubernetes API server..."
kubectl cluster-info
echo

# Check for running pods and nodes
echo "Verifying that all Kubernetes pods are running..."
kubectl get pods --all-namespaces
echo

# If IP address has changed, you might need to reinit the master node with the new IP
echo "Checking for node IP change..."
if [[ "$(hostname -I)" != "$MASTER_IP" ]]; then
    echo "IP address has changed. Reinitializing Kubernetes master node..."
    sudo kubeadm init --apiserver-advertise-address=$(hostname -I | awk '{print $1}') --pod-network-cidr=192.168.0.0/16
    echo "Reinitialized Kubernetes master node."
fi
echo

# Restart and check the status of the cluster
echo "Final status check of Kubernetes cluster..."
sudo systemctl restart kubelet
echo "Kubernetes services restarted. Please verify your node and pod status."
kubectl get nodes
kubectl get pods --all-namespaces
echo

echo "Kubernetes cluster restart process complete!"
