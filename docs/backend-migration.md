# F01 backend source migration

## Decision

`user_application/functions` is the single deployment source for shared Cloud
Functions in Firebase project `pharma-apps`. The same repository also owns the
reviewed Firestore rules, Firestore indexes, and Storage rules. The admin
repository remains the hosting source, and the pharmacy repository remains an
application source; neither repository now declares a Functions deployment.

The source document SHA-256 reviewed for this migration is
`d4696862cbc051e0baa23c7165e0a5ef17f1fbbdbfaa02e8c82cac6754205cc3`.
The canonical Cloud Functions runtime is Node.js 24, matching the inspected
`createOrder` deployment and the supported Cloud Run functions runtime.

## Source inventory before F01

| Previous root | Export | Event |
| --- | --- | --- |
| User | `reserveOrderNumber` | callable |
| User | `onNotificationCreated` | created `users/{userId}/notifications/{notificationId}` |
| User | `onChatMessageCreated` | created `chats/{chatId}/messages/{messageId}` |
| User | `onOrderCreated` | created `orders/{orderId}` |
| User | `onOrderUpdated` | updated `orders/{orderId}` |
| User | `onAdminBroadcastCreated` | created `adminBroadcastNotifications/{broadcastId}` |
| Pharmacy | `onNotificationCreated` | created `users/{userId}/notifications/{notificationId}` |
| Admin | `sendAdminBroadcast` | created `adminBroadcastNotifications/{broadcastId}` |
| Admin | `createAdminEmployee` | callable |

The user and pharmacy repositories used the same `default` codebase. The two
broadcast export names also described the same Firestore event, so independent
deploys could overwrite a function or create duplicate event handling.

## Live production inventory captured during F01

The Firebase Functions dashboard showed eight generation-2 functions in
`us-central1`: `onOrderCreated`, `onChatMessageCreated`,
`reserveOrderNumber`, `createOrder`, `sendOrderPushNotification`,
`onAdminBroadcastCreated`, `onNotificationCreated`, and `onOrderUpdated`.
The `createOrder` detail view confirmed runtime `nodejs24`, 256 MiB memory, and
a one-minute timeout. The deployed source supplied for `createOrder` and
`sendOrderPushNotification` was reviewed. The current checked-out applications
do not call either export, and the product owner confirmed that no old-client
compatibility is required, so both names are retired.

## Canonical contract after F01

The reviewed export map is maintained in `functions/README.md` and enforced by
`functions/test/export-map.test.js`. `reserveOrderNumber` and the order, chat,
and user-notification handlers retain their public names. The admin callable
retains `createAdminEmployee`. The canonical broadcast handler uses
`sendAdminBroadcast`; `createOrder`, `sendOrderPushNotification`, and
`onAdminBroadcastCreated` are retired names and must not remain deployed.

Broadcasts accept both the admin panel's `targetType` field and the older
`target` field. Titles over 80 characters, bodies over 500 characters, missing
bodies, and unknown targets are marked `failed`. A valid job moves from
`queued` to `processing` and then `sent`; notification document IDs are
deterministic (`admin_<broadcastId>`), so a repeated write does not create a
second record. `sendAdminBroadcast` sends the broadcast push to the deduplicated
user and pharmacy token set, including user token subcollections, and marks the
created notification records so `onNotificationCreated` does not send the same
broadcast twice.

## Failure behavior

- `reserveOrderNumber` preserves its transaction and callable error contract.
- Ordinary user push failures are logged and do not erase the notification
  record.
- Invalid broadcasts become `failed` with a reason instead of appearing sent.
- A failure while writing notifications or sending broadcast push marks the
  broadcast `failed` and surfaces the error to function logs.
- `createAdminEmployee` rejects unauthenticated, inactive, or unauthorized
  callers before creating an Authentication user.
- No custom environment variable or secret is required by the canonical code.
  Firebase runtime credentials remain platform-managed; secrets must never be
  committed.

## Read-only production inventory gate

F01 did not publish, delete, migrate data, or change production. The dashboard
inventory above was captured, but Firebase CLI was not available in the
inspected environment. Capture a fresh machine-readable list immediately before
deployment:

```powershell
firebase functions:list --project pharma-apps
```

