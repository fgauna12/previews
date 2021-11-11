# Pre-Requisites

Create the cluster

Install the NGINX Ingress Controller
``` bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

```
helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress
```

```
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Install Argo CD
```
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Enable the Load Balancer svc on the Argo CD instance.

```
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

``` shell
kubectl get svc -n argocd
NAME                                 TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.1.0.101   20.120.122.50   80:31397/TCP,443:30623/TCP   5m6s
```

Do not connect the CLI.

Open your browser to the IP of argo. 

## Define the Argo Apps of Apps

There is an initial set-up. We have to create an ArgoCD project and then set-up an Apps of Apps for the preview environments.

``` bash
kubectl apply -f projects.yaml
kubectl apply -f apps.yaml
```



