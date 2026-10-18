# Roshita User App and Backend

Source repository for the Roshita mobile application and its Firebase backend.

## Repository map

- `lib/`: Flutter mobile application.
- `functions/`: Firebase Cloud Functions, domain logic, and backend tests.
- `backend/`: prescription processing service and its tests.
- `test/`, `integration_test/`, `test_cases/`: application and acceptance tests.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json`: Firebase security and index configuration.
- `docs/`: architecture, release, deployment, and testing notes.

## Setup

1. Install Flutter using the project version/channel expected by the local environment.
2. Run `flutter pub get`.
3. Create local Firebase configuration files as needed. Do not commit Admin SDK credentials.
4. For Cloud Functions, run `npm ci` inside `functions/`.
5. For the Python prescription service, install dependencies from `backend/requirements.txt`.

## Tests

- Flutter: `flutter test`
- Cloud Functions: `cd functions; npm test`
- Prescription service: follow `backend/tests/README.md`

Live Firebase tests require an explicitly configured test project or emulator. Read the environment notes in `docs/` before running them.