Compare the live names, regions, generations, and runtimes with the canonical
map. Stop if the live project contains an unaccounted function or if a function
uses a region not represented in the deployment command.

## Historical F01 deployment order

The commands in this section are historical F01 evidence, not the current F03
release command. In particular, do not redeploy reserveOrderNumber. Current
source exports are in functions/README.md and the unfinished release gates are
in order-cycle-completion-audit.md. Stock and scheduler additions have not been
verified as deployed.

Run `npm ci` and `npm run verify` in `user_application/functions`, then start
the emulators from `user_application`. Use isolated test data and verify order
number reservation, user push creation, chat notifications, order creation and
status updates, admin employee authorization, and one broadcast for each target.

After the inventory gate passes, deploy only named functions. Never begin with
a full `firebase deploy --only functions`:

```powershell
firebase deploy --only functions:reserveOrderNumber,functions:onNotificationCreated,functions:onChatMessageCreated,functions:onOrderCreated,functions:onOrderUpdated,functions:createAdminEmployee,functions:sendAdminBroadcast --project pharma-apps
```

Verify that `sendAdminBroadcast` claims one queued test record, creates the
expected deterministic notification records, updates status, and produces no
duplicate push. Remove the three retired exports explicitly using their live
region:

```powershell
firebase functions:delete createOrder sendOrderPushNotification onAdminBroadcastCreated --region <verified-region> --project pharma-apps --force
```

Deploy the reviewed rules and indexes from `user_application` only after their
emulator checks pass:

```powershell
firebase deploy --only firestore:rules,firestore:indexes,storage --project pharma-apps
```

Do not deploy from `pharmacy_app/functions` or
`Roshita_Admin_Panel/functions`. Do not approve any CLI prompt to delete a name
that has not passed the inventory and responsibility checks above.

## Rollback

1. Stop new admin broadcasts and record the failed deployment/function names.
2. Restore the last known-good canonical files from version control; do not
   reset unrelated Flutter work.
3. Redeploy only the affected named functions from the restored source.
4. If broadcast cutover fails, stop queued broadcasts and fix or roll back the
   canonical `sendAdminBroadcast` source before accepting new jobs.
5. Restore the previous rules/index files only if the rules deployment itself
   caused the regression. Never roll back application data as part of this
   procedure.

## Historical deployed snapshot and pending F03 release

The last verified F01 production deployment contained seven generation-2,
`nodejs24` functions in `us-central1`: `reserveOrderNumber`,
`createAdminEmployee`, `onNotificationCreated`, `onChatMessageCreated`,
`onOrderCreated`, `onOrderUpdated`, and `sendAdminBroadcast`. The retired names
`createOrder`, `sendOrderPushNotification`, and `onAdminBroadcastCreated` were
absent. That historical inventory is not evidence for the current F03 source.

The current reviewed source contract contains 14 functions. After the user-run
local and emulator suites pass, capture `functions:list`, then deploy exactly
the named current set from `user_application` (never from the other two apps):

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application'
node --use-system-ca $firebaseCli deploy --only "functions:processOrderDeadlines,functions:refreshMedicineSearchAvailability,functions:onPharmacySearchProfileWritten,functions:onMedicineStockWritten,functions:executeOrderCommand,functions:managePharmacyEmployeeCredential,functions:createPharmacyEmployeeSession,functions:revokePharmacyEmployeeSession,functions:createAdminEmployee,functions:onNotificationCreated,functions:onChatMessageCreated,functions:onOrderCreated,functions:onOrderUpdated,functions:sendAdminBroadcast" --project pharma-apps
node --use-system-ca $firebaseCli deploy --only "firestore:rules,firestore:indexes" --project pharma-apps
node --use-system-ca $firebaseCli functions:list --project pharma-apps
```

Do not delete `reserveOrderNumber` merely because it is no longer in the source
until the fresh inventory and the already-reviewed retirement decision are
reconfirmed. The Firebase CLI may prompt about removing an unexported function;
reject any deletion prompt during the named deployment. Only the explicit
post-inventory retirement command is authorized. Then run the opt-in live
suites and both native manual flows from the order-cycle audit. Until those
results exist, F03 is ready for testing but neither deployed nor verified.
