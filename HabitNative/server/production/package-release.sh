#!/usr/bin/env bash
# Build the exact, self-contained payload used by maybii-verified.service.
# It deliberately excludes credentials and persistent server state.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
server_dir="$(cd "$script_dir/.." && pwd)"
output_path="${1:-$server_dir/maybii-verified-release.tar.gz}"

if [[ ! -f "$server_dir/local_qwen_proxy.py" ]]; then
  echo "missing required AI proxy: $server_dir/local_qwen_proxy.py" >&2
  exit 1
fi

stage_dir="$(mktemp -d)"
trap 'rm -rf "$stage_dir"' EXIT
mkdir -p "$stage_dir/production"
# Ship only the verified service. Historical Apple-login and anonymous-relay
# prototypes must not enter a release archive by accident.
for file in \
  attest_assertion.py attest_attestation.py attest_challenges.py attest_extensions.py \
  attest_receipt.py attest_registration.py review_authorization.py review_http.py \
  subscription_quota.py subscription_verifier.py trial_quota.py trial_verifier.py \
  verified_runner.py verified-nginx.conf maybii-verified.service production.env.example \
  requirements.txt README.md; do
  cp "$script_dir/$file" "$stage_dir/production/$file"
done
cp "$server_dir/local_qwen_proxy.py" "$stage_dir/local_qwen_proxy.py"

tar -C "$stage_dir" -czf "$output_path" production local_qwen_proxy.py
tar -tzf "$output_path" | grep -qx 'local_qwen_proxy.py'
tar -tzf "$output_path" | grep -qx 'production/verified_runner.py'
printf 'release archive: %s\n' "$output_path"
shasum -a 256 "$output_path"
