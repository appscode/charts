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

function publish_dir() {
    repo_dir=$1

    [ -d "$repo_dir" ] || {
        echo "charts not found"
        return 0
    }

    # helm repo index $repo_dir/ --url https://${REPO_DOMAIN}/$repo_dir/

    # sync charts
    # https://stackoverflow.com/a/38466192
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control
    gsutil -m -h "Cache-Control:public, max-age=600" rsync -a public-read -d -r $repo_dir gs://${BUCKET}/$repo_dir
    # gsutil -m acl ch -u AllUsers:R -r gs://${BUCKET}/$repo_dir

    # invalidate cache
    # ref: https://api.cloudflare.com/#zone-purge-files-by-url
    if [ ! -z "$CLOUDFLARE_ZONE_ID" ]; then
        sleep 5
        index_url="https://${REPO_DOMAIN}/${repo_dir}/index.yaml"
        echo "purging $index_url"
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache" \
            -H "Authorization: Bearer ${CLOUDFLARE_TOKEN}" \
            -H "Content-Type: application/json" \
            --data '{"files":["'${index_url}'"]}'
        # recommended by Cloudflare for purging to take effect
        sleep 30
    fi
}

for repo_dir in stable testing; do
    publish_dir $repo_dir
done

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
done 9< <(git show -s --format=%b)

[ ! -z "$RELEASE_TRACKER" ] || {
    echo "Release-tracker url not found."
    exit 0
}

parse_url $RELEASE_TRACKER
api_url="repos/${RELEASE_TRACKER_OWNER}/${RELEASE_TRACKER_REPO}/issues/${RELEASE_TRACKER_PR}/comments"
msg="/chart-published github.com/${GITHUB_REPOSITORY}"
hub api "$api_url" -f body="$msg"
