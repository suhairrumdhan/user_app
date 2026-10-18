# App review before release — 2026-09-26

Scope: static analysis of both Flutter projects, source tracing of order,
replacement, insurance-removal and invoice flows, and targeted widget tests.
This review does not certify every feature or constitute a production/device
end-to-end test. No deployment or release build was performed.

## Required follow-up

**Update:** the three items below have been implemented locally. See
`three-paths-release.md` for the completed commands and UI behavior. The original
findings are retained here as the review record.

1. **Full-order price consent:** `confirmFullOrder` reserves the original list
   directly. At invoice creation, the accepted-price guard depends on an accepted
   partial/replacement quote or insurance-removal quote. A regular fully confirmed
   order has no equivalent binding quote/consent cycle. Add a full-order quote and
   a renewed user decision when its payable price increases.
   Evidence: `functions/src/domain/order-commands.js`, confirmation and
   `consumeReservationAndCreateInvoice` acceptedQuote handling.
2. **Fresh pharmacy invoice view:** `OrdersPage._loadOrderInvoice` memoizes a
   `Future<Sale?>` by invoice ID and does not invalidate it when the order changes.
   Insurance removal can modify the same invoice ID. Opening its tab can therefore
   use a stale Sale snapshot. Refresh from the server on open or maintain a live
   invoice subscription, and update already-open saved invoice tabs.
   Evidence: pharmacy `lib/views/orders/orders_page.dart:1314` and
   `_openOrderInvoice`.
3. **Pharmacy cancellation while replacement is pending:** the transition matrix
   permits user rejection/cancellation in partialOfferPending; pharmacy
   cancelAfterInvoice is permitted only in preparing/ready. Once a pharmacy
   proposes a replacement after invoicing, it lacks an operational cancellation
   path while waiting for the user. Add a conditional command and visible action
   that atomically reverses the retained uncollected invoice and cancels the order.
   A withdrawal action that restores the previous state is a separate product
   choice and must not be confused with cancellation.

## Fixed during review

The pharmacy medicine review duplicated names/images and could dereference a null
inventory medicine while showing the barcode. Removed the duplicated section and
restored a guarded barcode row. Two new widget tests passed: missing inventory
renders safely, and replacement/original lineage and icons appear once.

## Verification

- Full Flutter analysis completed for both projects with no `error` diagnostics.
  Warnings and informational diagnostics remain; analyzer exits are nonzero due
  to those diagnostics. Reports are in `test_results/predeploy_*_analysis.txt`.
- Earlier backend suite: 256 passed. Replacement selection/dispatch widget,
  draft editing and user live replacement/price display tests passed.
- Real Android/Windows verification remains: chat agreement, replacement,
  acceptance/rejection, price changes, insurance removal, invoice generation,
  collection/cancellation, network recovery, pictures and notifications.

Recommendation: resolve the three follow-ups above before treating the two apps
as a final release; rebuild both apps and deploy the matching backend together.
