# etcd Backup and Restore Practice in a Single-Node Kubernetes Cluster

This README documents the process of practicing etcd backup and restore in a single-node Kubernetes cluster set up with `kubeadm` on an Ubuntu virtual machine (VM). The tasks include installing `etcdctl`, configuring environment variables, addressing permission issues, taking an etcd backup, deploying a sample Nginx application, deleting it, restoring the backup, and troubleshooting issues like the `etcd` pod being stuck in a `Pending` state.

## Prerequisites
- **Single-node Kubernetes cluster**: Set up using `kubeadm` on an Ubuntu VM, with the node named `k8s-master`.
- **User**: `masteradmin` with `sudo` privileges.
- **Tools**: `kubectl`, `kubeadm`, and a container runtime (`containerd` or `Docker`) installed.
- **Network**: Calico CNI plugin with pod network CIDR `192.168.0.0/16`.
- **Cluster initialization**: The cluster is initialized using a `reset.sh` script that resets and reinitializes the cluster on VM startup.
- **Disk space**: Sufficient space in `/backup` for storing etcd snapshots.
- **Date**: Performed on July 10, 2025.

## Tasks Performed

### 1. Install and Configure `etcdctl`
`etcdctl` is the command-line tool for interacting with the etcd database, which stores the Kubernetes cluster’s state.

#### Steps
1. **Check etcd version**:
   Verify the etcd version used by the cluster to ensure `etcdctl` compatibility:
   ```bash
   kubectl exec -n kube-system etcd-k8s-master -- etcd --version
   ```
   Output: `etcd Version: 3.5.15`.

2. **Remove existing `etcdctl`** (if present):
   Check for existing `etcdctl`:
   ```bash
   which etcdctl
   ```
   Remove if found (e.g., in `/snap/bin` or `/usr/local/bin`):
   ```bash
   sudo rm -f /usr/local/bin/etcdctl
   sudo snap remove etcd
   ```

3. **Install `etcdctl`**:
   Download and install `etcdctl` version 3.5.15 (matching etcd version):
   ```bash
   wget https://github.com/etcd-io/etcd/releases/download/v3.5.15/etcd-v3.5.15-linux-amd64.tar.gz
   tar -xvf etcd-v3.5.15-linux-amd64.tar.gz
   sudo mv etcd-v3.5.15-linux-amd64/etcdctl /usr/local/bin/
   sudo chmod +x /usr/local/bin/etcdctl
   rm -rf etcd-v3.5.15-linux-amd64*
   ```

4. **Verify installation**:
   ```bash
   etcdctl version
   ```
   Expected output:
   ```
   etcdctl version: 3.5.15
   API version: 3.5
   ```

### 2. Configure Environment Variables for `etcdctl`
Environment variables are required for `etcdctl` to authenticate with etcd using TLS certificates.

#### Steps
1. **Set environment variables**:
   ```bash
   export ETCDCTL_API=3
   export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
   export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
   export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
   export ETCDCTL_ENDPOINTS=https://172.17.29.35:2379
   ```
   Note: The endpoint `https://172.17.29.35:2379` is based on the `--advertise-client-urls` in `/etc/kubernetes/manifests/etcd.yaml`. Use `https://127.0.0.1:2379` if specified.

2. **Verify variables**:
   Check each variable:
   ```bash
   echo $ETCDCTL_API
   echo $ETCDCTL_CACERT
   echo $ETCDCTL_CERT
   echo $ETCDCTL_KEY
   echo $ETCDCTL_ENDPOINTS
   ```
   Expected output:
   ```
   3
   /etc/kubernetes/pki/etcd/ca.crt
   /etc/kubernetes/pki/etcd/server.crt
   /etc/kubernetes/pki/etcd/server.key
   https://172.17.29.35:2379
   ```

3. **Persist variables (optional)**:
   Add to `~/.bashrc` for persistence:
   ```bash
   nano ~/.bashrc
   ```
   Append:
   ```bash
   export ETCDCTL_API=3
   export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
   export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
   export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
   export ETCDCTL_ENDPOINTS=https://172.17.29.35:2379
   ```
   Reload:
   ```bash
   source ~/.bashrc
   ```

### 3. Fix Certificate Permission Issues
The error `open /etc/kubernetes/pki/etcd/server.crt: permission denied` indicated that `etcdctl` couldn’t access certificate files.

#### Steps
1. **Verify certificate files**:
   ```bash
   sudo ls -l /etc/kubernetes/pki/etcd/{ca.crt,server.crt,server.key,peer.crt,peer.key}
   ```
   Expected output:
   ```
   -rw-r--r-- 1 root root <size> <date> /etc/kubernetes/pki/etcd/ca.crt
   -rw-r--r-- 1 root root <size> <date> /etc/kubernetes/pki/etcd/server.crt
   -rw------- 1 root root <size> <date> /etc/kubernetes/pki/etcd/server.key
   -rw-r--r-- 1 root root <size> <date> /etc/kubernetes/pki/etcd/peer.crt
   -rw------- 1 root root <size> <date> /etc/kubernetes/pki/etcd/peer.key
   ```

