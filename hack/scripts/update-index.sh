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

pushd $SCRIPT_ROOT

# http://redsymbol.net/articles/bash-exit-traps/
function cleanup() {
    popd
}
trap cleanup EXIT

source $SCRIPT_ROOT/hack/scripts/common.sh

CHARTS_DIR=${1:-charts}
TMP_DIR=$SCRIPT_ROOT/tmp

cd $INSTALLER_ROOT

cd $SCRIPT_ROOT
# remove all unstagged changes
git add --all
git stash || true
git stash drop || true
# fetch latest remote
git fetch origin --prune
git gc
# checkout pr branch
if [ -z "$(git ls-remote --heads origin $pr_branch)" ]; then
    # remote branch does NOT exists
    git checkout master
    git branch -D $pr_branch || true
    git checkout -b $pr_branch
else
    git checkout master
    git branch -D $pr_branch || true
    git checkout -b $pr_branch --track origin/$pr_branch
fi
# update index
cd $TMP_DIR
mkdir -p $SCRIPT_ROOT/$REPO_DIR
if [ -f $SCRIPT_ROOT/$REPO_DIR/index.yaml ]; then
    helm repo index --merge $SCRIPT_ROOT/$REPO_DIR/index.yaml --url $REPO_URL $CHARTS_DIR
else
    helm repo index --url $REPO_URL $CHARTS_DIR
fi
mv $CHARTS_DIR/index.yaml $SCRIPT_ROOT/$REPO_DIR/index.yaml
cd $CHARTS_DIR
find . -maxdepth 1 -mindepth 1 -type d -exec mkdir -p $SCRIPT_ROOT/$REPO_DIR/{} \;
find . -path ./$CHARTS_DIR -prune -o -name '*.tgz' -exec mv {} $SCRIPT_ROOT/$REPO_DIR/{} \;
# commit updated index
cd $SCRIPT_ROOT
rm -rf $TMP_DIR
git add --all
git commit -a -s -m "Update index"
git push -u origin HEAD
