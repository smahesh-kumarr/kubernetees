# CronTab Operator: Custom Resource Definition, Resource, and Controller

The **CronTab Operator** is a Kubernetes operator that extends the Kubernetes API to manage custom `CronTab` resources. It demonstrates how to create a **Custom Resource Definition (CRD)**, instantiate **Custom Resources (CRs)**, and implement a **Custom Controller** to manage cron-like jobs in a Kubernetes cluster. This project allows users to define scheduled jobs using a declarative YAML interface, with a controller to reconcile the desired state with the actual state.

## Overview

This project provides a practical example of extending Kubernetes with:
- A **Custom Resource Definition (CRD)** for a `CronTab` resource, defining a custom API for managing cron-like jobs.
- **Custom Resources (CRs)** to specify job configurations, such as cron schedules, container images, and replicas.
- A **Custom Controller** to watch `CronTab` resources and perform actions (e.g., logging details or creating Pods).

The `CronTab` resource enables users to specify a cron schedule (`cronSpec`), a container image (`image`), and the number of replicas (`replicas`), with the controller ensuring the desired state is maintained.

## Features

- **Custom Resource Definition**: Defines a `CronTab` resource with a schema for `cronSpec`, `image`, and `replicas`.
- **Declarative Configuration**: Users can create `CronTab` instances using YAML manifests, leveraging Kubernetes' declarative model.
- **Custom Controller**: A basic controller watches `CronTab` resources and logs their details (extendable for production use cases like creating Pods or scheduling jobs).
- **Kubernetes-Native**: Integrates seamlessly with `kubectl`, RBAC, Helm, and other Kubernetes tools.

## Prerequisites

To set up and run this project, you need:
- A Kubernetes cluster (e.g., Minikube, Kind, or a cloud provider like GKE, EKS, or AKS).
- `kubectl` installed and configured to access the cluster.
- Go (version 1.20 or later) for building the controller.
- [Kubebuilder](https://book.kubebuilder.io) installed (`go install sigs.k8s.io/kubebuilder/v3`).
- Docker for building and pushing the controller image.
- A container registry (e.g., Docker Hub) for storing the controller image.

## Step-by-Step Implementation

Follow these steps to create the CRD, CR, and custom controller for the `CronTab` operator.

### Step 1: Initialize the Kubebuilder Project

1. Create a new directory for the project and initialize it with Kubebuilder:

```bash
mkdir crontab-operator
cd crontab-operator
kubebuilder init --domain example.com --repo example.com/crontab-operator
```

This sets up the project structure and Go module.

2. Create the API and controller scaffolding for the `CronTab` resource:

```bash
kubebuilder create api --group stable --version v1 --kind CronTab
```

When prompted, select `y` to create both the resource (CRD) and controller. This generates the necessary files under `api/v1/` and `controllers/`.

### Step 2: Define the CRD Schema

Edit `api/v1/crontab_types.go` to define the `CronTab` resource's spec and status:

```go
package v1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// CronTabSpec defines the desired state of CronTab
type CronTabSpec struct {
    CronSpec string `json:"cronSpec"`
    Image    string `json:"image"`
    Replicas int32  `json:"replicas"`
}

// CronTabStatus defines the observed state of CronTab
type CronTabStatus struct {
    ActivePods []string `json:"activePods,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
type CronTab struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    Spec   CronTabSpec   `json:"spec,omitempty"`
    Status CronTabStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true
type CronTabList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items []CronTab `json:"items"`
}

func init() {
    SchemeBuilder.Register(&CronTab{}, &CronTabList{})
}
```

**Explanation**:
- `CronTabSpec`: Defines the desired state with fields for `cronSpec` (cron schedule), `image` (container image), and `replicas` (number of instances).
- `CronTabStatus`: Defines the observed state, such as a list of active Pods.
- Kubebuilder annotations (`//+kubebuilder`) enable features like status subresources.

### Step 3: Generate the CRD Manifest

Generate the CRD manifest based on the schema:

```bash
make manifests
```

This updates the CRD file at `config/crd/bases/stable.example.com_crontabs.yaml`. The generated CRD will look like this:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: crontabs.stable.example.com
spec:
  group: stable.example.com
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                cronSpec:
                  type: string
                image:
                  type: string
                replicas:
                  type: integer
            status:
              type: object
              properties:
                activePods:
                  type: array
                  items:
                    type: string
  scope: Namespaced
  names:
    plural: crontabs
    singular: crontab
    kind: CronTab
    shortNames:
    - ct
```

Apply the CRD to your cluster:

```bash
kubectl apply -f config/crd/bases/stable.example.com_crontabs.yaml
```

Verify the CRD:

```bash
kubectl get crd crontabs.stable.example.com
```

### Step 4: Create a Custom Resource (CR)

Create a sample `CronTab` resource in a file named `my-crontab.yaml`:

```yaml
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: my-new-cron-job
  namespace: default
