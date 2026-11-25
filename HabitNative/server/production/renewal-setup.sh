#!/bin/sh
# Run only AFTER the ECS RAM role is attached and DNS hooks are deployed.
set -eu
certbot reconfigure --cert-name api.ddream.top --manual --preferred-challenges dns \
  --manual-auth-hook '/opt/maybii-acme/bin/python /opt/maybii-review/dns_hook.py auth' \
  --manual-cleanup-hook '/opt/maybii-acme/bin/python /opt/maybii-review/dns_hook.py cleanup' \
  --deploy-hook 'nginx -t && systemctl reload nginx' --non-interactive
certbot renew --cert-name api.ddream.top --dry-run --non-interactive
systemctl enable --now certbot.timer
