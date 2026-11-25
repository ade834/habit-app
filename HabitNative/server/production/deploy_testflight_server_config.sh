#!/usr/bin/env bash
# Configure server environment for TestFlight validation
set -euo pipefail

ENV_FILE="/etc/maybii-review/production.env"

echo "[1/3] Updating $ENV_FILE for TestFlight..."

cat <<'EOF' > "$ENV_FILE"
# TestFlight uses StoreKit sandbox + App Attest production
MAYBII_APPLE_ENV=sandbox
MAYBII_ATTEST_ENV=production
MAYBII_APPLE_TEAM_ID=YD654LRZQB
MAYBII_APPSTORE_KEY_ID=7V96L7F8ZS
MAYBII_APPSTORE_ISSUER_ID=793fe062-0580-462b-bc27-4e07a87af541
MAYBII_APP_APPLE_ID=6830592462
MAYBII_ATTEST_CATEGORIES=1,2,3,4
MAYBII_ATTEST_VERSIONS=1,2,3,4
MAYBII_BIND_PORT=8769
EOF

echo "[2/3] Checking permissions..."
chmod 600 "$ENV_FILE"

echo "[3/3] Restarting service..."
systemctl restart maybii-verified.service
systemctl status maybii-verified.service --no-pager

echo "=== Server configuration complete for TestFlight ==="
