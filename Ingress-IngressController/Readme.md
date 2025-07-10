# Flask App on Kubernetes with MetalLB and NGINX Ingress Controller

This project deploys a Python Flask web application in a local single-node Kubernetes cluster (set up with `kubeadm` and Calico CNI). The app has two routes (`/hello` and `/greet`), exposed via an NGINX Ingress Controller with path-based routing (`myapp.local/hello` and `myapp.local/greet`). MetalLB provides a virtual IP for external access, mimicking a cloud load balancer. This README documents the setup process and instructions to replicate it.

## Prerequisites

- **Single-node Kubernetes cluster**:
  - Set up with `kubeadm`.
  - Calico CNI installed for pod networking.
- **Docker**: Installed on the machine to build the Flask app image.
- **kubectl**: Configured to interact with the cluster.
- **Local network**: A range of unused IPs (e.g., `192.168.1.200-192.168.1.250`) for MetalLB.
- **Access to edit `/etc/hosts`** on the machine used to test the app.

## Setup Overview

1. **Flask App**: A Python Flask app with routes `/hello` ("Hello, World!") and `/greet` ("Greetings from Flask!").
2. **Docker Image**: Built and loaded into the cluster's Docker daemon.
3. **Kubernetes Deployment**: Runs two replicas of the Flask app.
4. **ClusterIP Service**: Exposes the Flask app internally for Ingress routing.
5. **MetalLB**: Provides a virtual IP for external access to the NGINX Ingress Controller.
6. **NGINX Ingress Controller**: Routes HTTP traffic based on Ingress rules.
7. **Ingress Resource**: Defines path-based routing for `myapp.local/hello` and `myapp.local/greet`.
8. **Local DNS**: Maps `myapp.local` to the MetalLB virtual IP via `/etc/hosts`.

## Step-by-Step Setup

### 1. Create the Flask App
The Flask app is a simple web server with two routes.

**Files**:
- `app.py`: Defines the Flask app with `/hello` and `/greet` routes.
- `requirements.txt`: Lists dependencies (`Flask==2.3.3`).
- `Dockerfile`: Builds the Docker image for the app.

**app.py**:
```python
from flask import Flask

app = Flask(__name__)

@app.route('/hello')
def hello():
    return 'Hello, World!'

@app.route('/greet')
def greet():
    return 'Greetings from Flask!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**requirements.txt**:
```
Flask==2.3.3
```

**Dockerfile**:
```
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
```

**Steps**:
1. Create a directory `flask-app` and add the above files.
2. Build the Docker image:
   ```bash
   cd flask-app
   docker build -t my-flask-app:latest .
   ```
3. Save and load the image into the cluster's Docker daemon:
   ```bash
   docker save -o my-flask-app.tar my-flask-app:latest
   docker load -i my-flask-app.tar
   ```

### 2. Deploy the Flask App to Kubernetes
The app is deployed as a Kubernetes Deployment with a ClusterIP Service for internal access.

**Deployment (`flask-deployment.yaml`)**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  namespace: flask-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-app
        image: my-flask-app:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
```

**Service (`flask-service.yaml`)**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-app-service
  namespace: flask-app
spec:
  selector:
    app: flask-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
  type: ClusterIP
```

**Steps**:
1. Create the namespace:
   ```bash
   kubectl create namespace flask-app
   ```
2. Apply the manifests:
   ```bash
   kubectl apply -f flask-deployment.yaml
   kubectl apply -f flask-service.yaml
   ```
3. Verify:
   ```bash
   kubectl get pods -n flask-app
   kubectl get svc -n flask-app
   ```

### 3. Install MetalLB
MetalLB provides a virtual IP (VIP) for LoadBalancer Services in a bare-metal cluster.

**Steps**:
1. Deploy MetalLB:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
   ```
2. Create an IP address pool (`metallb-config.yaml`):
   ```yaml
   apiVersion: metallb.io/v1beta1
   kind: IPAddressPool
   metadata:
     name: first-pool
     namespace: metallb-system
   spec:
     addresses:
     - 192.168.1.200-192.168.1.250
     autoAssign: true
   ---
   apiVersion: metallb.io/v1beta1
   kind: L2Advertisement
   metadata:
     name: default
     namespace: metallb-system
   spec:
     ipAddressPools:
     - first-pool
   ```
3. Apply the configuration:
   ```bash
   kubectl apply -f metallb-config.yaml
   ```
4. Verify MetalLB pods:
   ```bash
   kubectl get pods -n metallb-system
   ```

**What MetalLB Does**:
- Assigns a VIP (e.g., `192.168.1.200`) from the IP pool to LoadBalancer Services.
- Uses Layer 2 (ARP) to advertise the VIP to the local network, routing traffic to the Kubernetes node.
- Mimics cloud load balancers in a bare-metal environment.

### 4. Install NGINX Ingress Controller
The NGINX Ingress Controller routes HTTP traffic based on Ingress rules.

