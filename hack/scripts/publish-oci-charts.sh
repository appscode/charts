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

SCRIPT_ROOT=$(realpath $(dirname "${BASH_SOURCE[0]}")/../..)
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
if [ $# -gt 0 ]; then
    SCRIPT_ROOT=${1}
fi

pushd $SCRIPT_ROOT

# http://redsymbol.net/articles/bash-exit-traps/
function cleanup() {
    rm -rf $SCRIPT_ROOT/.oci
    popd
}
trap cleanup EXIT

CHARTS_DIR=${2:-charts}

REGISTRY_0=${REGISTRY_0:-}
REGISTRY_1=${REGISTRY_1:-}
REGISTRY_2=${REGISTRY_2:-}

mkdir -p $SCRIPT_ROOT/.oci
cd $SCRIPT_ROOT/.oci

if [ $# -gt 2 ]; then
    # Loop over the chart names provided as arguments
    for chart in "${@:3}"; do
        if [ -d "$SCRIPT_ROOT/$CHARTS_DIR/$chart" ]; then
            helm package "$SCRIPT_ROOT/$CHARTS_DIR/$chart"
        fi
    done
else
    # Loop over all charts
    for file in $SCRIPT_ROOT/$CHARTS_DIR/*; do
        if [ -d "$file" ]; then
            helm package "$file"
        fi
    done
fi

for file in $SCRIPT_ROOT/.oci/*; do
    if [ -n "$REGISTRY_0" ]; then
        helm push "$file" "$REGISTRY_0"
    fi
    if [ -n "$REGISTRY_1" ]; then
        helm push "$file" "$REGISTRY_1"
    fi
    if [ -n "$REGISTRY_2" ]; then
        helm push "$file" "$REGISTRY_2"
    fi
done
