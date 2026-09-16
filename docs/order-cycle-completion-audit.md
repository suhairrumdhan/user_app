# Order cycle completion audit

Source of requirements: `C:/Users/hp/OneDrive/Desktop/مشروع التخرج/فصول التوثيق المعتمدة/التوثيق المعتمد.docx`, especially chapter 6, INT-02 through INT-14 and the linked user/pharmacy use cases. Reviewed 2026-09-14. This is engineering evidence, not a change to the graduation document.

The goal remains completion of the full order lifecycle in both applications, including critical failures and alternatives. Passing existing F03 tests does not establish 99% coverage.

User handoff boundary, confirmed 2026-09-14: finish implementation of the order lifecycle and its related operations, then STOP at ready-for-testing and hand over the automated commands plus Android/Windows manual scenarios. The user executes the tests. Do not start unrelated tasks or automatically run functional/live tests or publish the current revision. Static source checks remain part of implementation. The source reached this ready-for-testing boundary after the employee/chat/notification continuation below. Readiness is not proof of final completion; record results when the user supplies them and address failures in scope. Inventory/POS batch FEFO and direct POS refunds remain a later phase and are not marked complete.

| Requirement | Current evidence / gap | Completion evidence required |
|---|---|---|
| INT-02 new order eligibility | Current backend checks approval, activation, administrative visibility and explicit receiving flag for new orders. Search visibility is separate from receiving: a visible stopped pharmacy can appear, but cannot receive a new order. Current-order commands are not blocked by those two switches | Seven new command cases and a new isolated-identity live suite are prepared, not executed. Prove new-request denial and existing-order completion through deployed commands plus both native UIs |
| INT-03/07 unified quantities and competition | Shared stock-units backend and Dart helper account for pieces backed by unopened unreserved packages. New POS transaction now reads stock, shift, pointer and company and commits invoice, stock, ledger, shift totals and insurer summary together; old split posting removed | Pack/piece and mixed simultaneous order/POS live tests, atomic rollback across all effects; client transaction does not establish trusted server authorization |
| Duplicate medicine | Backend safe input and user selection group by medicine plus unit; pharmacy fulfillment uses accepted offer items | Same medicine and unit displayed once with summed quantity; distinct units remain distinct; widget/live evidence missing |
| INT-05 replay / lost response | Backend records, deterministic order invoice ID, user persisted commands plus in-flight dedup added. Pharmacy coordinator now deduplicates the same command before storage reads, snapshots payloads and retains uncertain operation IDs with session guards | Prepared pharmacy recovery tests remain unexecuted; real app restart/lost-reply proof, cross-command uncertain-operation recovery UI and hard-crash persistence guarantees still need review |
| INT-06 insurance | Creation reads actual user card, membership, active company and contract; explicit uninsured decision clears active coverage. Invoice now revalidates selected card identity, dates, membership, company acceptance and current percentage, and rejects silently omitted coverage | Eight invoice rejection tests added; real app recovery after coverage changes and live execution remain unproved |
| INT-08 partial offer | Pharmacy editor now groups medicine/unit rows and prefills current quantities. Revision checks the viewed version; confirmed pre-invoice orders can reopen by atomically releasing the former reservation and requiring new consent. Each accepted replacement has a separate reservation record | New isolated and live repeat-offer suites prepared but unexecuted; visible Android/Windows acceptance, rejection, changed stock and concurrency evidence still required |
| INT-09 invoice and delivery | Canonical create/collect required. Shared read guard now verifies actual invoice identity, schema, consumed reservation quantities/units and payment snapshot for readiness, collection, reversal and refund. Creation whitelists input fields; direct order invoice/ledger edits are denied in local rules | Updated negative suites and rules tests prepared, not run/deployed; real invoice/shift/close concurrency and employee session authority still require proof |
| INT-10 cancellation / not collected | Reversal quarantines inactive/expired goods and restores valid originals; delivered returns always quarantined | Four pre-invoice states, forbidden later user cancellation, exact deadline, failed reversal rollback; live coverage needs extending |
| INT-11 authorization | Internal employees now use an owner-bound opaque server session backed by salted PBKDF2 credentials. Order commands reject an employee ID without a live session and transactionally reread credential version, active state and permission. Credential/index/session documents are server-only | New unit, emulator and live employee-auth suites are prepared but unexecuted; deploy and prove login, edit invalidation, logout, inactive/denied employee and real Windows command paths |
| INT-12 chat / notifications / session | Shared replaying SessionListFeed replaces separate notification list/badge sources; old-account events are ignored. Chat creation is deterministic and atomic in both apps, stays visible through all nonterminal order states, and rules close writes for all four terminal states. Push delivery now has claim/outcome state plus stable Android collapse ID | New emulator and live chain tests are prepared but unexecuted; actual Android FCM display/retry and both native chat screens remain manual evidence |
| INT-13 timers | Added processOrderDeadlines every 5 minutes UTC, transactional source reread, independent deterministic alerts and no automatic finalization. Reopened offers now accumulate both active periods and decision waits; a new controlled-clock test traverses actual commands to readiness at 26 active hours | Existing timer tests plus the new two-command-cycle test are prepared, not executed. Real scheduled execution, full two-offer UI path and admin rendered values remain unproved |
| INT-14 insured refunds | Canonical refund and insurer FIFO allocation wired to pharmacy; unpaid claim reduction, paid company credit and quarantine implemented. Refund shift fields corrected to cashRefunds/cardRefunds plus insuranceRefunds/refundsCount, matching drawer model and UI | Live pre/post payment proof, historical unallocated receipts, reporting and close-shift race remain pending |
| Search availability | Version-7 projection creates missing indexes and rereads current source transactionally. New pharmacy-profile trigger and expiry sweep are prepared. Search and confirmation now share unit-specific quote/availability; package and piece counts are no longer summed for match ordering | 21 projection cases, policy/quote tests and live trigger scenarios are prepared, not executed. Rules rollout, old-index rebuild, scheduler execution and native UI behavior remain unverified |
| Batch allocation and original return lineage | Word TC-PH inventory/sale/return cases require unit conversion, FEFO across eligible batches and original allocation linkage. Reviewed order/POS helpers still operate on medicine-level stock counters; batchNumber metadata alone is not an allocation engine. This is an inventory/POS architecture task and is explicitly deferred until after the requested order-cycle test stop | After the current order-cycle test gate, implement actual batch ownership, FEFO allocation, active reservations, expiration/quarantine exclusion and original-batch returns across orders/POS/purchases; prove mixed-unit example A=12 with 2 reserved, B=20, sale 10+5 |

