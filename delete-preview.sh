#! /bin/bash
# ./delete-preview.sh "repo" "1" 
export REPO="$1"
export PR_ID="$2"
export APP_ID="pr-$REPO-$PR_ID"

echo "Removing preview environment"
rm $PWD/apps/$APP_ID.yaml