**Steps**:
1. Deploy the NGINX Ingress Controller:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
   ```
2. Modify the Service to use LoadBalancer (for MetalLB):
   ```bash
   kubectl edit svc ingress-nginx-controller -n ingress-nginx
   ```
   Change `type: NodePort` to `type: LoadBalancer`.
   Alternatively, apply a custom Service (`ingress-service.yaml`):
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: ingress-nginx-controller
     namespace: ingress-nginx
   spec:
     type: LoadBalancer
     ports:
     - name: http
       port: 80
       targetPort: 80
       protocol: TCP
     - name: https
       port: 443
       targetPort: 443
       protocol: TCP
     selector:
       app.kubernetes.io/name: ingress-nginx
       app.kubernetes.io/instance: ingress-nginx
       app.kubernetes.io/component: controller
   ```
   ```bash
   kubectl apply -f ingress-service.yaml
   ```
3. Verify the Service and VIP:
   ```bash
   kubectl get svc -n ingress-nginx
   ```
   Note the `EXTERNAL-IP` (e.g., `192.168.1.200`).

**Role of NGINX Ingress Controller**:
- Runs NGINX as a reverse proxy to route HTTP traffic.
- Reads Ingress resources to configure routing rules (e.g., `myapp.local/hello` to `flask-app-service`).
- Handles path-based routing, load balancing, and optional SSL termination.

### 5. Create the Ingress Resource
The Ingress defines path-based routing rules for the Flask app.

**Ingress (`flask-ingress.yaml`)**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress
  namespace: flask-app
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /hello
        pathType: Prefix
        backend:
          service:
            name: flask-app-service
            port:
              number: 80
      - path: /greet
        pathType: Prefix
        backend:
          service:
            name: flask-app-service
            port:
              number: 80
```

**Steps**:
1. Apply the Ingress:
   ```bash
   kubectl apply -f flask-ingress.yaml
   ```
2. Verify:
   ```bash
   kubectl get ingress -n flask-app
   kubectl describe ingress flask-ingress -n flask-app
   ```

**Routing Rules**:
- Routes `myapp.local/hello` to `flask-app-service` (port 80), which forwards to Flask app pods (port 5000).
- Routes `myapp.local/greet` to the same Service for the `/greet` path.

### 6. Configure Local DNS
Map `myapp.local` to the MetalLB VIP.

**Steps**:
1. Get the LoadBalancer IP:
   ```bash
   kubectl get svc -n ingress-nginx
   ```
   Note the `EXTERNAL-IP` (e.g., `192.168.1.200`).
2. Edit `/etc/hosts`:
   ```bash
   sudo nano /etc/hosts
   ```
   Add:
   ```
   192.168.1.200 myapp.local
   ```

### 7. Test the Setup
**Steps**:
1. Test with `curl`:
   ```bash
   curl http://myapp.local/hello
   curl http://myapp.local/greet
   ```
   Expected output:
   - `/hello`: "Hello, World!"
   - `/greet`: "Greetings from Flask!"
2. Test in a browser:
   Visit `http://myapp.local/hello` and `http://myapp.local/greet`.
3. Ping the domain:
   ```bash
   ping myapp.local
   ```
   Should resolve to `192.168.1.200`.

## Troubleshooting
- **Flask App Issues**:
  ```bash
  kubectl logs -n flask-app -l app=flask-app
  kubectl port-forward svc/flask-app-service -n flask-app 8080:80
  ```
  Test: `http://localhost:8080/hello`.
- **MetalLB Issues**:
  ```bash
  kubectl get pods -n metallb-system
  kubectl get ipaddresspool -n metallb-system
  ```
  Ensure the IP pool is valid and doesn’t overlap with your network.
- **NGINX Ingress Issues**:
  ```bash
  kubectl get pods -n ingress-nginx
  kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
  ```
- **Webhook Errors**:
  If `failed calling webhook` occurs:
  ```bash
  kubectl get svc -n ingress-nginx
  kubectl describe validatingwebhookconfigurations ingress-nginx-admission
  ```
  Temporarily disable webhook (non-production):
  ```bash
  kubectl delete validatingwebhookconfigurations ingress-nginx-admission
  ```
- **Calico Issues**:
  ```bash
  kubectl get pods -n kube-system -l k8s-app=calico-node
  ```
  Check for network policy conflicts.

## Notes
- The `ClusterIP` Service (`flask-app-service`) enables internal communication between the NGINX Ingress Controller and Flask app pods.
- The `LoadBalancer` Service (`ingress-nginx-controller`) uses MetalLB to provide a virtual IP for external access.
- The Ingress resource defines path-based routing, allowing multiple routes (`/hello`, `/greet`) under one domain (`myapp.local`).

## Next Steps
- Add SSL with a self-signed certificate for HTTPS.
- Deploy a second Flask app with a new path (e.g., `/welcome`).
- Use Calico network policies to restrict traffic.