Verification must include live Firestore tests plus visible flows in Android user app and Windows pharmacy app. Record actual commands/results and deployed revision before closing the goal. No production publish or new live run has been performed for this audit yet.

## Latest evidence and next gates

2026-09-14: current source was reread against Word INT-09 through INT-14. The last turn is progress: it changed the shared notification source, error handling and persisted command deduplication. This continuation corrected a confirmed backend-to-UI mismatch in shift refund field names and a stale index write race.

Static validation for the latest shift/index batch: Node syntax checks and ESLint for order-commands, order-ledger and the two touched backend test files passed. Dart analysis of search index, shift model/controller/page and the new shift test returned no errors, but 9 existing unused declarations/parameters and 36 informational style/deprecation findings. These results are NOT functional test or deployment evidence.

Prepared checks for the user (not executed in this continuation):

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application\functions'
npm run verify
Set-Location 'C:\Users\hp\StudioProjects\user_application'
flutter test test/order_notifications_regression_test.dart
Set-Location 'C:\Users\hp\StudioProjects\pharmacy_app'
flutter test test/order_shift_refund_test.dart
```

Next critical implementation gates, without reducing the goal:

1. Execute the prepared employee session/rules/live tests and deploy the same reviewed functions/rules revision; source implementation is now present but unverified.
2. Verify the new POS atomic transaction/replay and extend coordinated transactions to direct POS refunds and other financial/inventory writers. Shift open/close now use transactions, but real concurrent integration coverage and protection of every writer remain outstanding.
3. Execute the new controlled-clock two-offer command scenario and both live reopening scenarios, validate the deployed scheduler, and prove both excluded intervals through the Android/Windows UI. The pre-invoice reopen transition is now implemented, but its functional/live evidence is not yet available.
4. Verify the removed invoice/reversal bypasses with updated suites; finish receipt/credit accounting and source-rule validation. Invoice-time coverage checks are implemented but not live-verified.
5. Execute the extended live chat/notification and employee-auth branches and record app screenshots/observed states against every applicable INT gate before any completion claim.

### Scheduler continuation evidence

Added `functions/src/domain/order-timers.js`, exported `processOrderDeadlines`, and updated the exact source export contract to nine functions. Seven timer tests are prepared but not executed in this continuation (user owns test execution). Node syntax checks and ESLint for timer source/index/export and timer tests pass. Dart analysis of the changed user order files and pharmacy order model/page reports no errors or warnings, only style/deprecation information. No production scheduler or new Functions deployment was performed.

Admin summary updates now transactionally reread current order data instead of publishing an older event snapshot. This prevents an out-of-order status event from reverting newly recorded delay indicators in the derived summary.

Test command: from `C:\Users\hp\StudioProjects\user_application\functions`, run `npm run verify`. Completion still requires observing the deployed scheduled function and matching source flags, notifications and app states on test-owned live orders.

### Canonical invoice continuation

Removed three bypasses: preparation using only a precreated invoice ID, reversal based on a caller-supplied precreated refund, and completion that silently skipped collection for absent/non-payable invoices. Updated local full lifecycle to issue a real canonical invoice payload and assert physical consumption and customer collection. Updated live lifecycle fixtures/requests to the same contract and preserved negative tests for forged/precreated records. All remain unexecuted in this continuation. Node syntax and targeted ESLint passed; no deployment occurred.

Pharmacy source inspection confirmed saveSale returns from createOrderInvoiceAtomically for order invoices before entering the POS path. Removed the obsolete after-save order hook and service method rather than retaining a second unsupported command path.

### Shift concurrency continuation

Shift closure previously read totals once and later committed a blind batch. It now transactionally rereads both the actual shift and active-shift pointer, recalculates the drawer in integer cents, requires an explicit note for any current difference, and closes/clears the matching pointer atomically. It cannot clear a newer shift pointer. Opening a shift similarly rereads the state inside a transaction to prevent two simultaneous open shifts for one actor. Auth identity is checked before and after awaited reads, but this is client session hygiene, NOT the missing trusted employee authentication boundary.

Added five pure calculation tests in pharmacy `test/shift_closure_test.dart` for all cash movements, a newly posted collection/refund, cents rounding and invalid inputs. These are prepared, not executed; they do not simulate a Firestore concurrency race. At this stage direct POS registerSaleOnShift was still uncoordinated; the next continuation replaces that sale path, but refunds and other writers remain. Removed a diagnostic line that printed the internal employee password; no credential data was deleted or changed.

### POS atomic posting continuation

Added pharmacy `lib/services/pos_checkout_service.dart` and `lib/shared/pos_posting.dart`. The production callback rereads invoice, current shift and actor pointer, existing deterministic ledger IDs, inventory and insurer before writes. It posts physical consumption (preserving order reservations), invoice, customer receipt, company claim, one shift sales count and split cash/card/company totals, and company summary in one Firestore transaction. An overlapping shift closure or reservation therefore invalidates the read set. Removed the draft document write, separate `_postSaleFinancialTransactions`, separate stock-only transaction and the post-save `registerSaleOnShift` calls. Both save entry points now use the same posting path; order invoices still use their canonical backend command.

POS identity includes actor, original draft creation instant and visible invoice number (the visible number alone repeats each second). A recorded fingerprint rejects changed retries; completed replay returns the original invoice without posting again. Concurrent same-draft save calls share an in-flight future. Draft persistence is required before committing, and local item expiry timestamps now serialize as ISO strings instead of unencodable Firestore Timestamp values. Session identity is rechecked after awaits, including the order-invoice command. These checks are client hygiene, not a trusted employee-authentication boundary.

Prepared 18 tests: nine in `test/pos_posting_test.dart` cover split accounting, local JSON/expiry recovery, stable identity, changed replay, shift gates and quantity aggregation; nine in `test/services/pos_checkout_service_test.dart` execute the production service against an in-memory optimistic transaction double and cover atomic abort, lost response, same-draft concurrency, competing sales, intervening reservation/shift closure and changed insurance rate. None were run in this continuation. The double explicitly does NOT prove real Firestore isolation, security rules, deployed source or native plugin behavior. Targeted Dart analysis of both new sources and all three new test/helper files returned no issues. No live writes or deployment performed.

Commands for execution:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\pharmacy_app'
flutter test test/pos_posting_test.dart test/services/pos_checkout_service_test.dart test/order_shift_refund_test.dart test/shift_closure_test.dart
```

