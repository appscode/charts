#!/bin/bash

# Copyright AppsCode Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eou pipefail

SCRIPT_ROOT=$(realpath $(dirname "${BASH_SOURCE[0]}")/..)
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
pushd $SCRIPT_ROOT

# http://redsymbol.net/articles/bash-exit-traps/
function cleanup() {
    popd
}
trap cleanup EXIT

REPO_DIR=stable
[ -d "$REPO_DIR" ] || {
    echo "charts not found"
    exit 0
}

# helm repo index $REPO_DIR/ --url https://charts.appscode.com/$REPO_DIR/

# sync charts
gsutil rsync -d -r $REPO_DIR gs://appscode-charts/$REPO_DIR
gsutil acl ch -u AllUsers:R -r gs://appscode-charts/$REPO_DIR

# invalidate cache
sleep 10
gcloud compute url-maps invalidate-cdn-cache cdn \
    --project appscode-domains \
    --host charts.appscode.com \
    --path "/$REPO_DIR/index.yaml"
