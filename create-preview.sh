#! /bin/bash
# ./create-preview "repo" "1" "busybox:777"
export REPO="$1"
export PR_ID="$2"
export APP_ID="pr-$REPO-$PR_ID"
export FULLY_QUALIFIED_IMAGE="$3"

cat <<EOF | tee $PWD/apps/templates/$APP_ID.yaml
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
        - 'ghcr.io/fgauna12/front-end=$FULLY_QUALIFIED_IMAGE'
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
git push
