# Understanding StorageClass and Static vs Dynamic Provisioning in Kubernetes with EFS

This repository explains the concept of **StorageClass** in Kubernetes, the differences between **Static** and **Dynamic Provisioning**, and provides practical examples of each using Amazon EFS (Elastic File System) with an AWS EKS (Elastic Kubernetes Service) cluster. The setup assumes you have an EKS cluster configured with the EFS CSI Driver and necessary permissions.

## What is a StorageClass?

A **StorageClass** in Kubernetes is like a blueprint that defines how storage is created and managed for **Persistent Volume Claims (PVCs)**. It tells Kubernetes:

- **What type of storage** to use (e.g., Amazon EBS, EFS, NFS).
- **How to provision** the storage (e.g., size, performance settings).
- **Additional parameters** (e.g., encryption, permissions, or access points).

Without a StorageClass, you must manually create a **Persistent Volume (PV)** and match it to a PVC (Static Provisioning). With a StorageClass, Kubernetes can automatically create a PV when a PVC is requested (Dynamic Provisioning).

### Why Use a StorageClass?

- **Simplifies storage management**: Automates the creation of storage resources.
- **Scalability**: Easily supports multiple applications with different storage needs.
- **Flexibility**: Allows customization of storage parameters (e.g., EFS access points, performance modes).

## Static vs Dynamic Provisioning

### Static Provisioning
In **Static Provisioning**, the administrator manually creates a **Persistent Volume (PV)** that points to an existing storage resource (e.g., an EFS file system). The PVC is then manually configured to bind to this specific PV.

- **How it works**: You pre-create the storage (e.g., EFS in AWS) and define a PV to represent it. The PVC must match the PV’s specifications (e.g., capacity, access modes).
- **Use case**: When you have a fixed storage resource that you want to reuse (e.g., an existing EFS file system).
- **Drawbacks**: Manual, less flexible, and requires precise matching between PV and PVC.

### Dynamic Provisioning
In **Dynamic Provisioning**, Kubernetes automatically creates a **Persistent Volume (PV)** when a **Persistent Volume Claim (PVC)** is created, based on the rules defined in a **StorageClass**.

- **How it works**: You define a StorageClass with a provisioner (e.g., `efs.csi.aws.com`). When a PVC references this StorageClass, Kubernetes creates a PV and provisions the storage automatically (e.g., a new EFS access point or volume).
- **Use case**: When you want storage to be created on-demand for applications.
- **Benefits**: Fully automated, scalable, and reduces manual configuration.

### Key Differences

| **Feature**               | **Static Provisioning**                     | **Dynamic Provisioning**                     |
|---------------------------|---------------------------------------------|---------------------------------------------|
| **Volume Creation**       | Admin manually creates PV                  | Kubernetes creates PV automatically         |
| **StorageClass Required** | No (can use empty `storageClassName`)       | Yes (PVC references a StorageClass)         |
| **Automation**            | Manual setup                               | Fully automated                            |
| **Flexibility**           | Less flexible, pre-allocated storage        | More flexible, on-demand storage            |
| **Who Creates Storage?**  | Admin (e.g., creates EFS in AWS)           | Kubernetes (via StorageClass provisioner)   |
| **PVC Matching**          | Must match PV’s capacity and access modes   | Auto-bound to dynamically created PV        |
| **Use Case**              | Fixed, pre-existing storage                | Scalable, on-demand storage for apps        |

### How Kubernetes Matches PVC to PV
Kubernetes binds a PVC to a PV based on:
- **accessModes** (e.g., `ReadWriteMany`, `ReadWriteOnce`).
- **storageClassName** (must match or be empty for static).
- **Requested storage** (PVC’s requested size ≤ PV’s capacity).
- **volumeName** (in static provisioning, PVC specifies the exact PV name).

## Prerequisites

