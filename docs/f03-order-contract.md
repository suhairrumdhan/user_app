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

## Insurance ownership and order continuity

Each beneficiary has at most one current insurance document. Its document ID
and `beneficiaryId` are the beneficiary key (`self` or the family-member ID).
The document stores that beneficiary's own `policyNumber`; a policy is not a
single account-level number shared by an arbitrary list of family members.
`beneficiaryType`, `beneficiaryName`, company code, policy number and coverage
dates are snapshotted when the user submits an insured order.

The search insurance filter is only discovery. `createOrder` independently
resolves coverage against the exact beneficiary document, the policy number,
its validity dates, the pharmacy's accepted codes and its active company
contract. A successful resolution writes immutable `insuranceSelection`
details (company, policy, beneficiary and percentage) and advances the order to
`underReview`. Failure leaves it in `received` until the user explicitly elects
to continue without insurance. The pharmacy must display and invoice the
resolved selection; it cannot substitute another company. Invoice creation
revalidates the same beneficiary-policy-company relationship and current
coverage percentage before calculating the insurer and customer shares.

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

Partial offers include a server-generated `quote` in LYD: unit and line prices,
gross total, insurance share, and customer total. Acceptance verifies current
stock prices and insurance coverage against that quote. A changed quote returns
`aborted` with `stale-offer-price` and requires a revised offer. An invoice may
reduce the accepted price but cannot raise any quoted unit price or customer
total. Accepted estimates and final invoice totals are projected onto the order.
The user app displays the quote before acceptance and retains it afterward;
legacy offers without a quote must be resent to enable acceptance in this app.
Continuing without insurance restores the gross estimate.

Insurance removal for active orders has a separate versioned consent record:
`requestInsuranceRemoval` (user or pharmacy), `acceptInsuranceRemoval` and
`rejectInsuranceRemoval` (owning user only). Requests keep coverage and amounts
unchanged until acceptance, block forward fulfillment commands, and publish an
authoritative uninsured quote. Price changes require rejection and a new request.
Before invoicing, acceptance updates the quote without changing a reservation;
pending partial offers get a new version so an old insured dialog cannot accept.
For canonical invoices still in `pendingDelivery`, acceptance transfers the
insurer share to the customer without moving inventory or posting money. The
prior payment snapshot is retained. Delivered or financially posted invoices
cannot use this command. Rejection preserves coverage, invoice and inventory.
Coverage decision waits are excluded from processing time and extend a ready
order's pickup deadline. Notifications and audit records are deterministic.
The older `continueWithoutInsurance` command remains limited to `received` for
existing clients; updated clients use the quote/consent flow.
Updated user clients show the pending quote in detail and list totals and offer
continuing without insurance or `cancelInsuranceRemoval`. The latter requires
the owning user's current pending version and releases stock or reverses an
uncollected invoice atomically. Refreshing a quote passes its current version
to `requestInsuranceRemoval`; it advances consent version without resetting the
waiting interval. Legacy `rejectInsuranceRemoval` remains compatible.

Local verification is `npm run verify:f03`. Production verification is
explicitly opt-in through `ROSHITA_LIVE_TEST=1` and
`ROSHITA_LIVE_PROJECT_ID=pharma-apps`, then `npm run test:f03:live`. Live suites
write their result to `_liveTestRuns`; they never use the emulator silently.