Remaining POS gates: trusted server-bound employee authorization, live concurrent tests against the actual command/rules stack, atomic direct-sale refunds, company summary rebuild races and session/UI recovery after uncertain completion. This is progress, not closure of the full lifecycle objective.

### User handoff/report requirement

User clarified that modification authorization covers only Roshita user, pharmacy and admin projects, not unrelated projects. After the full task is finished, review actual progress and update the existing HTML task report. Located `C:/Users/hp/Documents/Codex/2026-09-12/new-chat-2/code_audit/report/index.html` with title `روشيتة | خطة مطابقة الكود والتوثيق` and F01/F02/F03 entries. This is the relevant code plan candidate, distinct from `consistency_review/todo/repairs_todo.html` (documentation repairs). Preserve report data/local progress and distinguish implemented, tested and deployed evidence. No report completion marks have been changed yet.

### Canonical invoice identity and source rules continuation

Added `functions/src/domain/order-invoice.js`, shared by markReady, completeOrder, cancelAfterInvoice, markNotCollected and delivered refund. It reads both the real invoice and server-owned consumed reservation, requires matching order/pharmacy/invoice/schema/source, inventory-consumed flags and exact summed medicine quantities by package/piece unit, and verifies pending/delivered payment snapshots. Missing, unrelated, partially posted, reversed and mismatched records fail before business effects. Invoice creation no longer spreads arbitrary input fields: callers cannot inject future collection/refund/reversal markers. Reversal validates stock counters before restoring and quarantines malformed expiry instead of restoring unverified goods.

