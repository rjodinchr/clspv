#!/usr/bin/bash

set -x

SCRIPT_DIR="$(dirname $(realpath "${BASH_SOURCE[0]}"))"
source "${SCRIPT_DIR}/make_artifact_functions.sh"
make_android_from_linux arm64-v8a "aarch64-linux-gnu-strip"
