#! /bin/bash
# ./delete-preview.sh "repo" "1" 
export REPO="$1"
export PR_ID="$2"
export APP_ID="pr-$REPO-$PR_ID"

ENVIRONMENT_FILE="$PWD/apps/$APP_ID.yaml"
INGRESS_FILE="$PWD/apps/$APP_ID-ingress.yaml"
echo "Removing preview environment $ENVIRONMENT_FILE"
rm $ENVIRONMENT_FILE
rm $INGRESS_FILE