spec:
  cronSpec: "* * * * */5"
  image: my-cron-image:latest
  replicas: 3
```

**Explanation**:
- This CR defines a `CronTab` named `my-new-cron-job` with a cron schedule (`* * * * */5` for every 5 minutes), a container image, and 3 replicas.

Apply the CR:

```bash
kubectl apply -f my-crontab.yaml
```

Verify the CR:

```bash
kubectl get crontab -n default
```

### Step 5: Implement the Custom Controller

Edit `controllers/crontab_controller.go` to add basic reconciliation logic for the `CronTab` resource:

```go
package controllers

import (
    "context"
    "k8s.io/apimachinery/pkg/runtime"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/log"
    stablev1 "example.com/crontab-operator/api/v1"
)

type CronTabReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=stable.example.com,resources=crontabs,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=stable.example.com,resources=crontabs/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;watch;create;update;patch;delete

func (r *CronTabReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch the CronTab instance
    crontab := &stablev1.CronTab{}
    err := r.Get(ctx, req.NamespacedName, crontab)
    if err != nil {
        log.Error(err, "unable to fetch CronTab")
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Log the CronTab details (extend with real logic, e.g., creating Pods)
    log.Info("Reconciling CronTab", "name", crontab.Name, "replicas", crontab.Spec.Replicas)

    return ctrl.Result{}, nil
}

func (r *CronTabReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&stablev1.CronTab{}).
        Complete(r)
}
```

**Explanation**:
- The controller watches `CronTab` resources and logs their name and replicas.
- RBAC annotations (`//+kubebuilder:rbac`) define the permissions needed for the controller.
- In a production environment, you would extend the `Reconcile` function to create Pods, schedule jobs based on `cronSpec`, or update the CR’s status.

### Step 6: Deploy the Controller

1. Build the controller binary:

```bash
make
```

2. Build and push the Docker image:

```bash
make docker-build docker-push IMG=crontab-operator:latest
```

*Note*: Update `IMG` with your container registry path (e.g., `docker.io/your-username/crontab-operator:latest`).

3. Deploy the controller to the cluster:

```bash
make deploy IMG=crontab-operator:latest
```

Alternatively, run the controller locally for development:

```bash
make install
make run
```

### Step 7: Verify the Setup

1. Verify the CRD:

```bash
kubectl get crd crontabs.stable.example.com
```

2. Verify the CR:

```bash
kubectl get crontab -n default
```

3. Check the controller logs to confirm reconciliation:

```bash
kubectl logs -l control-plane=controller-manager -n crontab-operator-system
```

You should see logs indicating the controller is processing the `my-new-cron-job` resource.

## Usage

### Creating a CronTab

To create a new `CronTab` resource, define a YAML file with the desired configuration. For example, to schedule a daily backup job:

```yaml
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: backup-job
  namespace: default
spec:
  cronSpec: "0 0 * * *" # Run daily at midnight
  image: backup-tool:latest
  replicas: 1
```

Apply it:

```bash
kubectl apply -f backup-job.yaml
```

### Viewing CronTab Resources

List all `CronTab` resources in a namespace:

```bash
kubectl get crontabs -n default
```

Use the short name:

```bash
kubectl get ct -n default
```

### Extending the Controller

The current controller logs `CronTab` details for demonstration purposes. To make it production-ready, extend `controllers/crontab_controller.go` to:
- Create Kubernetes Pods or Jobs based on the `image` and `replicas` fields.
- Use a cron library (e.g., `robfig/cron`) to schedule jobs based on `cronSpec`.
- Update the `status.activePods` field to reflect running Pods.
- Implement error handling, retries, and cleanup for completed jobs.

Example extension ideas:
- Create a Kubernetes Job for each scheduled run based on `cronSpec`.
- Monitor job execution and update the CR’s status with success or failure details.
- Scale Pods dynamically based on the `replicas` field.

## Project Structure

```
crontab-operator/
├── api/
│   └── v1/
│       ├── crontab_types.go       # Defines the CronTab CRD schema
│       └── zz_generated.deepcopy.go
├── controllers/
│   └── crontab_controller.go      # Controller reconciliation logic
├── config/
│   ├── crd/                       # CRD manifests
│   ├── rbac/                      # RBAC permissions for the controller
│   └── samples/                   # Sample CRs (e.g., my-crontab.yaml)
├── main.go                        # Entry point for the controller
└── Makefile                       # Build and deployment scripts
```
## Real-World Use Cases

- **Scheduled Backups**: Manage database or application backups with custom schedules and configurations.
- **Batch Processing**: Run periodic data processing jobs (e.g., ETL pipelines) using custom container images.
- **Monitoring Tasks**: Schedule health checks, log collection, or monitoring scripts across applications.
