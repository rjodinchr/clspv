#!/usr/bin/bash

set -x

SCRIPT_DIR="$(dirname $(realpath "${BASH_SOURCE[0]}"))"
source "${SCRIPT_DIR}/make_artifact_functions.sh"
make_native "Linux-X64" clang++ clang "CREATE_ZIP" "strip"