Updated `firestore.rules` to remove overlapping recursive owner write grants for sales, financial transactions and quarantined returns. Canonical order invoices cannot be forged, converted to POS, edited or deleted directly. POS invoice plus ledger writes are allowed using getAfter, including null metadata from the existing financial model; POS refunds cannot target an order invoice. User incident writes/deletion are server-only. These changes do not solve trusted employee login or protection of all other financial writers.

Added 42 backend cases (36 malformed invoice variants across readiness/delivery/cancellation/not-collected, five delivered-refund guards, one injection test), and three emulator tests for rules denial and preserving POS after-state writes. Updated isolated and live fixtures to contain real canonical identity/payment/reservation fields instead of legacy ID-only invoice records. All new functional/emulator/live cases remain unexecuted in this continuation. Node syntax checks and targeted ESLint passed; rules execution and production deployment have not occurred. Existing older live test success must not be presented as proof of these changes.

Prepared commands from user application functions directory: `npm run verify`, then `npm run test:emulator`; production publishing and live verification must use the same reviewed source/rules revision. The subsequent pharmacy UI continuation below addresses the direct soft-delete mismatch.

### Pharmacy action and session UI continuation

Added `lib/shared/pharmacy_action_policy.dart`. The history menu offers soft-delete only for saved, non-deleted direct POS invoices without an order link. Order invoices, order reversals and order refunds remain visible and cannot enter that path. The controller rereads and validates the invoice plus current actor/permission in a transaction before soft-delete, and reports a specific action message rather than generic Firestore failure. The history list refreshes after a successful deletion only. This is UI/race alignment with the prior rules change; it does not make legacy direct POS refunds atomic.

Employee UI permission evaluation now requires an active identified employee and successful permission loading; explicit employee overrides precede the admin role. Entering/switching internal login locks owner fallback while the employee login is unresolved. A generation plus Firebase UID check discards late employee/profile/role reads after switching or logout. Failed role loading does not re-enable admin actions. Auth account changes clear previous employee/pharmacy state, pharmacy loads reject stale account responses, and the auth subscription is cancelled on disposal. Credential fields are removed from the returned employee session object and the employee ID comes from the document path rather than its editable `id` field; a raw employee debug print was removed.

Eight tests in pharmacy `test/pharmacy_action_policy_test.dart` cover owner identity, switching, admin overrides, inactive employees, failed permission loading, role precedence and invoice action gating. They are prepared but unexecuted. Targeted Dart analysis of the helper and tests reports no issues. This does NOT fix the fundamental server authorization gap: internal login still queries plaintext credentials through the client and shares the pharmacy owner's Firebase identity. Server-bound employee authentication/session, credential storage migration and permission-aware direct writes remain required. Do not label INT-11 complete.

Prepared command: from pharmacy_app run `flutter test test/pharmacy_action_policy_test.dart`. No app launch, functional test, live write, deployment or HTML completion-mark update occurred in this continuation.

### Pharmacy command recovery continuation

The preceding response explained the employee-authentication plan only; this continuation revalidated current code and made implementation progress. Employee login must remain internal username/password with an editable username and no email account requirement. No server-authentication migration was implemented or published here, and INT-11 remains open.

Added `lib/shared/pending_pharmacy_order_commands.dart` and wired it into `PharmacyOrdersService`. Registration occurs before the first asynchronous storage read so matching simultaneous calls share one result and one operation ID. Requests are deep-snapshotted, nested map key order is normalized for comparison, and each transport attempt gets a fresh copy. Existing preference keys and saved request envelopes are preserved for recovery from the prior version. Failed preference writes prevent sending; failure to clean up a known successful result does not turn that success into a reported failure.

