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

SCRIPT_ROOT=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
DEFAULT_CHARTS_DIR="${SCRIPT_ROOT}/charts"
CHARTS_DIR="${CHARTS_DIR:-$DEFAULT_CHARTS_DIR}"
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

function usage() {
    cat <<EOF
Usage:
    ${SCRIPT_NAME} --charts-dir <path> --all
    ${SCRIPT_NAME} --charts-dir <path> <chart-name> [<chart-name> ...]
    CHARTS_DIR=<path> ${SCRIPT_NAME} --all

Behavior:
  1. If chart names are provided, delete chart directories not in that list.
  2. If --all is used, keep all chart directories.
  3. For each remaining chart, strip a leading 'v' from version/appVersion
     values in Chart.yaml.
    4. charts directory can be passed via --charts-dir or CHARTS_DIR env var.
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

declare -a selected_charts=()
all_mode=false

function contains_chart() {
    local target="$1"
    shift
    local item
    for item in "$@"; do
        if [[ "$item" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --charts-dir)
            if [[ $# -lt 2 ]]; then
                echo "error: --charts-dir requires a path" >&2
                usage
                exit 1
            fi
            CHARTS_DIR="$2"
            shift 2
            ;;
        --all)
            all_mode=true
            shift
            ;;
        --*)
            echo "error: unknown flag: $1" >&2
            usage
            exit 1
            ;;
        *)
            selected_charts+=("$1")
            shift
            ;;
    esac
done

if [[ "$all_mode" == true && ${#selected_charts[@]} -gt 0 ]]; then
    echo "error: --all cannot be combined with chart names" >&2
    usage
    exit 1
fi

if [[ "$all_mode" == false && ${#selected_charts[@]} -eq 0 ]]; then
    echo "error: provide chart names or use --all" >&2
    usage
    exit 1
fi

if [[ ! -d "$CHARTS_DIR" ]]; then
    echo "error: charts directory not found: $CHARTS_DIR" >&2
    exit 1
fi

shopt -s nullglob
for chart_path in "${CHARTS_DIR}"/*; do
    [[ -d "$chart_path" ]] || continue
    chart_name=$(basename "$chart_path")

    if [[ "$all_mode" == false ]]; then
        if ! contains_chart "$chart_name" "${selected_charts[@]}"; then
            echo "Deleting chart: $chart_name"
            rm -rf "$chart_path"
            continue
        fi
    fi

    chart_yaml="${chart_path}/Chart.yaml"
    if [[ ! -f "$chart_yaml" ]]; then
        echo "Skipping chart without Chart.yaml: $chart_name"
        continue
    fi

    # Strip only a leading 'v' from version/appVersion values.
    sed -E -i.bak \
        -e 's/^(version:[[:space:]]*"?)v([^"[:space:]#]+)("?[[:space:]]*(#.*)?)$/\1\2\3/' \
        -e 's/^(appVersion:[[:space:]]*"?)v([^"[:space:]#]+)("?[[:space:]]*(#.*)?)$/\1\2\3/' \
        "$chart_yaml"
    rm -f "${chart_yaml}.bak"
    echo "Updated chart metadata: $chart_name"
done
