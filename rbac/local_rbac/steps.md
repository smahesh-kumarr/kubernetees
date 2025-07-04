#Step: 1 Create Two namespace 

``sh
kubectl create namespace dev
kubectl creae namespace prod
kubectl get namespace
``

#Step: 2 Create the nginx_deployment_with dev and prod

``sh
nano dev_nginx_deployment.yml
nano prod_nginx_deployment.yml
``

#Step: 3 Apply the yml files 

``sh
kubectl apply -f dev_nginx_deployment.yml
kubectl apply -f prod_nginx_deployment.yml
``

#Step4: Verify the pods and Delpoyment with respective namespaces

``sh
kubectl get deployments -n dev
kubectl get pods -n dev
kubectl get deployments -n prod
kubectl get pods -n prod
``

#Step5: Create devuser with Namespace-Scoped RBAC

### We’ll create a Kubernetes user devuser using client certificates
### and grant access to the dev namespace with a Role and RoleBinding 
### for get, list, watch, and create permissions on pods, deployments

# Step-I: Generate a private key

``sh
openssl genrsa -out devuser.key 2048
``

# Step-II: Create a Certificate Signing Request (CSR)

``sh
openssl req -new -key devuser.key -out devuser.csr -subj "/CN=devuser/O=devgroup"
``

# Step-III: Create a CSR YAML for Kubernetes:

``sh
nano devuser-csr.yaml
``

# Step-IV: Replace <base64-encoded-csr> with the base64-encoded CSR

``sh
cat devuser.csr | base64 | tr -d '\n'
``

#Step-V: Apply and approve the CSR

``sh
kubectl apply -f devuser-csr.yaml
kubectl certificate approve devuser
``

#Step-VI: Retrieve the signed certificate:

``sh
kubectl get csr devuser -o jsonpath='{.status.certificate}' | base64 --decode > devuser.crt
``

#Step-VII: Create kubeconfig for devuser:

``sh 
kubectl config set-credentials devuser --client-certificate=devuser.crt --client-key=devuser.key
kubectl config get-clusters
kubectl config set-context devuser-context --cluster=<cluster-name> --user=devuser --namespace=dev
``

#Step6: Create RBAC Role for devuser

``sh
nano dev-role.yaml
kubectl apply -f dev-role.yaml
``

#Step7: Create RoleBinding for devuser

``sh
nano dev-rolebinding.yaml
kubectl apply -f dev-rolebinding.yaml
``

#Step8: Switch to devuser context

``sh
kubectl config get-contexts
kubectl config use-context devuser-context
``

#---------------------------------------------------------------------------------------#

# From Step:5 follow the steps for task 2

# Create produser with Cluster-Wide RBAC
#We’ll create a Kubernetes user produser and grant cluster-wide access 
#to pods with get, list, create, and delete permissions.