Unknown/transport errors retain the operation ID, including malformed HTTP replies, aborted and resource-exhausted failures. Retries are bounded at three attempts with the same identity. An idempotency conflict never discards the record. A later business/permission rejection after an uncertain reply also retains it: that rejection does not disprove an earlier commit. A first, definitive rejection can clear its record. Corrupt saved attempts are preserved and block automatic replacement, requiring investigation rather than silent deletion.

The service captures actual Firebase user, local employee-session generation and current employee ID. Changing account/employee or entering login prevents further retries and prevents returning a late success into the new session. Windows token acquisition uses the captured Firebase user and checks session identity before and after awaiting its token. These are client isolation checks only; they do not close the shared-owner-UID server authorization gap.

Prepared 24 cases in pharmacy `test/services/pending_pharmacy_order_commands_test.dart`: concurrent duplicate/reordered requests, changed and mutated payloads, six retryable error categories with restart recovery, a real HTTP-client parser with a mocked transport, unknown local failures, definitive rejection, later rejection after uncertainty, idempotency conflict, storage failure, stale-session replies/retries, employee mismatch, cleanup failure, corrupt records and independent orders. These tests use an in-memory store and mocked transport, NOT live Firestore or actual disk/restart execution. None were run in this continuation, following the user's instruction to own test execution.

Static Dart analysis of the changed helper, service, auth controller and test reported no compilation errors or warnings; pre-existing auth style/deprecation diagnostics remain. Whitespace diff checks passed for touched tracked source. No app launch, live writes, deployment or HTML completion marks occurred. SharedPreferences still underlies production persistence; this batch does not prove power-loss durability or safe coordination between separate application processes. Those limits, cross-command recovery UI, employee authentication, all other audit gates and coordinated live verification remain outstanding.

Prepared execution command:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\pharmacy_app'
flutter test test/services/pending_pharmacy_order_commands_test.dart test/services/order_callable_http_client_test.dart test/pharmacy_action_policy_test.dart
```

### Repeated partial offers and documented timing continuation

2026-09-14: re-read the current Word source text at INT-08 and INT-13 without editing or re-exporting the document. INT-13 explicitly requires review from day-one 08:00, waits 10:00-13:00 and 18:00-20:00, and readiness day-two 15:00 (26 active hours, 5 waiting hours). This exposed a concrete source mismatch: confirmedReserved previously had no path back to a new offer, so the second separated decision interval could not occur through commands. The preceding goal turn made progress in command recovery; this continuation makes further source/UI/test progress, not a completion claim.

Added confirmedReserved -> partialOfferPending through revisePartialOffer, only before any linked invoice. Revision requires the offerVersion actually viewed by the pharmacy, including zero after full confirmation, so stale dialogs cannot silently replace the current offer. Reopening validates items first, releases the existing active reservation in the same transaction, clears active consent and starts a new decision interval. It preserves the old reservation record; later acceptance creates a distinct versioned reservation instead of colliding with or overwriting the original fixed ID. Rejecting/cancelling the new offer leaves the old reservation released. Failed release or failed new reservation rolls back all effects, with no silently reduced quantities.

Active pharmacy time is accumulated when entering each new wait and resumed on acceptance. Decision start/deadline are cleared when a decision or cancellation completes; revising an already-pending offer counts only its actual waiting segment. Added an injectable server-side clock to the handler factory for deterministic command testing, not a caller-supplied timestamp or production-time override.

Pharmacy UI now offers "تعديل الكميات وطلب موافقة جديدة" for a confirmed, uninvoiced order and explains that sending releases the old reservation. The new PartialOfferDraft groups duplicate medicine lines by medicine AND unit, prefills current offer quantities, validates selected amounts and carries the viewed version. The controller handles busy state and failed revision messages. Updated the user-side status transition helper to reflect user-only acceptance, pharmacy-only revision and insurance decision actors, and disabled acceptance when offer details/version are absent. Corrected mounted-context guards for cancellation and chat errors while reviewing the same details screen.

Prepared nine backend cases in `functions/test/f03/repeated-partial-offer.test.js`, six pharmacy draft cases, three user transition cases, and two live cases added to `order-accounting-live.test.js`. The nine backend cases include a complete actual-command chain through both waits, canonical invoice creation, readiness, exact delay boundary, repeated timer scans and pickup overdue; they also cover revision replay, stale decisions, both cancellation paths, rollback, invoice guard, original reservation ID collision and changed inventory. The controlled clock/fake Firestore does not prove real transaction concurrency. Live cases exercise actual deployed callables with test-owned stock and both new user decisions, but do not wait 31 wall-clock hours or validate production scheduler timing. Updated existing revision tests and the exact transition contract to the new versioned request.

Node syntax checks and targeted ESLint passed. Dart analysis reported no compilation errors or warnings for touched sources/tests; existing view style/deprecation information remains. The new pharmacy helper/test analysis has no issues. Functional tests, live tests, app launches, deployment and HTML completion marks were NOT performed. Existing older deployed functions will reject this new transition; publish only a coordinated, verified backend/client revision. Unresolved saved revision requests from the older payload must be recovered or explicitly investigated, not discarded to bypass the new version requirement.

Prepared commands, to be executed by the user:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application\functions'
npm run verify
Set-Location 'C:\Users\hp\StudioProjects\pharmacy_app'
flutter test test/partial_offer_draft_test.dart
Set-Location 'C:\Users\hp\StudioProjects\user_application'
flutter test test/order_status_transitions_test.dart
```

