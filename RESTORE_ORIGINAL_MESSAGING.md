# Messaging test mode: use, disable, and restore

> Historical instructions: the temporary messaging test-mode code has been
> removed and the pre-test-mode Flutter messaging files have been restored.
> The endpoints and flags described below are no longer available.

This is an isolated development-only conversation. It does not change the
production chat routes, bid/proposal flow, authentication, or UI design. The
test thread and per-user read state are stored in a local JSON file outside the
repository. No test thread, message, notification, bid, task, assignment, read
state, or token is written to Neon.

## Enable

1. Run the backend with `NODE_ENV=development`. In the backend's local
   environment, set:
   - `MESSAGING_TEST_MODE=true`
   - `MESSAGING_TEST_ADMIN_ID=<existing ADMIN user id>`
   - `MESSAGING_TEST_FREELANCER_ID=<existing USER user id>`
2. Restart `next dev`. The server verifies both IDs and their current database
   roles with SELECT-only queries. Do not set these values in production.
3. Run Flutter with
   `flutter run --dart-define=MESSAGING_TEST_MODE=true`. The Dart define defaults
   to `false`; rebuild/restart the app after changing it. Sign in normally as
   either configured participant. In this mode, Flutter also suppresses FCM
   token registration/deactivation calls, so testing cannot create or modify
   token rows; push can still reach a token that was already active.
4. Open Messages. Both configured participants see the same
   `messaging-test-thread`; messages and each participant's unread state persist
   on the backend machine.

The test endpoints require the real NextAuth session cookie and are available
only when both the development environment and explicit server flag are true.
When disabled, every endpoint returns 404 before session, body, or path
processing. With the mode enabled, only the configured admin and freelancer
can access the fixed thread ID.

For manual API checks, use the signed-in session cookie:

- `GET /api/messaging-test/threads` — the participant's test inbox.
- `GET /api/messaging-test/threads/messaging-test-thread` — thread and history.
- `POST /api/messaging-test/threads/messaging-test-thread` with JSON
  `{"body":"Test message"}` — persists locally and returns push availability.
- `PATCH /api/messaging-test/threads/messaging-test-thread/read` — marks the
  participant's local read-through state.

FCM is attempted only for the exact other participant, and only by SELECTing
their already-active token(s). It sends directly through Firebase Admin; it
does not create an in-app notification or deactivate tokens. Push delivery
requires an existing active token and matching server-only Firebase Admin
configuration (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and
`FIREBASE_PRIVATE_KEY`). Otherwise the message still persists and the POST
response reports `push.available: false` with a non-sensitive reason. Tokens
and credentials are never returned.

On Windows the default local store is
`%LOCALAPPDATA%\WorkingTrust\messaging-test.json`; on other systems it is under
the user's local application-data directory. `MESSAGING_TEST_DATA_PATH` can
override this with an absolute path outside the repository. To remove test
data, stop the backend and delete that JSON file and its sibling
`messaging-test.json.next` if present. This does not affect Neon.

## Disable

- Set `MESSAGING_TEST_MODE=false` or remove it from the backend environment, and
  restart the backend. `NODE_ENV` outside development also disables every test
  route.
- Rebuild/restart Flutter without `--dart-define=MESSAGING_TEST_MODE=true` (or
  explicitly pass `false`). The existing notification-backed Messages list,
  production chat thread/read requests, and normal proposal flow remain in
  effect.
- Optionally remove the local JSON file as described above.

## Restore the pre-test-mode messaging source

The Phase 1 backup is preserved at
`messaging_original_backup\MESSAGING_ORIGINAL_FLOW.txt`; its
`MESSAGING_BACKUP_MANIFEST.txt` contains SHA-256 values for the snapshot files.
Neither backup file was modified. Disable both flags first. To restore source,
use the exact path-delimited sections in `MESSAGING_ORIGINAL_FLOW.txt` for the
pre-test-mode copies of the modified Flutter files below and verify each
restored file against the manifest hash:

- `lib\core\network\api_endpoints.dart`
- `lib\features\messages\controller\messages_controller.dart`
- `lib\features\messages\controller\project_chat_controller.dart`
- `lib\features\messages\screens\messages_screen.dart`
- `lib\features\messages\services\project_chat_service.dart`
- `lib\features\notifications\services\fcm_push_service.dart`
- `test\project_chat_test.dart`

Also remove the added `lib\core\config\messaging_test_mode.dart` and
`test\messaging_test_mode_test.dart`. Remove the added backend files
`src\app\api\messaging-test\threads\route.ts`,
`src\app\api\messaging-test\threads\[threadId]\route.ts`,
`src\app\api\messaging-test\threads\[threadId]\read\route.ts`,
`src\lib\messaging-test.ts`, `src\lib\messaging-test-store.ts`, and
`src\lib\messaging-test-store.test.ts`. Remove only the test-mode variable
block appended to `.env.example`; preserve any unrelated local edits. Do not
restore or overwrite the backup itself. Existing
`src\app\api\tasks\[id]\chat\route.ts` was not changed.

## Files changed for Phase 2

- `D:\Trust Work\.env.example` — documented server test-mode settings.
- `D:\Trust Work\src\app\api\messaging-test\threads\route.ts`
- `D:\Trust Work\src\app\api\messaging-test\threads\[threadId]\route.ts`
- `D:\Trust Work\src\app\api\messaging-test\threads\[threadId]\read\route.ts`
- `D:\Trust Work\src\lib\messaging-test.ts`
- `D:\Trust Work\src\lib\messaging-test-store.ts`
- `D:\Trust Work\src\lib\messaging-test-store.test.ts`
- `D:\WorkingTrust\lib\core\network\api_endpoints.dart`
- `D:\WorkingTrust\lib\core\config\messaging_test_mode.dart`
- `D:\WorkingTrust\lib\features\messages\controller\messages_controller.dart`
- `D:\WorkingTrust\lib\features\messages\controller\project_chat_controller.dart`
- `D:\WorkingTrust\lib\features\messages\screens\messages_screen.dart`
- `D:\WorkingTrust\lib\features\messages\services\project_chat_service.dart`
- `D:\WorkingTrust\lib\features\notifications\services\fcm_push_service.dart`
- `D:\WorkingTrust\test\messaging_test_mode_test.dart`
- `D:\WorkingTrust\test\project_chat_test.dart`
- `D:\WorkingTrust\RESTORE_ORIGINAL_MESSAGING.md`
