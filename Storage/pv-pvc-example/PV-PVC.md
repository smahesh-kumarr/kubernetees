# Kubernetes Persistent Volumes (PV), Persistent Volume Claims (PVC), and Amazon EFS - Complete Guide

## 🚀 Overview

This document explains how Kubernetes uses Persistent Volumes (PVs) and Persistent Volume Claims (PVCs) to manage storage, and how to integrate Amazon EFS (Elastic File System) into the storage workflow.

---

## 🏋️ Concepts

### ✅ Persistent Volume (PV)

* A piece of storage in the cluster that has been provisioned manually or dynamically.
* Independent of Pod lifecycle.
* Can be backed by cloud storage (like EBS, EFS) or local disks.

### ✅ Persistent Volume Claim (PVC)

* A request for storage by a user or application.
* Specifies size, access mode, and optionally a storage class.
* PVC gets **bound** to a suitable PV.

### ✅ Amazon EFS (Elastic File System)

* A managed NFS storage solution from AWS.
* Ideal for shared, persistent storage across multiple Pods or nodes.
* Supports ReadWriteMany (RWM) access mode.

---

## 🔄 Workflow of PV → PVC → Pod (Using EFS)

```text
Amazon EFS (fs-xxxxxx)
     ▲
     |
PersistentVolume (PV) with EFS CSI Driver
     ▲
     |
PersistentVolumeClaim (PVC)
     ▲
     |
Pod uses PVC as a volumeMount
```

---

## 📅 Use Case

* **Pod-1** uses PVC that requests 5GiB.
* PVC binds to a 100GiB PV backed by EFS.
* Data written by Pod-1 is stored on EFS.
* If Pod-1 is recreated, the new Pod reuses the same PVC.
* ✅ Data remains available = **persistence is ensured**.

---

## ❓ What Happens When Resources Are Deleted?

| Resource Deleted | With `Retain` Policy                   | With `Delete` Policy                 |
| ---------------- | -------------------------------------- | ------------------------------------ |
| Pod              | PVC and PV stay intact                 | PVC and PV stay intact               |
| PVC              | PV becomes Released, EFS data retained | PV is deleted, EFS folder is deleted |

---

## 📄 Example YAMLs

### 1. StorageClass (EFS)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
```

### 2. PersistentVolume (PV)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: fs-12345678  # Your EFS ID
```

### 3. PersistentVolumeClaim (PVC)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

### 4. Pod Using PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Hello from EFS > /data/msg.txt && sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: efs-vol
  volumes:
  - name: efs-vol
    persistentVolumeClaim:
      claimName: efs-pvc
```

---

## 🎉 Summary

* Pods are ephemeral; PVCs are persistent.
* PVCs request storage from PVs.
* PVs can be backed by AWS EFS for cloud-scale persistence.
* Reclaim policies (`Retain`, `Delete`) control lifecycle of PVs and actual data.
* Use `Retain` if you want to **keep the data** even after PVC is gone.

---

## 💡 Tips for DevOps Engineers

* Always check PVC status via `kubectl get pvc`.
* Monitor disk usage via EFS metrics.
* Use `ReadWriteMany` mode with EFS for multi-pod shared storage.
* Consider access control with IAM roles and EFS access points.
