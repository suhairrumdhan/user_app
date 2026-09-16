# F03 — Order command contract

The canonical production source is `functions/src`. Order creation and every
status transition use the callable `executeOrderCommand` with schema version 3.

Each request includes a stable `operationId`. The server computes `payloadHash`
and stores the immutable command result in `orderOperations`. Retrying the same
operation with the same payload returns that exact result; reusing the ID with a
different payload is rejected.

Canonical states are: `received`, `underReview`, `partialOfferPending`,
`confirmedReserved`, `preparing`, `ready`, `completed`, `cancelled`, `rejected`,
and `notCollected`. Legacy names are accepted only by the explicit alias table;
an unknown value is never treated as `received`.

An unresolved insured order stays `received` until the user explicitly chooses
`continueWithoutInsurance`. A partial offer can be replaced only through
`revisePartialOffer`; every replacement increments `offerVersion`, and the user
can accept only the current version. Time spent waiting for that decision is
stored separately and is excluded from the pharmacy review duration.

For an order sale, `startPreparing` creates the invoice, consumes the
reservation, and deducts physical stock in one Firestore transaction. The
invoice remains tied to its creation shift with zero customer payment until
delivery. `completeOrder` records the customer payment in the current
collection shift and creates any insurance receivable exactly once. Before
delivery, `cancelAfterInvoice` and an expired `markNotCollected` restore the
same inventory documents and create a zero-cash reversal atomically.

Clients cannot create orders or write protected order state. Firestore rules
allow only related user/pharmacy reads and limited note/chat edits. Admin users
read `adminOrderSummaries`, which omits identity, medicines, health data, and
locations.

An owner Firebase session is the transport identity for the pharmacy app. An
internal employee still signs in using only the editable username and password
shown by the app. The server stores no plaintext password, returns an opaque
12-hour employee session, and binds operational order commands to the current
employee, credential version, active flag and permission set. A credential
change, logout, expiry, deactivation or explicit denial invalidates command
authorization. Employee credential, username-index and session documents are
server-only under Firestore rules.

One deterministic chat (`order_<orderId>`) can be linked to an active order.
Both participants may read it, but new messages are denied after `completed`,
`cancelled`, `rejected`, or `notCollected`. Order and chat notifications use
deterministic document IDs. User push delivery records a claim/outcome and uses
the notification ID as the Android collapse key/tag so trigger retries do not
create multiple visible cards for the same notification.

Local verification is `npm run verify:f03`. Production verification is
explicitly opt-in through `ROSHITA_LIVE_TEST=1` and
`ROSHITA_LIVE_PROJECT_ID=pharma-apps`, then `npm run test:f03:live`. Live suites
write their result to `_liveTestRuns`; they never use the emulator silently.
