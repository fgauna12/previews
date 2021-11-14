# Pre-Requisites

Create the cluster

``` bash
chmod +x ./create-vanilla-cluster.sh
./create-vanilla-cluster "aks-socks-001" "rg-socks-001"
```

## NGINX Ingress Controller with Let's Encrypt
Inspired by [this doc](https://docs.microsoft.com/en-us/azure/aks/ingress-tls)

Install the NGINX Ingress Controller with Let's Encrypt.
``` bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

```
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress --create-namespace\
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux 
```

Ge the public IP of the Ingress load balancer. 

``` shell
kubectl get svc -n ingress
NAME                                               TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)                      AGE
nginx-ingress-ingress-nginx-controller             LoadBalancer   10.1.0.225   20.81.13.40   80:31258/TCP,443:30489/TCP   6m59s
```

Create a DNS record that points to the Public IP of the NGINX ingress controller.

### Install Cert Manager

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart

``` bash
CERT_MANAGER_TAG=v1.3.1

# Label the ingress-basic namespace to disable resource validation
kubectl label namespace ingress cert-manager.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
  --namespace ingress \
  --version $CERT_MANAGER_TAG \
  --set installCRDs=true \
  --set nodeSelector."kubernetes\.io/os"=linux 

```

Create a CA cluster issuer

``` bash
cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: facundo@boxboat.com
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF
```

Deploy a test application to validate that ingress works.

``` bash
# Set your custom domain
export DOMAIN_NAME="socks.azure.boxboat.io"

# Create a namespace to place your test application
kubectl create ns ingress-test

# Deploy the first test application
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld
  namespace: ingress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld
  template:
    metadata:
      labels:
        app: aks-helloworld
    spec:
      containers:
      - name: aks-helloworld
        image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "Welcome to Azure Kubernetes Service (AKS)"
---
apiVersion: v1
kind: Service
metadata:
  name: aks-helloworld
  namespace: ingress-test
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: aks-helloworld
EOF

# Deploy the second test application
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-demo
  namespace: ingress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ingress-demo
  template:
    metadata:
      labels:
        app: ingress-demo
    spec:
      containers:
      - name: ingress-demo
        image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "AKS Ingress Demo"
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-demo
  namespace: ingress-test
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: ingress-demo
EOF

# Deploy the ingress routes
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  namespace: ingress-test
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - $DOMAIN_NAME
    secretName: tls-secret
  rules:
  - host: $DOMAIN_NAME
    http:
      paths:
      - path: /hello-world-one(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld
            port:
              number: 80
      - path: /hello-world-two(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: ingress-demo
            port:
              number: 80
      - path: /(.*)
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld
            port:
              number: 80
EOF
```

Once everything works, then delete the namespace.

``` bash
kubectl delete ns ingress-test
```

## Install Argo CD
```
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Deploy ingress rules. Make sure you that add an A record on your DNS to the ingress controller service again.

``` bash
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    # If you encounter a redirect loop or are getting a 307 response code 
    # then you need to force the nginx ingress to connect to the backend using HTTPS.
    #
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: argocd.azure.boxboat.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: 
            name: argocd-server
            port:
              name: https
  tls:
  - hosts:
    - argocd.azure.boxboat.io
    secretName: argocd-secret # do not change, this is provided by Argo CD
EOF
```

Open your browser to the IP of argo. 

Get the initial password. 

``` bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Login to Argo. Then change the default password.

## Define the Argo Apps of Apps

There is an initial set-up. We have to create an ArgoCD project and then set-up an Apps of Apps for the preview environments.

``` bash
kubectl apply -f projects.yaml
kubectl apply -f apps.yaml
```



