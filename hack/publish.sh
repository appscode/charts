#!/bin/bash
set -xeou pipefail

GOPATH=$(go env GOPATH)
REPO_ROOT="$GOPATH/src/github.com/appscode/charts"

pushd $REPO_ROOT

helm repo index stable/ --url https://charts.appscode.com/stable/

gsutil rsync -d -r stable gs://appscode-charts/stable
gsutil acl ch -u AllUsers:R -r gs://appscode-charts/stable

popd
