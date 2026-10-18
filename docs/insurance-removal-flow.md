# Insurance to self-pay flow

Implemented in the canonical backend, user Android app and pharmacy app.

## Supported phases

`received`, `underReview`, `partialOfferPending`, `confirmedReserved`,
`preparing`, and `ready`. Both full and partial orders are supported.
Completed, cancelled, rejected and not-collected orders cannot be repriced.

## Consent

1. User or authorized pharmacy actor requests `requestInsuranceRemoval`.
2. Server records a versioned quote with prior customer amount, new customer
   amount, reason, source status/offer/invoice and coverage snapshot.
3. Coverage remains enabled while the decision is pending. Forward fulfillment
   is blocked; legitimate cancellation remains available.
4. The current user interface offers continuing without insurance or cancelling
   the order. `cancelInsuranceRemoval` is restricted to the owning user with a
   pending request and its exact version; it releases reservations or reverses
   a canonical uncollected invoice. The older reject command remains compatible.
5. Acceptance rechecks the quote. A pending quote can be refreshed with its
   current version, creating new consent without restarting the waiting clock.
6. Detail and list totals display the pending uninsured quote ahead of old
   invoice/estimate fields. The stored insurer payment is changed only on consent.
   Successful decisions fetch current server state, and older snapshots cannot
   replace newer detail data.

Before invoicing, reservations and quantities remain unchanged. A pending
partial offer receives a new version to reject decisions from older insured
dialogs. Accepted partial consent is carried to the new version without a
second reservation. Full-order uninsured consent also caps invoice prices.

For an invoice awaiting delivery with no financial posting, the existing gross
amount after discounts becomes the customer amount. Insurer amount and claim
are cleared; original payer values are retained. Inventory, cost, gross profit
and shift totals do not move. Collection then posts customer payment once;
subsequent cancellation and refund use the uninsured invoice correctly.

Coverage waiting intervals are excluded from pharmacy processing time. Ready
orders gain the decision waiting time on their pickup deadline, and cannot be
marked not-collected while the coverage decision is pending.

## Verification evidence

- Backend full lint and 241 tests passed (18 removal cases included).
- User targeted tests: 13 passed.
- Price display correction: three model cases passed and two widget cases
  passed. Widget cases verify a live update replaces the old invoice total,
  continuation/cancellation choices, accepted state, rejection of an older
  snapshot, and the list card's current quote.
- Pharmacy targeted tests: 5 passed.
- Targeted analysis had no errors; existing warnings/informational findings
  remain. No native UI or production end-to-end flow is claimed verified.

## Release coordination

This change is local and has not been deployed or packaged into new binaries.
The updated user app must be available before pharmacy actors start sending
coverage requests; older user binaries cannot decide the new request.
The backend functions using the updated command or delay code are
`executeOrderCommand`, `processOrderDeadlines`, `onOrderCreated`,
`onOrderUpdated`, `adminOrderProjection`, `adminInsights`, and `adminList`.
Capture a fresh production inventory and verify named deployment targets before
publishing. No new rules or indexes are required by this flow.
