# Roshita shared Cloud Functions

This directory is the only reviewed deployment source for the `pharma-apps`
Firebase backend. The pharmacy and admin repositories retain compatibility
shims for local discovery, but their `firebase.json` files do not deploy Cloud
Functions.

## Export and trigger map

| Export | Kind | Event or caller |
| --- | --- | --- |
| `executeOrderCommand` | Callable | Reviewed order and insurance commands |
| `managePharmacyEmployeeCredential` | Callable | Owner-managed internal username/password |
| `createPharmacyEmployeeSession` | Callable | Internal employee login without email |
| `revokePharmacyEmployeeSession` | Callable | Internal employee logout/session revocation |
| `createAdminEmployee` | Callable | Admin panel |
| `onNotificationCreated` | Firestore created | `users/{userId}/notifications/{notificationId}` |
| `onChatMessageCreated` | Firestore created | `chats/{chatId}/messages/{messageId}` |
| `onOrderCreated` | Firestore created | `orders/{orderId}` |
| `onOrderUpdated` | Firestore updated | `orders/{orderId}` |
| `sendAdminBroadcast` | Firestore created | `adminBroadcastNotifications/{broadcastId}` |
| `onMedicineStockWritten` | Firestore written | `pharmacies/{pharmacyId}/medicines/{medicineId}` |
| `onPharmacySearchProfileWritten` | Firestore written | `pharmacies/{pharmacyId}` |
| `processOrderDeadlines` | Scheduled | Every 5 minutes UTC; flags and deduplicated alerts only |
| `refreshMedicineSearchAvailability` | Scheduled | Every 15 minutes UTC; expiry projection repair |

`reserveOrderNumber`, `createOrder`, `sendOrderPushNotification`, and `onAdminBroadcastCreated` are
retired production names. The checked-out applications do not use the two
callables, and `sendAdminBroadcast` is the sole canonical owner of the broadcast
event. This table describes current SOURCE, not verified production deployment.
The stock trigger and deadline scheduler require explicit deployment after the
completion audit gates; no live deployment of these additions is claimed here.

Internal employees remain username/password-only in the UI. Their password is
stored as a salted PBKDF2 record in a server-only document and login returns an
opaque, expiring session. Order commands reread that session, the employee and
current permission state transactionally; supplying only an employee ID is not
authorization. Changing credentials invalidates earlier sessions.

The scheduler uses Cloud Scheduler and platform runtime credentials. It reads
active orders in pages, rereads each inside a transaction, and records review
delay or pickup overdue without changing status, invoice, inventory or customer
incidents. Deterministic timerEvents and notification IDs preserve read/delete
flags across retries. It is not run automatically by the Functions emulator.

## Runtime and configuration

- Runtime: Node.js 24, CommonJS.
- Custom environment variables: none are currently required.
- Credentials: Firebase runtime credentials are supplied by the platform. Do
  not commit service-account files, tokens, `.env`, or runtime secrets.
- Future local-only values belong in an ignored `*.local` file and must be
  documented here before use.

## Local verification

From `user_application/functions`:

```powershell
npm ci
npm run verify
npm run test:emulator
```

From `user_application/functions`, after installing dependencies:

```powershell
npm run emulators:start
```

Review the inventory, ordered deploy list, verification checks, and rollback
procedure before deployment.

## F02 isolated test environment

F02 uses only the synthetic project ID `demo-roshita-f02`. The test helpers
reject `pharma-apps`, every non-`demo-` project, and any emulator endpoint that
is not loopback. The fixture reset command clears Auth, Firestore, and Storage
inside the emulators only, then recreates deterministic users, beneficiaries,
pharmacies, employees, administrators, and valid/expired inventory batches.

See `../docs/f02-test-environment.md` for the commands, failure contract, and
test matrix.
