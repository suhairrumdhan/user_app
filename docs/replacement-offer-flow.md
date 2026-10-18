# Replacement offers

`proposeReplacementOffer` is a pharmacy command available in underReview,
partialOfferPending, confirmedReserved, preparing and ready. Delivered or terminal
orders cannot be edited. Payload requires the viewed `offerVersion`, a nonempty
`reason`, and items containing target `medicineId`, `quantity`, `soldByPiece`,
source `replacesMedicineId` and `replacesSoldByPiece`.

Sources must belong to the original order. Each source may appear once. Omitted
sources are excluded, so the user reviews the complete offered list. The server
derives replacement names and images from the pharmacy stock and computes the
price and insurance share. This command records a pharmacy proposal; it does not
select clinically equivalent medicines automatically.

The user accepts with `acceptPartialOffer` and its current version. Acceptance
rechecks stock and price; stale price/version or insufficient stock fails
atomically. Rejecting with `rejectPartialOffer` cancels an uninvoiced order. After invoicing, rejection restores the original preparing/ready state and preserves its invoice, stock and pickup deadline. A revision
requires fresh consent. Both interfaces show original and replacement images;
missing/broken images use an icon only. Available images open an enlarged view.

Before invoicing, sending a replacement releases any existing reservation.
After an uncollected invoice, the old invoice remains pending until the decision.
Acceptance reverses it and reserves the new list in one transaction, preserving
invoice history and incrementing `invoiceGeneration`. The next invoice ID is
`order-{orderId}-replacement-{invoiceGeneration}`. User rejection preserves the old invoice and restores the original order. User `cancelOrder` is forbidden after invoicing; pharmacy `cancelPendingReplacement` can atomically reverse the invoice and cancel the order. No money is collected by a
replacement decision. Collected invoices cannot be replaced.

A replacement after invoicing starts a new fulfillment/pickup timing cycle.
Insurance removal during a pending replacement quotes the replacement list,
requires a separate user decision, and retains the old invoice until the
replacement decision. Pending insurance decisions block replacement actions.

## Release

These edits are local. Deploy the backend callable and deadline processor with
the existing insurance-removal release functions, then rebuild the user Android
app and pharmacy Windows app. Older pharmacy builds cannot propose replacements.
The automated test coverage does not replace a device check of image loading,
image zoom, layout and notifications against the deployed project.
