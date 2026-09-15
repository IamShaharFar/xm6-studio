#!/bin/bash
set -euo pipefail
project_path="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_path"
export CLANG_MODULE_CACHE_PATH="$project_path/.build/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_path/.build/modules"
swift test --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
