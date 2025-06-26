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

- **How it works**: You define a StorageClass with a
