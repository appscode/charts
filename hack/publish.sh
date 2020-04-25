#!/bin/bash
set -xeou pipefail

REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")/..

pushd $REPO_ROOT

helm repo index stable/ --url https://charts.appscode.com/stable/

gsutil rsync -d -r stable gs://appscode-charts/stable
gsutil acl ch -u AllUsers:R -r gs://appscode-charts/stable

sleep 10

gcloud compute url-maps invalidate-cdn-cache cdn \
  --project appscode-domains \
  --host charts.appscode.com \
  --path "/stable/index.yaml"

popd