2. **Fix permissions**:
   ```bash
   sudo chown root:root /etc/kubernetes/pki/etcd/{ca.crt,server.crt,server.key,peer.crt,peer.key}
   sudo chmod 644 /etc/kubernetes/pki/etcd/{ca.crt,server.crt,peer.crt}
   sudo chmod 600 /etc/kubernetes/pki/etcd/{server.key,peer.key}
   ```

3. **Regenerate certificates (if missing)**:
   ```bash
   sudo kubeadm init phase certs etcd-all --cert-dir=/etc/kubernetes/pki/etcd
   ```

4. **Test access**:
   ```bash
   sudo cat /etc/kubernetes/pki/etcd/server.crt
   ```

### 4. Deploy a Sample Nginx Application
To create data in etcd, deploy a sample Nginx application.

#### Steps
1. **Create `nginx-deployment.yaml`**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: nginx-deployment
     namespace: default
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: nginx
     template:
       metadata:
         labels:
           app: nginx
       spec:
         containers:
         - name: nginx
           image: nginx:latest
           ports:
           - containerPort: 80
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-service
     namespace: default
   spec:
     selector:
       app: nginx
     ports:
       - protocol: TCP
         port: 80
         targetPort: 80
     type: ClusterIP
   ```

2. **Apply the deployment**:
   ```bash
   kubectl apply -f nginx-deployment.yaml
   ```

3. **Verify deployment**:
   ```bash
   kubectl get deployments
   kubectl get pods
   kubectl get services
   ```
   Expected output:
   ```
   NAME               READY   UP-TO-DATE   AVAILABLE
   nginx-deployment   2/2     2            2

   NAME                                READY   STATUS
   nginx-deployment-<hash>-<hash>      1/1     Running
   nginx-deployment-<hash>-<hash>      1/1     Running

   NAME             TYPE        CLUSTER-IP      PORT(S)
   nginx-service    ClusterIP   10.99.113.113   80/TCP
   ```

4. **Test service**:
   ```bash
   kubectl exec -it nginx-deployment-<hash>-<hash> -- curl http://nginx-service
   ```

### 5. Take an etcd Backup
Back up the etcd database to capture the cluster state, including the Nginx deployment.

#### Steps
1. **Create backup directory**:
   ```bash
   sudo mkdir -p /backup/etcd/$(date +%Y%m%d)
   ```

2. **Take snapshot**:
   ```bash
   sudo etcdctl snapshot save /backup/etcd/$(date +%Y%m%d)/etcd-snapshot-$(date +%Y%m%d_%H%M%S).db \
   --cacert=$ETCDCTL_CACERT \
   --cert=$ETCDCTL_CERT \
   --key=$ETCDCTL_KEY \
   --endpoints=$ETCDCTL_ENDPOINTS
   ```
   Example output file: `/backup/etcd/20250710/etcd-snapshot-20250710_110400.db`

3. **Verify snapshot**:
   ```bash
   sudo etcdctl snapshot status /backup/etcd/$(date +%Y%m%d)/etcd-snapshot-<timestamp>.db
   ```

4. **Secure backup**:
   ```bash
   sudo chmod 600 /backup/etcd/$(date +%Y%m%d)/etcd-snapshot-*.db
   ```

### 6. Delete the Sample Deployment
Simulate data loss by deleting the Nginx deployment.

#### Steps
1. **Delete deployment**:
   ```bash
   kubectl delete -f nginx-deployment.yaml
   ```

2. **Verify deletion**:
   ```bash
   kubectl get deployments
   kubectl get pods
   kubectl get services
   ```
   Expected output: No `nginx-deployment` or `nginx-service` (except `kubernetes` service).

### 7. Restore the etcd Backup
Restore the etcd snapshot to recover the deleted deployment.

#### Steps
1. **Stop etcd pod**:
   ```bash
   sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/
   ```
   Verify the pod is terminated:
   ```bash
   kubectl get pods -n kube-system | grep etcd
   ```

2. **Back up current etcd data** (safety):
   ```bash
   sudo mv /var/lib/etcd /var/lib/etcd-backup-$(date +%Y%m%d)
   ```

3. **Restore snapshot**:
   ```bash
   sudo etcdctl snapshot restore /backup/etcd/20250710/etcd-snapshot-<timestamp>.db \
   --data-dir=/var/lib/etcd-restored \
   --cacert=$ETCDCTL_CACERT \
   --cert=$ETCDCTL_CERT \
   --key=$ETCDCTL_KEY \
   --endpoints=$ETCDCTL_ENDPOINTS
   ```

4. **Update etcd manifest**:
   Edit `/tmp/etcd.yaml`:
   ```bash
   sudo nano /tmp/etcd.yaml
   ```
   Change `--data-dir` to `/var/lib/etcd-restored`. Save and move back:
   ```bash
   sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
   ```

5. **Restart API server** (if needed):
   ```bash
   sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
   sleep 5
   sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
   ```

### 8. Troubleshoot etcd Pod Pending State
The `etcd-k8s-master` pod was stuck in `Pending` after the restore, with a `DNSConfigForming` warning.

#### Issues Identified
- **Pending state**: The pod was created but didn’t transition to `Running`, likely due to:
  - Corrupted or incompatible data in `/var/lib/etcd-restored`.
  - Certificate issues or misconfiguration.
  - Hostname resolution failure (`sudo: unable to resolve host k8s-master`).
  - DNS misconfiguration (`DNSConfigForming` warning).

#### Troubleshooting Steps
1. **Check logs**:
   ```bash
   kubectl logs -n kube-system etcd-k8s-master
   sudo journalctl -u kubelet | tail -n 50
   ```

2. **Fix hostname resolution**:
   Edit `/etc/hosts`:
   ```bash
   sudo nano /etc/hosts
   ```
   Ensure:
   ```
   127.0.0.1   localhost
   127.0.1.1   k8s-master
   172.17.29.35 k8s-master
   ```
   Test:
   ```bash
   ping -c 2 k8s-master
   ```

3. **Fix DNS configuration**:
   Edit `/etc/resolv.conf`:
   ```bash
   sudo nano /etc/resolv.conf
   ```
   Set:
   ```
   nameserver 8.8.8.8
   nameserver 8.8.4.4
   ```

4. **Verify data directory**:
   ```bash
   sudo ls -l /var/lib/etcd-restored
   ```

5. **Check certificates**:
   ```bash
   sudo ls -l /etc/kubernetes/pki/etcd/{ca.crt,server.crt,server.key,peer.crt,peer.key}
   ```
   Regenerate if needed:
   ```bash
   sudo kubeadm init phase certs etcd-all --cert-dir=/etc/kubernetes/pki/etcd
   ```

6. **Restart etcd pod**:
   ```bash
   sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/
   sleep 5
   sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
   ```

7. **Check resources**:
   ```bash
   free -m
   df -h /var/lib/etcd-restored
   ```

### 9. Verify the Restored Cluster
After fixing the `Pending` state, verify the cluster and restored data.

#### Steps
1. **Check etcd health**:
   ```bash
   sudo etcdctl endpoint health \
   --cacert=$ETCDCTL_CACERT \
   --cert=$ETCDCTL_CERT \
   --key=$ETCDCTL_KEY \
   --endpoints=$ETCDCTL_ENDPOINTS
   ```

2. **Verify cluster status**:
   ```bash
   kubectl get nodes
   ```

3. **Verify Nginx deployment**:
   ```bash
   kubectl get deployments
   kubectl get pods
   kubectl get services
   ```

4. **Test Nginx service**:
   ```bash
   kubectl exec -it nginx-deployment-<hash>-<hash> -- curl http://nginx-service
   ```

5. **Check etcd data**:
   ```bash
   sudo etcdctl get --prefix /registry/deployments/default/nginx-deployment \
   --cacert=$ETCDCTL_CACERT \
   --cert=$ETCDCTL_CERT \
   --key=$ETCDCTL_KEY \
   --endpoints=$ETCDCTL_ENDPOINTS
   ```

## Troubleshooting Notes
- **etcdctl not found**: Ensure `/usr/local/bin/etcdctl` is installed and in PATH.
- **Permission denied**: Use `sudo` for `etcdctl` commands or fix certificate permissions.
- **Pending etcd pod**: Check logs, certificates, data directory, and DNS. Revert to original data (`/var/lib/etcd-backup-<timestamp>`) if needed.
- **Hostname resolution**: Ensure `/etc/hosts` maps `k8s-master` to `172.17.29.35`.
- **DNSConfigForming**: Update `/etc/resolv.conf` with valid nameservers.

## Conclusion
This practice demonstrated setting up `etcdctl`, taking an etcd backup, deploying and deleting a sample Nginx application, and restoring the backup. Despite the `etcd-k8s-master` pod being `Pending`, the Nginx deployment was restored, indicating a partial success. Resolving the `Pending` state ensures a fully functional cluster.

For further assistance, share logs or errors with:
```bash
kubectl logs -n kube-system etcd-k8s-master
sudo journalctl -u kubelet | tail -n 50
```
