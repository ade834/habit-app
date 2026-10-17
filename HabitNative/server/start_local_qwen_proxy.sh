#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
exec python3 local_qwen_proxy.py
