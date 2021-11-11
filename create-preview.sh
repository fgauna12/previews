#! /bin/bash
# ./create-preview "20.120.122.50" "repo" "1" "busybox:777"
export INGRESS_HOST="$1"
export REPO="$2"
export PR_ID="$3"
export APP_ID="pr-$REPO-$PR_ID"
export FULLY_QUALIFIED_IMAGE="$4"
export HOSTNAME="$APP_ID.$INGRESS_HOST.nip.io"

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
    path: helm
    repoURL: https://github.com/fgauna12/$REPO.git
    targetRevision: HEAD
    helm:
      values: |
        image:
          tag: "$FULLY_QUALIFIED_IMAGE"
        ingress:
          host: "$HOSTNAME"
      version: v3
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

git add .
git commit -m "Adding environment for PR $PR_ID"

echo "Your environment is accessible at $HOSTNAME"