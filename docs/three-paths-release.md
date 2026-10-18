# Completion of the three pre-release paths

## Full-order price consent

The pharmacy button **إرسال سعر الطلب الكامل للموافقة** runs
`proposeFullOffer(offerVersion)`. The server prices the original list and stores a
versioned offer with `kind: full`. No reservation exists until the user accepts
the current version. Changed prices or unavailable stock reject acceptance
atomically. The accepted quote caps invoice unit prices and the customer total;
lower prices/discounts remain allowed.

Legacy `confirmFullOrder` captures a server quote. If its total exceeds the
submitted payable amount, a unit price increases, or the original amount is
unknown, it returns a pending full offer instead of reserving. Otherwise it stores
`fullOrderQuote` and reserves. An old reserved order with no known approved amount
cannot be invoiced until a new price offer is accepted.

## Live saved invoices

The pharmacy order details invalidate invoice lookup caches when the order changes
and use a server read. Opening a linked invoice also performs a fresh server read.
Saved order invoice tabs subscribe to their canonical invoice document and update
the displayed amounts and state. Reopening a tab replaces its snapshot. Closing
the tab disposes the feed; old-session callbacks cannot change the active view.

## Pharmacy cancellation while a replacement is pending

The pharmacy button **إلغاء الطلب وعكس الفاتورة** runs
`cancelPendingReplacement(offerVersion, reason)`. It requires the current pending
replacement version, an uncollected canonical invoice, a nonempty reason, and
employee permissions `orders.update_status` and `sales.refund`. Cancellation,
invoice reversal and restoration/quarantine of original stock are one transaction.
It also closes an outstanding insurance-removal decision and user wait timers.
Retries reuse the operation ID; a user acceptance that wins first makes the stale
cancellation fail. No substitution is reserved and no money is refunded because
the retained invoice has not been collected.

## Release and limits

Deploy the matching order callable, notification trigger, and existing timing/admin
projections, then rebuild both Flutter apps. No release build or deployment was
performed during this task. Automated checks cover backend transitions, price
ceilings, legacy migration, idempotent reversal, refund permission, invoice feed
updates/disposal/session isolation, and the full/replacement offer UI. A real
Android/Windows end-to-end run against the deployed project remains necessary.