Before proceeding with the examples, ensure you have:
- An **AWS EKS cluster** running (version 1.27 or later recommended).
- **EFS CSI Driver** installed (see [previous setup](#)).
- An **EFS File System** created in the same VPC and Availability Zone as your EKS cluster.
- **IAM Role** with `AmazonEFSCSIDriverPolicy` attached to the EKS node group.
- **kubectl** installed and configured to interact with your EKS cluster.
- AWS CLI configured with `aws configure`.

## Example: Static vs Dynamic Provisioning with EFS

Below are two examples demonstrating **Static** and **Dynamic Provisioning** using Amazon EFS in an EKS cluster.

### Example 1: Static Provisioning

In this example, you manually create a **Persistent Volume (PV)** that points to an existing EFS file system, and a **Persistent Volume Claim (PVC)** binds to it.

1. **Create the Persistent Volume (PV)**:

   Save the following as `pv-static.yaml`:

   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: my-static-pv
   spec:
     capacity:
       storage: 5Gi
     volumeMode: Filesystem
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain
     storageClassName: ""
     csi:
       driver: efs.csi.aws.com
       volumeHandle: fs-xxxxxxxx  # Replace with your EFS File System ID
   ```

   **Note**: Replace `fs-xxxxxxxx` with your actual EFS File System ID (found in the AWS EFS Console).

2. **Create the Persistent Volume Claim (PVC)**:

   Save the following as `pvc-static.yaml`:

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: my-static-pvc
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: ""
     resources:
       requests:
         storage: 5Gi
     volumeName: my-static-pv
   ```

   **Note**: The `volumeName` field explicitly binds this PVC to the `my-static-pv` PV.

3. **Create a Pod to Use the PVC**:

   Save the following as `pod-static.yaml`:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: efs-static-app
   spec:
     containers:
     - name: app
       image: amazonlinux
       command: ["/bin/sh"]
       args: ["-c", "while true; do echo Hello from Static EFS > /mnt/efs/hello.txt; sleep 30; done"]
       volumeMounts:
       - name: efs-volume
         mountPath: /mnt/efs
     volumes:
     - name: efs-volume
       persistentVolumeClaim:
         claimName: my-static-pvc
   ```

4. **Apply the Configurations**:

   ```bash
   kubectl apply -f pv-static.yaml
   kubectl apply -f pvc-static.yaml
   kubectl apply -f pod-static.yaml
   ```

5. **Verify the Setup**:

   Check the PV, PVC, and pod status:

   ```bash
   kubectl get pv
   kubectl get pvc
   kubectl get pods
   ```

   Verify the EFS mount:

   ```bash
   kubectl exec -it efs-static-app -- cat /mnt/efs/hello.txt
   ```

   Expected output:
   ```
   Hello from Static EFS
   ```

### Example 2: Dynamic Provisioning

In this example, you create a **StorageClass** to allow Kubernetes to dynamically provision an EFS-backed Persistent Volume when a PVC is created.

1. **Create the StorageClass**:

   Save the following as `storageclass.yaml`:

   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: efs-sc
   provisioner: efs.csi.aws.com
   parameters:
     provisioningMode: efs-ap
     fileSystemId: fs-xxxxxxxx  # Replace with your EFS File System ID
     directoryPerms: "700"
     gidRangeStart: "1000"
     gidRangeEnd: "2000"
     basePath: "/dynamic_provisioning"
   ```

   **Note**: Replace `fs-xxxxxxxx` with your actual EFS File System ID.

2. **Create the Persistent Volume Claim (PVC)**:

   Save the following as `pvc-dynamic.yaml`:

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: my-dynamic-pvc
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: efs-sc
     resources:
       requests:
         storage: 5Gi
   ```

3. **Create a Pod to Use the PVC**:

   Save the following as `pod-dynamic.yaml`:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: efs-dynamic-app
   spec:
     containers:
     - name: app
       image: amazonlinux
       command: ["/bin/sh"]
       args: ["-c", "while true; do echo Hello from Dynamic EFS > /mnt/efs/hello.txt; sleep 30; done"]
       volumeMounts:
       - name: efs-volume
         mountPath: /mnt/efs
     volumes:
     - name: efs-volume
       persistentVolumeClaim:
         claimName: my-dynamic-pvc
   ```

4. **Apply the Configurations**:

   ```bash
   kubectl apply -f storageclass.yaml
   kubectl apply -f pvc-dynamic.yaml
   kubectl apply -f pod-dynamic.yaml
   ```

5. **Verify the Setup**:

   Check the PV, PVC, and pod status:

   ```bash
   kubectl get pv
   kubectl get pvc
   kubectl get pods
   ```

   Verify the EFS mount:

   ```bash
   kubectl exec -it efs-dynamic-app -- cat /mnt/efs/hello.txt
   ```

   Expected output:
   ```
   Hello from Dynamic EFS
   ```

## Why Use Dynamic Provisioning with EFS?

- **Automation**: No need to manually create PVs for each application.
- **Scalability**: Easily create storage for multiple pods or applications.
- **Flexibility**: Supports `ReadWriteMany` (multiple pods can mount the same EFS volume).
- **EFS Access Points**: Dynamic provisioning with EFS often uses access points to isolate directories for different applications, improving security and organization.

## Cleanup

To avoid AWS charges, delete the resources when done:

```bash
# Static Provisioning
kubectl delete -f pod-static.yaml
kubectl delete -f pvc-static.yaml
kubectl delete -f pv-static.yaml

# Dynamic Provisioning
kubectl delete -f pod-dynamic.yaml
kubectl delete -f pvc-dynamic.yaml
kubectl delete -f storageclass.yaml

# Delete EKS Cluster (if no longer needed)
eksctl delete cluster --name my-cluster --region ap-south-1
```
