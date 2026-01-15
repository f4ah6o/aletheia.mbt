#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

moon run src/aletheia -- generate ./src
moon info
moon fmt
