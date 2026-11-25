# Production preparation — 2026-11-04

## Current status — 2026-11-09

The verified sandbox service is running only on the server's loopback interface;
the public production API is not enabled. `verified_runner.py` now uses bounded
workers so a long model request does not block unrelated challenges. The local
test suite covers 32 checks, including concurrency and overload cases; this does not
establish real Apple entitlement verification. The revised nginx template routes
attestation challenge/registration, trial reset and review paths, but has not
been installed or tested with nginx on the server. `maybii-verified.service` is
an uninstalled deployment template; the older `maybii-review.service` starts a
different, historical runner and must not be used for the verified endpoint.
The production StoreKit/App Attest flow, valid production credentials and
certificate renewal still need real verification before public release.
The free-trial reservation no longer imposes a three-attempt daily cap: a
successful trial is consumed once, a failed attempt may be retried, and a
verified local-data reset permits another trial. The sandbox service deployed
before this change still runs the older code and must be updated and retested.
The current verified runner also removes the extra three-per-day subscription
limit to preserve the app's per-report cooldown rules. The backend still
requires a valid current Apple entitlement and App Attest proof; the ingress
template retains short-term request-rate controls. An authentic subscription
transaction must contain an app-transaction identifier matching the separately
verified app proof. Missing or mismatched identifiers fail closed; compatibility
with real sandbox purchases and Family Sharing needs device verification.

On 2026-11-09 a development-signed iPad generated a real Apple App Attest
attestation, receipt and assertion. Local verification accepted the Apple
certificate chain, receipt and assertion, and rejected replay. The AppTransaction
in that run was Xcode-signed rather than Apple sandbox-signed, so the app-proof
verifier was explicitly mocked for the combined registration/assertion test;
this is not an end-to-end authorization test. The raw test fixture was removed
from both the device and local machine. Testing exposed and fixed the actual
four-byte validation-category encoding, raw receipt text fields, assertion flags
and ECDSA verification behavior. A true sandbox transaction and an end-to-end
HTTP request are still required.

The early sections below describe superseded preparation. The latest decisions
and current release blockers are in the 2026-11-06 sections at the end.

## Verified server state

Certificate is installed. Nginx listens ONLY on 127.0.0.1:8443 and returns 503.
TLS verification via curl returned 0 (valid). Existing private proxy stays on 8765.
ECS role metadata endpoint returned 404. Automatic renewal is NOT enabled.

## Local implementation (not deployed)

- access.py: individually issued random bearer tokens, SHA256 hashes only in SQLite.
- Default allocation: 10 attempts per user per China calendar day; administrator can change it.
- Failed upstream requests consume quota too, to put a hard bound on paid attempts.
- Atomic SQLite reservations survive restart and prevent concurrent overuse.
- runner.py: requires token before calling Qwen, upstream on loopback 8766.
- nginx.conf: per-IP request/concurrency controls; keep loopback until deployment checks pass.
- Build deployment archives with `./package-release.sh /path/to/release.tar.gz`.
  The archive includes `local_qwen_proxy.py` at its required top-level path, so it
  must never be copied from an unrelated staging deployment.
- This is invitation-token access control, NOT Apple account login or verified real-world identity.
- Credential enrollment/login UI is still required. Release App currently reads a per-user token
  from Keychain service com.deshiru.habitnative.review-access, account user-token.
  No token is shipped; missing token fails locally before sending reflection data.

## DNS renewal prerequisites

Review dns-role-policy.json and attach an ECS RAM role with this domain-scoped policy.
It permits changes to ddream.top records; API policy granularity must be reviewed before use.
Install official Alibaba SDK packages in /opt/maybii-acme virtualenv:
  alibabacloud_alidns20150109 alibabacloud_credentials alibabacloud_tea_openapi
Deploy dns_hook.py. Run renewal-setup.sh only after role credentials work.
The script reconfigures Certbot, tests renewal, then enables the timer.
Do not report automatic renewal working until the full dry-run passes.

