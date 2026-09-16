# F02 isolated test environment

## Safety contract

The F02 harness targets only `demo-roshita-f02`. It refuses the production
project `pharma-apps`, refuses every project ID that does not begin with
`demo-`, and refuses Auth, Firestore, Storage, or Functions endpoints that are
not bound to `127.0.0.1`, `localhost`, or `::1`.

The fixture commands never call a production cleanup API. Reset clears only
the locally running Auth, Firestore, and Storage emulators. The Firebase
Emulator UI is disabled so running the suite does not download an unnecessary
UI bundle.

## Fixed fixtures

Every reset recreates the same IDs and timestamps:

- users `user-one` and `user-two`;
- beneficiaries `beneficiary-one` and `beneficiary-two` under their owners;
- pharmacies `pharmacy-one` and `pharmacy-two`;
- pharmacy employees `employee-manager` and `employee-viewer` with different
  permissions;
- administrators `admin-allowed` and `admin-denied`;
- inventory entries `batch-valid` and `batch-expired` with fixed expiry dates.

The fixtures use test-only `@f02.test` addresses and a fixed test password.
They are not valid production identities.

## Commands

From `user_application/functions`:

```powershell
npm ci
npm run verify
npm run test:emulator
```

`test:emulator` starts Auth, Firestore, Storage, and Functions, runs the isolated
suite, shuts all emulators down, and records the actual exit status and tool
versions in `test/results/f02-latest.json`. That generated file is ignored by
Git and is never pre-populated with a passing result.

Firebase CLI requires Java 21 or newer. The runner honors
`ROSHITA_JAVA_HOME` and otherwise uses `JAVA_HOME`; on Windows it also detects
the Java 21 runtime bundled with Android Studio.

For an interactive emulator session:

```powershell
npm run emulators:start
```

While that command remains running, use a second terminal in the same folder:

```powershell
npm run fixtures:reset
npm run fixtures:seed
```

Both commands fail closed if the emulator is unavailable or the environment is
not isolated.

From each Flutter application root:

```powershell
flutter test --dart-define=ROSHITA_TEST_PROJECT_ID=demo-roshita-f02
flutter test integration_test/f02_environment_test.dart --dart-define=ROSHITA_TEST_PROJECT_ID=demo-roshita-f02 --dart-define=ROSHITA_USE_FIREBASE_EMULATORS=true
```

From `Roshita_Admin_Panel`:

```powershell
npm ci
npm test
npm run test:e2e
```

The admin test mode loads `.env.test`, connects every Firebase client to the
loopback emulator ports, and throws before Firebase initialization if test mode
does not explicitly enable emulators or uses a non-demo project.

## Reliability helpers

`test/helpers/commands.js` provides:

- a barrier that releases two or more operations concurrently;
- replay with one stable `operationId` and lookup of a result committed before
  the response was lost;
- a lost-response-after-commit fault wrapper;
- an injectable clock with deterministic set and advance operations.

Failures remain visible as rejected operations or nonzero test exit codes. No
helper converts an unknown result into success. The emulator runner records
`passed` only when the real child process exits with code zero.
