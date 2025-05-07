# 🚀 NGINX DaemonSet Deployment in Kubernetes

This guide demonstrates how to create and manage a **DaemonSet** in Kubernetes that deploys an `nginx:1.19` container to every node in the cluster under the `logging` namespace.

---

## 📄 DaemonSet YAML Configuration

Save this configuration as `nginx-daemonset.yaml`.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx
  namespace: logging
spec:
  selector:
    matchLabels:
      name: nginx
  template:
    metadata:
      labels:
        name: nginx
    spec:
      containers:
        - name: nginx-container
          image: nginx:1.19
          ports:
            - containerPort: 80
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
```

---
# 📦 What This DaemonSet Does

---
## Configured with a RollingUpdate strategy where only 1 pod can be unavailable at a time during updates.

## ⚙️ Step-by-Step Usage
###1. Create the Namespace
```bash
kubectl create namespace logging
```

###2. Apply the DaemonSet Configuration
```bash
kubectl apply -f nginx-daemonset.yaml
```
##3. Verify DaemonSet Creation
```bash
kubectl get daemonset nginx -n logging
```

### 4. List All Pods Created by DaemonSet

```bash

kubectl get pods -n logging -o wide
```
### ✅ You should see one NGINX pod on each node.

### 5. Simulate Failure: Delete a Pod
```bash
kubectl delete pod <pod-name> -n logging
```
## 6. Observe Rolling Updates
## Change the image in nginx-daemonset.yaml to:


## image: nginx:1.20
### Apply the change:

```bash
kubectl apply -f nginx-daemonset.yaml
```

### Track the update:

```bash
kubectl rollout status daemonset/nginx -n logging
```
#### 7. Debugging and Logs

###To describe the DaemonSet:
```bash
kubectl describe daemonset nginx -n logging
```
### To view logs from a pod:

```bash
kubectl logs <pod-name> -n logging
```

### 🧹 Clean Up

```sh
kubectl delete -f nginx-daemonset.yaml
kubectl delete namespace loggin
```