After coordinated deployment and existing live-test opt-in/credentials, the prepared accounting live suite includes the new scenarios: run `node --test test/live/order-accounting-live.test.js` from the functions directory. Do not treat prepared tests as passing evidence. The full audit remains open, including employee server authentication without emails, direct financial writer/refund atomicity, search/index gates, notification/session work, scheduler/admin evidence, all regression suites and the final HTML progress update.

### Availability/index continuation and progress reporting

2026-09-14: the user requests detailed step-by-step updates and a progress percentage. Report the reviewed item, actual change and remaining verification separately. A total verified percentage is not yet computable from this audit: prepared test counts and old passing runs are not a denominator for the 117 requirements and must not be reported as 99% completion.

Implemented shared availability policy in the backend and both Flutter projects: new orders require an approved, non-blocked, active pharmacy explicitly accepting orders (`isOnline == true`). Existing-order transitions are not gated by this new-order switch. Reservation and invoice consumption now reject malformed supplied expiry dates and the exact expiration boundary. Missing expiry remains distinct from malformed supplied expiry. Search also rechecks expiry locally and fetches current pharmacy eligibility. This source review does not prove existing-order continuation after a switch; prepare a command-level regression before closure.

The version-7 server projection rereads current medicine and pharmacy in a transaction, creates a missing public index, removes obsolete indexes when their source is missing and replaces outdated projection fields. Added `onPharmacySearchProfileWritten` and `refreshMedicineSearchAvailability` (every 15 minutes), retaining `onMedicineStockWritten` with the new projection. Export contract now includes 11 functions. Added the `available + expiryAt` composite index. Pharmacy client index rebuild version is now 7. Existing v6 documents without `expiryAt` require rebuilding before the expiry sweep can cover them; no live rebuild or deployment occurred.

Tightened source rules so an ordinary signed-in user cannot write any pharmacy's search index, and pharmacy-owned index writes require matching source IDs and an existing medicine. Owner profile edits cannot change administrator approval/block/activation fields. These rules still need emulator/live verification and coordinated rollout; trusted employee identity and permission-aware writes remain a separate unresolved gate.

Prepared 20 cases in `functions/test/f03/availability-index.test.js` for eligibility, expiry, malformed/fully reserved stock, public projection, missing index creation, delayed refresh, source deletion and profile-trigger loop avoidance. They are NOT executed. Updated three live-suite pharmacy fixtures to explicitly accept orders. Node syntax checks and targeted ESLint passed; user Dart availability/search analysis reports no issues after removing an unused conversion helper. Pharmacy analysis has only a pre-existing interpolation style info. Index JSON parses successfully. No functional tests, app launches, live data writes, deployment or HTML completion marks occurred.

Remaining in this batch: rules denial/owner-compatibility tests, command-level stopped-pharmacy continuation tests, Dart policy regressions, live projection/scheduler evidence, old-index rebuild verification and package-versus-piece result/price consistency review. Remaining overall gates above are unchanged. Prepared user-run command from the functions directory: `npm run verify`; do not run new live scenarios against the old deployed revision as proof of the new code.

### Documentation correction and unit-specific quotes continuation

The preceding turn made progress through source edits, static validation and the audit update. This continuation reread relevant Word text, including the visibility/receiving distinction and package/piece and batch-allocation requirements, without modifying/re-exporting the document. That authoritative text contradicts the preceding batch's use of the receiving flag as a search visibility gate. The correction below supersedes that policy: `pharmacyVisibleInSearch` excludes unapproved/inactive/administratively blocked pharmacies, whereas `pharmacyAcceptsNewOrders` additionally requires `isOnline == true`. A stopped but visible pharmacy remains eligible for search. Existing-order commands remain separate from those switches. Approval and trusted employee permissions still require their independent enforcement/audit.

