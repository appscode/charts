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

if [ -z "$1" ]; then
    echo "Missing argument for instller directory."
    echo "Correct usage: $SCRIPT_NAME <path_to_installer_repo> <charts_dir, defaults to charts>."
    exit 1
fi

INSTALLER_ROOT=$1
CHARTS_DIR=${2:-charts}

cd $INSTALLER_ROOT

GIT_TAG=${GITHUB_REF#'refs/tags/'}
PRODUCT_LINE=${PRODUCT_LINE:-}
RELEASE=${RELEASE:-}
RELEASE_TRACKER=${RELEASE_TRACKER:-}

while IFS=$': \r\t' read -r -u9 marker v; do
    case $marker in
        ProductLine)
            PRODUCT_LINE=$(echo $v | tr -d '\r\t')
            ;;
        Release)
            RELEASE=$(echo $v | tr -d '\r\t')
            ;;
        Release-tracker)
            RELEASE_TRACKER=$(echo $v | tr -d '\r\t')
            ;;
    esac
done 9< <(git tag -l --format='%(body)' $GIT_TAG)

pr_branch=${GITHUB_REPOSITORY}@${GIT_TAG}
if [ ! -z "$PRODUCT_LINE" ] && [ ! -z "$RELEASE" ]; then
    pr_branch=${PRODUCT_LINE}@${RELEASE}
fi

while true; do
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
    # package charts
    cd $INSTALLER_ROOT
    find $CHARTS_DIR -maxdepth 1 -mindepth 1 -type d -exec helm package {} -d {} \;
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
    # open pr
    cd $SCRIPT_ROOT
    git add --all
    # generate commit command
    ct_cmd="git commit -a -s -m \"Publish ${GITHUB_REPOSITORY}@${GIT_TAG} charts\""
    ct_cmd="$ct_cmd --message \"ProductLine: $PRODUCT_LINE\""
    if [ ! -z "$RELEASE" ]; then
        ct_cmd="$ct_cmd --message \"Release: $RELEASE\""
    fi
    if [ ! -z "$RELEASE_TRACKER" ]; then
        ct_cmd="$ct_cmd --message \"Release-tracker: $RELEASE_TRACKER\""
    fi
    # commit
    eval "$ct_cmd"
    # push successfully or { sleep and retry)
    git push -u origin HEAD || {
        sleep $((1 + RANDOM % 10))
        continue
    }
    #  open pr
    pr_cmd=$(
        cat <<EOF
hub pull-request \
    --message "Publish $pr_branch charts" \
    --message "$(git show -s --format=%b)"
EOF
    )
    # if no Release-tracker: auto merge.
    if [ -z "$RELEASE_TRACKER" ]; then
        pr_cmd="$pr_cmd --labels automerge"
    fi
    eval "$pr_cmd" || true
    # if Release-tracker: found, report back.
    if [ ! -z "$RELEASE_TRACKER" ]; then
        parse_url $RELEASE_TRACKER
        api_url="repos/${RELEASE_TRACKER_OWNER}/${RELEASE_TRACKER_REPO}/issues/${RELEASE_TRACKER_PR}/comments"
        msg="/chart github.com/${GITHUB_REPOSITORY} ${GIT_TAG}"
        hub api "$api_url" -f body="$msg"
    fi
    exit 0
done