## Remaining release gates

Deploy authenticated backend and test 401, 429 and valid requests through HTTPS.
Complete credential issuance/enrollment flow. Confirm filing/public access state.
Enable public TLS only after these pass. Check signed device Archive/IPA separately.

## Apple login preparation — 2026-11-04

Implemented: server-issued 5-minute one-time nonce challenge; Apple JWKS RS256 signature,
issuer, audience, expiry and nonce validation; 7-day opaque server sessions stored as
hashes; server quota survives re-login. Invalid/replayed challenges fail closed.
Client: native Apple sign-in sheet, state/nonce binding, HTTPS exchange, device-only Keychain.
No email or full name requested. Missing session opens login from review generation.

Still pending: deployment, enabling Sign in with Apple for the paid account's App ID,
merging apple-signin-entitlement.plist into the actual signing entitlements once ready,
and real Apple integration testing. Do not enable public service yet.
Before production launch also implement Apple authorization revocation/account deletion
and session revocation notifications. Current server sessions expire after seven days;
Apple account revocation is not yet propagated immediately to them.
No Apple private key is required for current ID-token signature verification; token
refresh/revocation endpoints will need further Apple developer configuration.

RAM role to create: MaybiiCertificateRenewalRole, trusted service ecs.aliyuncs.com.
Attach only dns-role-policy.json (AddDomainRecord and DeleteDomainRecord on ddream.top).
Then attach role to ECS i-bp1a7n88rgbjd0kqqsja in cn-hangzhou.
This grants domain-wide record create/delete rights; code only creates the ACME TXT
record and deletes the RecordId it created. No main-account AccessKey required.

Latest verification: access + Apple auth unit tests pass (2026-11-04). Latest full
Release build blocked by non-exhaustive switches in Garden/PosyFloraEngine.swift
(new plant cases reported by compiler). Previously built simulator app was
installed, so that launch does NOT certify the latest Apple login changes.

## AI access decision — 2026-11-06

The product decision is to remove Sign in with Apple from AI review. The existing
Apple-login runner and token database are historical preparation and MUST NOT be
published as the anonymous service. The app no longer sends those login tokens.
An anonymous design still needs server-side subscription entitlement verification,
rate limits and a spending ceiling before deployment. Local review cooldowns are
not a server security boundary. Until these controls are implemented and tested,
keep the public endpoint disabled; the production AI flow is not ready for use.

## Anonymous subscriber prototype — 2026-11-06

`anonymous_runner.py` and `anonymous-nginx.conf` are a local prototype only.
They verify App Store-signed subscription transactions, fetch current status,
and impose three review requests per subscription per China calendar day.
A model language retry does not consume an extra review request, but can cause
two billable upstream calls. The backend stores a keyed hash of each subscription
identifier and daily usage. Old records are removed during new reservations;
independent automatic 30-day cleanup still needs server scheduling and verification.
Update privacy information before release. This is pseudonymous personal data, not anonymous logs. The independent
IP-based limiter and request-size cap are in the nginx template.

Do not deploy or expose this prototype yet. The existing free AI trial is not
supported, App Attest / replay resistance and StoreKit sandbox verification
are not complete, no production StoreKit key or trust root has been configured,
and quotas cannot be described as a monetary spending cap. App Store Server API
keys must be provisioned securely; production and sandbox must remain isolated.
The existing server still runs the old login preparation, not this prototype.

Local verification on 2026-11-06: the existing localhost development proxy
returned nonempty analysis and encouragement for synthetic week and month
requests. This did not test StoreKit, the anonymous relay, or the production
server. The paid-relay test suite used a fake Apple verifier/API and fake model;
it checked per-subscription three-request limits, concurrency, retry accounting,
request authentication failure and redaction. Apple sandbox, signed transactions,
App Attest and trial behavior remain unverified. No production keys or source
were deployed. The operator declined a shared daily global request ceiling.