Added user `MedicineSaleQuote` and used it in both the actual matcher and order-confirmation preflight. A quote chooses a unit with available stock; a saved piece selection cannot silently become a package after stock/configuration changes. Missing/nonpositive piece estimates derive from package price divided by valid units, never from the entire package price. Without a conversion/price, loose pieces have an unknown estimate (zero), not an invented package charge. Index-side piece conversion follows that same fallback. Match ordering no longer adds package and piece counts together. Confirmation now rechecks new-order pharmacy eligibility, expiry/stock validity, selected-unit availability and changed estimates. These are preliminary checks, not a reservation or proof of final invoice correctness.

Both Dart stock parsers now reject counters and computed piece totals outside the backend's safe-integer range. Public index optional text fields no longer copy arbitrary nested source objects. The expiry scan ignores malformed source IDs instead of following slash-containing paths; this does not constitute repair/backfill of corrupt legacy index documents.

Prepared test additions: seven new command-level eligibility/continuation cases in insurance-resolution, three emulator rules cases, eight policy tests in EACH Flutter project and nine user quote/matcher tests. Projection suite now contains 21 cases including separation of receiving/visibility and piece-price fallback. Tests are prepared, NOT executed. Existing native view diagnostics are informational only; targeted analysis of the new user policy/quote/matcher/search/test files reports no issues. Targeted Node syntax/ESLint and tracked whitespace checks passed. Final analysis after the stock-parser range edits also found no errors or warnings in either project; each copy retains one pre-existing missing-braces style info in the sell method.

Added `functions/test/live/order-availability-live.test.js` with three real deployed-service scenarios: source-trigger creation/expiry repair, stopped receiving with existing-order delivery/replay, and administrative hiding with existing-order delivery/replay. Duplicate medicine input becomes a single quantity-two order, reservation reflects in the index and one delivery posts one stock/shift effect. The suite uses unique test identities per run, keeps its labeled fixtures/evidence, invokes the deployed callable and waits for deployed index triggers; it never substitutes local handlers. Its helper rejects emulator environment variables. Passing evidence is written only if all three subscenarios reached their assertions. It does not prove security rules (Admin SDK seeds/reads), trusted employee sessions, native UI flows, real scheduler timing or batch FEFO. No live test was run and nothing was deployed.

