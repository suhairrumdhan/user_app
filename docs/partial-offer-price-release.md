# Partial offer price release — 2026-09-26

## Deployment evidence

- Project: `pharma-apps`.
- Named function: `executeOrderCommand`, `us-central1`, generation 2, Node.js 24.
- Firebase CLI reported `Successful update operation` and `Deploy complete`.
- Post-deployment inventory state: `ACTIVE`.
- Deployed source hash: `360e5a01f2d29a7937964d38bcfb0ecf5ea17145`.
- No rules, indexes, other functions or mobile binaries were published in this release.

## Verification

- Full backend ESLint passed after correcting the k6 test module configuration
  and removing an unused test import.
- Backend predeploy tests: 223 passed, zero failed.
- User Flutter tests: 66 passed, zero failed, two PDF tests skipped because their
  local sample path environment variables were not provided. Earlier corpus
  verification remains separate evidence.
- Full Flutter analysis reported no errors, 43 warnings and 459 informational
  findings; this is not a clean analyzer gate. Output is recorded locally in
  `test_results/user_release_analysis.txt`.

## User app readiness

The existing APK dated September 24 predates the partial offer price UI.
A new APK and actual Android user / pharmacy flow verification are required.
Validate a partial offer before and after acceptance, price revision, full
insurance coverage, continuing without insurance, invoice discounts, cancellation,
chat and notifications, and recovery after interrupted connectivity.
Legacy offers without a price quote must be resent for acceptance in the updated UI.
Price consent protection in this release applies to quoted partial offers;
full-order price changes do not have the same new consent flow.
Successful local tests and an ACTIVE deployment do not establish end-to-end
production correctness or 100 percent final readiness.