Free trial research prototype: `trial_verifier.py` verifies an Apple-signed app
transaction, and `trial_quota.py` tracks a keyed-hash trial marker, pending work,
and a maximum of three attempts per China calendar day. A successful marker is
kept without an automatic expiration, so it requires an accurate privacy policy
and a deletion process before any deployment. These components are deliberately
NOT wired into `anonymous_runner.py` or the app yet. A signed transaction can be
replayed; App Attest, replay defenses, testability on unsupported devices, and
real Apple sandbox purchase / free-install tests still need implementation.

Apple IAP key 7V96L7F8ZS was created by the operator and downloaded once into a
restricted local backup. A harmless nonexistent transaction lookup returned
404 in the Apple sandbox (credentials accepted) and 401 in production; this is
not a successful production entitlement test. No key was deployed to the server.
Apple's commerce engineer says production API access is unavailable before an
app has a production release: https://developer.apple.com/forums/thread/806452
The app is currently marked Prepare for Submission, so the observed 401 is
consistent with that explanation, but does not independently prove its cause.

App Store Connect now has subscription group 22551981 and matching monthly and
yearly product IDs. Monthly and yearly price matrices have the requested values
for China, Japan and the US. Availability currently covers only those three
regions; this does not assert the operator chose to exclude all other markets.
Both products remain draft. Localizations, review screenshots, correct ordering
(yearly has more features and should rank above monthly), actual purchases and
the first submission with the app still require completion.
App Review and TestFlight use sandbox StoreKit transactions. A production-only
API verifier will reject those; accepting arbitrary sandbox transactions on the
public paid AI relay could let sandbox purchases incur real model costs. Solve
review access and abuse controls together before deployment; never automatically
treat sandbox entitlements as paid production subscriptions.

Security notes for the unfinished anti-replay path:
- Bind an Apple App Attest assertion to a fresh server challenge, the exact request
  bytes, and both StoreKit proofs. Verify attestation certificate chain, app ID,
  environment, key ID, nonce, counter and Apple validation-category/version
  extensions before registering a key. Counter update and challenge consumption
  must be atomic. Do not trust the local challenge helper alone.
- For the one-free-review prototype, retain only a keyed hash of Apple-signed
  appTransactionId and a success marker. Its indefinite retention conflicts with
  an unqualified 30-day retention statement and needs explicit disclosure and a
  deletion method. Losing or rotating the HMAC key changes identity and may reset
  trial history; secure recovery/rotation must be designed before rollout.
  The current app also clears its local free-trial state on data reset, whereas
  the indefinite server marker does not. Resolve the resulting product mismatch
  before connecting or deploying either trial implementation.
- Verify how to handle unsupported App Attest devices and network failures without
  creating a route that bypasses subscription and per-user limits. App Attest
  reduces abuse; it does not guarantee that abuse or all unexpected costs are zero.
- Include billing retries and model token usage in financial monitoring. The
  operator explicitly declined a shared global daily ceiling, so even with a
  per-subscription cap, total spend can increase with the number of subscriptions.

Additional local-only work: `subscription_quota.py DATABASE` removes expired
daily quota rows even when no requests arrive. It must be scheduled and tested
on the actual server before making a retention promise. This does not delete
trial markers, App Attest keys, receipts, backups, or other records. App Attest
certificate, receipt and assertion code is experimental, not connected to the
service, and tested only with synthetic fixtures. It requires independent
security review and real-device verification. The free trial remains unavailable
in the anonymous relay. No changes in this section have been deployed.

`review_authorization.py` composes app-transaction verification, subscription
status, request-bound App Attest assertions and paid/free quotas for local tests.
It is not connected to the HTTP relay or Swift client. Its exception behavior
requires a fail-closed caller; free-trial reset and data retention decisions,
real-device testing and review access remain release blockers. After the paid
agreement became active the synthetic lookup still returned sandbox 404 and
production 401, consistent with the pre-release restriction described above.
The monthly and yearly products now also have Chinese names and descriptions;
English/Japanese localizations and review screenshots are still incomplete.