Prepared commands for user execution:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application\functions'
npm run verify
npm run test:emulator
Set-Location 'C:\Users\hp\StudioProjects\user_application'
flutter test test/availability_policy_test.dart test/medicine_sale_quote_test.dart
Set-Location 'C:\Users\hp\StudioProjects\pharmacy_app'
flutter test test/availability_policy_test.dart
```

After coordinated deployment of the reviewed functions/rules/indexes and the existing explicit live opt-in/credentials, run `node --test test/live/order-availability-live.test.js` from functions. Its evidence is stored under `_liveTestRuns/f03-live-availability-<runId>`. The newly documented batch-allocation gap, internal employee username/password authentication without email, direct financial/refund writers, remaining regression/native/live verification and final HTML progress publication remain open. No overall completion percentage or 99% claim is supported.

### Internal employee, chat, notification and query-index continuation

2026-09-14: implemented username/password-only internal employee login without
creating Firebase Auth users for employees. The pharmacy owner Firebase session
remains the transport identity. `managePharmacyEmployeeCredential` owns unique
normalized usernames and salted PBKDF2 password records;
`createPharmacyEmployeeSession` applies failure throttling and returns an opaque
12-hour bearer; `revokePharmacyEmployeeSession` revokes logout. The raw bearer
is never stored in Firestore. Changing username/password increments a credential
version and invalidates prior bearers. `executeOrderCommand` requires the bearer
whenever an employee ID is present and rereads the session, employee and current
permission inside the business transaction. Persisted pending pharmacy commands
retain only the employee ID and attach the current bearer at transport time.

The employee create/edit UI delegates protected username/password fields to the
server and never reads or writes plaintext credentials. Firestore rules deny
client access to `employeeCredentials`, `employeeUsernames`, and
`employeeSessions`, deny direct employee creation, and exclude protected login
fields from otherwise allowed profile edits. Unit cases cover hash storage,
normalization/uniqueness, lock release, legacy plaintext migration, credential
invalidation and logout. Command cases cover missing, expired, revoked,
version-stale, inactive, explicitly denied and cross-pharmacy sessions. Emulator
rules cases cover protected storage. A new isolated live suite provisions real
credentials and sessions through deployed callables before exercising an order
command. These functional/emulator/live cases are prepared, not executed.

The pharmacy now creates the deterministic order chat, system message and order
link in one transaction. Its chat action remains available during review,
partial-offer wait, confirmed/reserved, preparing and ready. Both clients and
the rules treat completed, cancelled, rejected and not-collected as read-only.
Added the missing production indexes used by user/pharmacy order lists, both
chat lists and pharmacy notification filters. User push processing now claims
each notification transactionally, records sent/skipped/failed outcome,
rethrows failures for platform retry, and uses a stable Android collapse key and
tag. A new isolated live suite proves the deployed order-notification-chat
chain plus actual rule/index queries; a real Android FCM token is still required
to prove the visible push card.

Static evidence for this continuation: backend ESLint passes and the Firestore
index JSON parses. Targeted Dart analysis reports no errors or warnings in the
employee-session service/controllers/order coordinator and no errors in the
touched user chat/notification or pharmacy order/chat sources; only existing
informational style/deprecation lints remain. Source export contract is now 14
functions. This is source readiness, not functional or deployment evidence.
Per the user's boundary, the inventory/POS batch-FEFO architecture and direct
POS refund writer remain deferred until after the order-cycle test stop; they
must not be represented as completed requirements.

### Partial-offer availability and retained-index closure

2026-09-14: the earlier device failure was a real server rejection, not a
broken accept button: `acceptPartialOffer` reported that the offered medicine
had insufficient unreserved stock. The pharmacy offer editor previously
limited a line only by the order's requested quantity, so it could publish an
offer that was already impossible after subtracting other reservations.

The canonical command handler now validates every new or revised partial offer
against the live saleable stock inside the same transaction, without reserving
it before user consent. A revision from `confirmedReserved` evaluates the new
offer after excluding the order's own reservation, then releases that old
reservation through the existing guarded path. User acceptance still repeats
the transactional availability check because another order can reserve the
stock during the decision window; this race must remain a visible failure and
must never silently reduce the consented quantity. A new regression asserts
that an already-unavailable offer is rejected with no order, counter or
reservation mutation. The pharmacy UI now translates stock, expiry, stale
offer, session and connectivity failures into bounded Arabic messages instead
of displaying the raw exception/stack.

During the coordinated index deployment Firebase reported three live `sales`
indexes and one pharmacy-notification index as absent from the canonical file.
They are active query contracts in the pharmacy client, so deletion was refused
and the canonical index file now retains their exact field order. The export
contract regression also requires these retained indexes, preventing a later
deployment from accidentally proposing them as obsolete.

Static evidence only for this closure: the changed Node source passes
`node --check` and targeted ESLint; JSON parsing and tracked whitespace checks
pass. Dart formatting passes. Flutter analysis was interrupted after the local
analyzer produced no output for more than a minute, so it is not counted as
passing evidence. No functional, emulator or live suite was executed by Codex,
and the latest callable change is not proven deployed. Stop here for the
user-owned test/deployment gate as requested.

The live lifecycle suite now also seeds an order whose medicine has two
packages with one already reserved, attempts to publish a two-package partial
offer, and requires a deployed `failed-precondition` response containing
`insufficient stock`. It verifies the complete order document is unchanged,
the physical and reserved counts remain `2` and `1`, and no reservation
document was created. This case is prepared but has not been run against the
latest deployment.

### First order-chat creation rule closure

2026-09-14: the user-owned live run completed 41 tests: 38 passed and three
were reported failed. Two failing subtests and their parent suite represented
one root defect. The first-chat transaction reads the deterministic
`chats/order_<orderId>` document before creating it, while the deployed rule
previously authorized every read only from `resource.data`. Because a missing
document has no participant fields, Firestore rejected the read before any
chat write. The following pharmacy-message test then failed as a consequence;
the order, accounting, employee identity, availability, lifecycle and other
failure-path suites all passed.

The canonical rule now permits an authenticated single-document `get` only
when an `order_` deterministic chat ID does not exist. Reads of every existing
chat and all list queries remain participant-only. Creation remains bound to a
real order whose user and pharmacy exactly match the requested chat, so the
exception discloses no existing data and grants no broader create authority.
The create rule also binds the document ID to `order_<orderId>`, preventing a
participant from creating a second chat for the same order under another ID.
An emulator regression reproduces the client transaction: it reads the order
and absent chat, atomically creates the chat and system message, links the
order, proves both participant queries, and rejects outsider and anonymous
reads. The live suite now also asserts that the chat exists before testing a
pharmacy message or terminal-order rejection, eliminating false-positive
passes caused by a missing prerequisite.

Static syntax, targeted ESLint and tracked-whitespace checks pass. The updated
rules and regressions are prepared but have not yet been run or deployed. Stop
at the user-owned emulator, rules-deployment, focused-live and full-live gates
before any interface test, as requested.
