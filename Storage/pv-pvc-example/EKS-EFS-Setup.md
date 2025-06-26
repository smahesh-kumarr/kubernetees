# AWS EKS with EFS Setup

This repository provides a complete setup guide for creating an Amazon EKS (Elastic Kubernetes Service) cluster with a single node, integrating Amazon EFS (Elastic File System) for persistent storage, and deploying a sample application using PersistentVolume (PV) and PersistentVolumeClaim (PVC). The setup includes instructions for managing the cluster from a local terminal using tools like PuTTY.

## Prerequisites

Before starting, ensure you have the following:

- **AWS Account** with appropriate permissions (AdministratorAccess recommended).
- **AWS CLI** installed and configured (`aws configure`).
- **kubectl** installed for Kubernetes management.
- **eksctl** installed for EKS cluster creation.
- **PuTTY** (or equivalent SSH client) for accessing the EC2 worker node.
- A key pair (`.pem` file) for SSH access, converted to `.ppk` for PuTTY if needed.
- Familiarity with AWS Management Console (UI).

## Cost Details

Amazon EKS does **not** offer a completely free tier. Below are the key costs:

- **EKS Control Plane**: ~$0.10/hour (~$72/month per cluster).
- **EC2 Worker Nodes**: Billed per EC2 pricing (e.g., t3.small). AWS Free Tier provides 750 hours/month for t2.micro/t3.micro instances.
- **EBS Volumes**: ~$0.10/GB-month for storage.
- **EFS**: ~$0.30/GB-month + data transfer costs.

**Tip**: To avoid costs, delete the cluster after use with `eksctl delete cluster`. For free Kubernetes experimentation, consider **Minikube**, **Kind**, or **EKS Anywhere**.

## Setup Instructions

### Step 1: Install Required Tools

1. **AWS CLI**:
   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-windows-x86_64.zip" -o "awscliv2.zip"
   ```
   Unzip and install using Command Prompt or PowerShell as admin.

2. **kubectl**:
   ```bash
   curl -o kubectl.exe https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-07-05/bin/windows/amd64/kubectl.exe
   ```
   Add `kubectl.exe` to your system PATH.

3. **eksctl**:
   ```bash
   choco install eksctl
   ```
   Install using Chocolatey (Windows) or equivalent for your OS.

### Step 2: Create EKS Cluster with Single Node

Run the following command to create a single-node EKS cluster:

```bash
eksctl create cluster \
  --name my-cluster \
  --version 1.27 \
  --region ap-south-1 \
  --nodegroup-name standard-workers \
  --node-type t3.small \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 1 \
  --managed
```

- This creates a VPC, EKS cluster, and one EC2 worker node (t3.small).
- Takes ~15 minutes to complete.

### Step 3: Test Cluster Access

Update your kubeconfig and verify the node:

```bash
aws eks --region ap-south-1 update-kubeconfig --name my-cluster
kubectl get nodes
```

You should see one node listed.

### Step 4: Access Worker Node via PuTTY

1. In AWS Console, go to **EC2 > Instances** and find the instance in your EKS node group.
2. Note the **Public IP** and ensure you have the associated key pair (`.pem` file).
3. Convert the `.pem` to `.ppk` using **PuTTYgen**.
4. Open **PuTTY**:
   - **Host**: `<Public-IP>`
   - **Auth**: Load the `.ppk` file.
   - **Username**: `ec2-user` (for Amazon Linux 2).
5. Connect to the node.

### Step 5: Create EFS File System

1. In AWS Console, go to **EFS > Create File System**.
2. Select the **same VPC and Availability Zone (AZ)** as your EKS cluster.
3. Create a new Security Group (`efs-sg`) for the EFS mount target.
4. Add a mount target in the same subnets as your EKS cluster.

### Step 6: Configure EFS Security Group

Modify the `efs-sg` Security Group:

- **Type**: NFS
- **Protocol**: TCP
- **Port Range**: 2049
- **Source**: Security Group ID of the EKS node group.

### Step 7: Install EFS CSI Driver

1. In AWS Console, go to **EKS > Your Cluster > Add-ons**.
2. Click **Create Add-on** and select **Amazon EFS CSI Driver**.
3. Choose the latest version.
4. Create a new IAM role (`AmazonEKS_EFS_CSI_DriverRole`) and attach the necessary policy.
5. Complete the add-on installation.

### Step 8: Create IAM Role for EFS Access

1. In AWS Console, go to **IAM > Policies > Create Policy**.
2. Use the following JSON for the `AmazonEFSCSIDriverPolicy`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems"
      ],
      "Resource": "*"
    }
  ]
}
```

3. Attach this policy to the EKS node group’s IAM role.

### Step 9: Create EFS Access Point (Optional)

1. In EFS Console, go to your EFS file system > **Access Points > Create Access Point**.
2. Configure:
   - **Name**: `eks-ap`
   - **Path**: `/eks`
   - **POSIX User ID**: `1000`
   - **Group ID**: `1000`
   - **Permissions**: `0755`

### Step 10: Create Kubernetes Resources

Apply the following YAML files to configure PersistentVolume (PV), PersistentVolumeClaim (PVC), and a sample pod.

1. **pv.yaml**:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pv
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
    volumeAttributes:
      accessPointId: fsap-xxxxxxxx  # Replace with your EFS Access Point ID
```

2. **pvc.yaml**:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 5Gi
  volumeName: efs-pv
```

3. **pod.yaml**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: efs-app
spec:
  containers:
  - name: app
    image: amazonlinux
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo Hello from EFS > /mnt/efs/hello.txt; sleep 30; done"]
    volumeMounts:
    - name: efs-volume
      mountPath: /mnt/efs
  volumes:
  - name: efs-volume
    persistentVolumeClaim:
      claimName: efs-pvc
```

Apply the files:

```bash
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f pod.yaml
```

### Step 11: Verify Setup

Check the status of the resources:

```bash
kubectl get pv
kubectl get pvc
kubectl get pods
```

Verify EFS is mounted:

```bash
kubectl exec -it efs-app -- cat /mnt/efs/hello.txt
```

Expected output:

```
Hello from EFS
```

### Step 12: Deploy a Sample Application

To test the cluster, deploy a simple Nginx application:

```bash
kubectl create deployment hello-world --image=nginx
kubectl expose deployment hello-world --type=LoadBalancer --port=80
kubectl get svc
```

Wait for the `EXTERNAL-IP` and access it in a browser.

## Cleanup

To avoid charges, delete the resources when done:

```bash
kubectl delete -f pod.yaml
kubectl delete -f pvc.yaml
kubectl delete -f pv.yaml
eksctl delete cluster --name my-cluster --region ap-south-1
```

## Notes

- Ensure the EFS file system and mount targets are in the **same Availability Zone** as your EKS cluster to avoid cross-AZ data transfer costs.
- The `AmazonEFSCSIDriverPolicy` allows the EKS nodes to access EFS. Modify permissions as needed for production.
- Use **PuTTY** or a similar SSH client to manage the EC2 worker node if needed.

## Troubleshooting

- **Node not visible**: Ensure `kubectl` is configured with `aws eks update-kubeconfig`.
- **EFS mount issues**: Verify the Security Group allows NFS (port 2049) and the IAM role is correctly attached.
- **Pod errors**: Check pod logs with `kubectl logs efs-app`.

## Contributing

Feel free to fork this repository, submit issues, or create pull requests to improve the setup!

## License

This project is licensed under the MIT License.
