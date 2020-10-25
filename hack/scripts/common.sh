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

CLOUDFLARE_ZONE_ID=092ef15f721929a515232abd079f128b

BUCKET=${BUCKET:-charts.appscode.com}

REPO_DOMAIN=${REPO_DOMAIN:-charts.appscode.com}
REPO_DIR=${REPO_DIR:-stable}
REPO_URL=https://${REPO_DOMAIN}/${REPO_DIR}/

# ref: https://gist.github.com/joshisa/297b0bc1ec0dcdda0d1625029711fa24
parse_url() {
    proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    # remove the protocol
    url="$(echo ${1/$proto/})"

    IFS='/'                  # / is set as delimiter
    read -ra PARTS <<<"$url" # str is read into an array as tokens separated by IFS
    if [ ${PARTS[0]} != 'github.com' ] || [ ${#PARTS[@]} -ne 5 ]; then
        echo "failed to parse relase-tracker: $url"
        exit 1
    fi
    export RELEASE_TRACKER_OWNER=${PARTS[1]}
    export RELEASE_TRACKER_REPO=${PARTS[2]}
    export RELEASE_TRACKER_PR=${PARTS[4]}
}
