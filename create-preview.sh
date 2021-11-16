#! /bin/bash
# ./create-preview.sh "repo" "1" "busybox:777"
export REPO="$1"
export PR_ID="$2"
export APP_ID="pr-$REPO-$PR_ID"
export FULLY_QUALIFIED_IMAGE="$3"

echo "Creating Argo application definition"
cat <<EOF | tee $PWD/apps/$APP_ID.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_ID
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: previews
  source:
    path: k8s
    repoURL: https://github.com/fgauna12/$REPO.git
    targetRevision: HEAD
    kustomize:
      images:
        - 'weaveworksdemos/front-end=$FULLY_QUALIFIED_IMAGE'
  destination:
    namespace: "$APP_ID"
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
    - CreateNamespace=true
EOF

echo "Creating ingress for the preview environment"

cat << EOF | tee $PWD/apps/$APP_ID-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $APP_ID-ingress
  namespace: $APP_ID
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
spec:
  rules:
  - host: $APP_ID-socks-shop.azure.boxboat.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: front-end
            port:
              number: 80
  tls:
  - hosts:
    - $APP_ID-socks-shop.azure.boxboat.io
    secretName: $APP_ID-socks-shop-tls-secret
EOF