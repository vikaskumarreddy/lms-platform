# Firebase Push Notifications — Setup & Testing Guide

This guide walks through creating a Firebase project for this LMS, wiring its
keys into the admin portal, and verifying end-to-end that push notifications
actually reach a student's phone.

Nothing Firebase-related is hardcoded in this codebase. Every key lives in the
`system_config` table and is edited from **Admin Portal → Settings**. That
means:

- No `google-services.json` or `GoogleService-Info.plist` needs to be bundled
  into the mobile app.
- Rotating a key (e.g. after a leak) is a Settings-page edit + save, not a
  redeploy — `FcmService` reads the config from the database on every send.
- The mobile app fetches its Firebase config from the backend at startup
  (`GET /api/system-config/public/firebase`, unauthenticated by design — see
  `SecurityConfig.java:39`) instead of shipping it in the APK/IPA.

## How it fits together

```
Admin Portal Settings page
   → PUT /api/system-config/by-key/{key}     (saves into system_config table)

Mobile app startup (main.dart)
   → GET /api/system-config/public/firebase  (apiKey, appId, messagingSenderId, projectId)
   → Firebase.initializeApp(options: ...)
   → PushNotificationService.initialize()
       → requests notification permission
       → FirebaseMessaging.instance.getToken()
       → PUT /api/students/{id}/fcm-token    (saves token onto the User row)

Admin creates an assignment/exam/drive/event/certificate
   → Controller saves the entity
   → NotificationService.safeNotify(...)  (audience = students by batch/plan)
       → saves in-app Notification rows
       → FcmService.sendToTokens(...)     (only if push.enabled=true and a
                                            service-account JSON is configured)
           → mints an OAuth2 token from the service account
           → POST https://fcm.googleapis.com/v1/projects/{projectId}/messages:send
```

There are **two separate sets of keys** you need, for two different purposes:

| Keys | Used for | Where they're used |
|---|---|---|
| `firebase.apiKey`, `firebase.appId`, `firebase.messagingSenderId`, `firebase.projectId` | Letting the **mobile app** initialize Firebase and register for a device token | `firebase_options.dart` (fetched from backend) |
| `firebase.serviceAccountJson`, `push.enabled` | Letting the **backend** authenticate to Google and actually send pushes via FCM's HTTP v1 API | `FcmService.java` |

Both are required — the app needs the first set to *get* a token, the backend
needs the second set to *send to* that token.

> **Known limitation:** the current schema stores one global set of client
> keys (not one per platform). If you only test on Android, register the
> Android app in Firebase and use its credentials. If you later need iOS too,
> the single `firebase.appId`/`firebase.apiKey` pair can only match one
> platform at a time — extending `system-config`/`public/firebase` to return
> platform-specific values would be a follow-up if that's needed.

---

## Part 1 — Create the Firebase project

1. Go to the [Firebase Console](https://console.firebase.google.com/) and sign in with the Google account that should own this organization's project.
2. Click **Add project**.
3. Name it something identifiable, e.g. `lms-<yourorg>-prod` (or `-staging` for a test project — recommended so test pushes never risk hitting production data).
4. Google Analytics is optional for this use case — you can disable it.
5. Wait for provisioning, then open the project.

## Part 2 — Register the Android app (needed for the mobile client keys)

1. In the Firebase Console, click the **Android** icon (**Add app**).
2. **Android package name** — this must exactly match the app's `applicationId`. Check it first:
   ```
   backend not involved here — check the Flutter project:
   mobile-app/android/app/build.gradle.kts → applicationId
   ```
   As of this writing that value is `com.example.lms_student_app` — a Flutter
   default placeholder. **Decide now whether to keep it or rename it** (e.g.
   to `com.yourorg.lms`) before registering, since Android package names are
   effectively permanent once you've published anywhere. If you rename it,
   update `applicationId` in `mobile-app/android/app/build.gradle.kts` (and
   the corresponding namespace) to match what you register here.
3. App nickname: anything, e.g. "LMS Student App".
4. SHA-1 debug/release signing certificate: **not required** for FCM to work — only needed for Dynamic Links/Auth features this app doesn't use. You can skip it.
5. Click **Register app**.
6. On the next screen, Firebase offers to download `google-services.json` —
   **you can skip/dismiss this**. This app fetches its config from the
   backend at runtime instead (see `firebase_options.dart`), so the file
   isn't wired into the Gradle build. Click through **without** adding the
   Google Services Gradle plugin.
7. Back on the project's **Project settings → General** tab, under "Your apps", click the Android app you just added and note:
   - **App ID** (looks like `1:1234567890:android:abcdef123456`)
   - **API key** — shown either there or under **Project settings → General → Web API Key** section
   - **Project ID**
   - **Project number** = `messagingSenderId`

   (If the Android app card doesn't show an API key directly, use **Project settings → General → Project ID** and the **Web API Key** listed at the bottom of that same General tab — it's a project-level key valid for any of the project's registered apps.)

## Part 3 — Enable Cloud Messaging

1. In **Project settings → Cloud Messaging**, confirm the **Firebase Cloud Messaging API (V1)** is enabled. If you see a banner suggesting you enable it, click through — this is the API `FcmService.java` calls (`https://fcm.googleapis.com/v1/projects/...`). The legacy server-key API is deprecated and not used by this backend, so ignore any "Server key"/"Legacy" field.
2. (iOS only, skip if Android-only for now) Under the same tab, upload an **APNs Authentication Key** — FCM cannot deliver to iOS devices without one. Not needed to test on Android.

## Part 4 — Generate the service account (for the backend to send pushes)

1. Go to **Project settings → Service accounts**.
2. Click **Generate new private key**. Confirm the download — this gives you a `.json` file containing a private key.
3. **Treat this file as a secret credential:**
   - Never commit it to git.
   - Don't paste it into Slack/email in plaintext if avoidable — use the admin portal directly.
   - If it's ever exposed, go back to this same screen and revoke/regenerate it (old keys can be deleted from **IAM & Admin → Service Accounts → Keys** in Google Cloud Console).
   - The identity minted from this file only has the `firebase.messaging` OAuth scope requested in `FcmService.mintAccessToken`, but the key file itself grants whatever roles the service account has in IAM — don't grant it more than `Firebase Cloud Messaging API Admin` needs.
4. Open the downloaded JSON in a text editor. You'll need to paste its **entire contents** (all of it, including the outer `{ }`) into the admin portal in the next step.

## Part 5 — Configure keys in the Admin Portal

1. Log in to the admin portal as an `ADMIN` or `INSTITUTE_ADMIN`.
2. Go to **Settings**.
3. Find the **🔥 Firebase Configuration** section and fill in, from Part 2:
   - `firebase.apiKey`
   - `firebase.appId`
   - `firebase.messagingSenderId`
   - `firebase.projectId`
4. Find the **Push Notifications** section and fill in, from Part 4:
   - `firebase.serviceAccountJson` — paste the full JSON file contents here.
   - `push.enabled` — set to `true`.
5. Save. There's no backend restart required — `FcmService` reads these
   values straight from the database on every send call, so the change is
   live for the very next notification.

## Part 6 — Confirm the mobile app can register a device token

1. Run the mobile app on a **physical Android device or an emulator with
   Google Play services** (a bare AOSP emulator without Play services won't
   get an FCM token).
2. Log in as a student. On startup the app calls
   `GET /api/system-config/public/firebase` — if `apiKey`/`appId` come back
   non-empty, it calls `Firebase.initializeApp` and `PushNotificationService`
   requests notification permission and fetches a token.
3. Grant the notification permission prompt if asked.
4. Verify the token made it to the backend — the simplest check is a DB query:
   ```sql
   SELECT id, name, fcm_token FROM users WHERE id = <student id>;
   ```
   `fcm_token` should now be populated (a long string). If it's still null:
   - Confirm Part 5's four `firebase.*` keys are actually saved (re-open Settings and check they didn't get cleared).
   - Check the app's debug console for `Push notification init skipped: ...` or `Failed to register FCM token: ...` — both are caught and logged rather than crashing the app, so look at `flutter run` / logcat output.
   - Confirm the device has internet access and Google Play services isn't disabled.

## Part 7 — Send a test push

Two ways, from least to most end-to-end:

### A. Direct FCM smoke test (isolates FCM delivery from app logic)

With the student's `fcm_token` from Part 6, call the existing manual-send endpoint as a logged-in admin:

```bash
curl -X POST http://localhost:8080/api/notifications \
  -H "Authorization: Bearer <admin JWT>" \
  -H "Content-Type: application/json" \
  -d '{
        "title": "Test push",
        "message": "If you see this on your phone, FCM is wired up correctly.",
        "type": "info",
        "targetType": "USER",
        "userIds": [<student id>]
      }'
```

You should see the notification arrive in the device's system tray within a
few seconds (if the app is backgrounded/closed) or in the debug console log
line `Foreground push received: ...` (if the app is in the foreground).

If nothing arrives, check the backend logs for `FCM send failed: ...` — this
is printed by `FcmService.sendToToken` on any error, and the message usually
tells you exactly what's wrong (invalid service account JSON, wrong
`project_id`, expired/unregistered token, etc. — see Troubleshooting below).

### B. Full feature test (the actual feature the user asked for)

This exercises the real trigger path added to `AssignmentController`,
`ExamController`, `PlacementDriveController`, `EventController`, and
`CertificateController` — each one calls `NotificationService.safeNotify(...)`
right after saving.

1. Make sure the test student is in a batch (assignments/exams/events) and/or
   on a subscription plan (placement drives/events) that you're about to target.
2. In the admin portal, create one of:
   - **Assignment** or **Exam** — assign it to a batch that includes the test student (or leave batches empty, which targets every student).
   - **Placement Drive** — assign it to a plan the test student is on (or leave the plan empty for "everyone").
   - **Event / Calendar Event** — assign its batch and/or plan to match the student (both admin portal calendar and events pages hit the same `/api/events` endpoint, so either surface works).
   - **Certificate** — issue one directly to the test student.
3. Watch the device — the push should arrive within a couple of seconds of hitting Save, carrying a `data.actionUrl` payload (e.g. `/assignments`, `/exams`, `/placement-drives`, `/calendar`, `/certificates`) that deep-links into the right screen if the user taps the notification.
4. Also confirm the in-app **Notifications** list picked up the same event (these are written unconditionally, independent of whether push actually delivered — so an empty in-app list plus no push means the trigger itself didn't fire, whereas a populated in-app list plus no push narrows it down to FCM/config).

### C. Testing the new plan-upgrade-request notifications

This is the other notification path added in this feature set:

1. As a student in the mobile app, go to **Subscription** and tap **Request Upgrade** on a plan.
2. Confirm `INSTITUTE_ADMIN`/`ADMIN` users for that organization receive a
   "Plan upgrade requested" push + in-app notification, and that the request
   shows up under **📥 Plan Upgrade Requests** on the admin **Subscriptions** page.
3. Approve or reject it from that admin screen.
4. Confirm the student receives an "Upgrade approved" or "Upgrade request declined" push back.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `fcm_token` stays null on the student row | App never called `Firebase.initializeApp` — usually because `GET /api/system-config/public/firebase` returned an empty `apiKey`/`appId` (Part 5 keys not saved), or the device has no Google Play services. |
| Backend logs `FCM send failed: 401 UNAUTHORIZED` or `invalid_grant` | `firebase.serviceAccountJson` is malformed, truncated (check nothing got cut off pasting into the Settings textarea), or was revoked in Google Cloud Console. |
| Backend logs `FCM send failed: ... NOT_FOUND` on `messages:send` | `project_id` inside the pasted service-account JSON doesn't match a real project, or the Cloud Messaging API isn't enabled on that project. |
| Backend logs `FCM send failed: ... UNREGISTERED` / `404` | The device's FCM token is stale (app reinstalled, or `FirebaseMessaging.instance.deleteToken()` was called on logout without a fresh login yet). Re-open the app while logged in to get a fresh token registered. |
| Everything configured but nothing sends, no error logged | `push.enabled` is not literally the string `true` (case-insensitive is fine, but check for stray whitespace) — `FcmService.isPushEnabled()` requires an exact match. |
| Works on Android, nothing on iOS | Missing APNs Authentication Key upload (Part 3, step 2) — FCM cannot deliver to iOS without it, independent of the service account being correct. |
| In-app notification appears but no push | Push wasn't enabled/configured at all — this is expected/by-design (`safeNotify` always writes the in-app row regardless of push status), not a bug. Recheck Part 5. |

## Security notes (recap)

- `firebase.serviceAccountJson` and the API keys are stored as plain values in `system_config` — treat DB access and admin-portal login as sensitive accordingly for this table's contents.
- Never commit the downloaded service-account `.json` file to git. If your editor auto-saves it somewhere inside the repo while copy-pasting, delete it afterward and double check `git status` before any commit.
- Use a **separate Firebase project for staging/testing** vs. production so a mis-targeted broadcast during testing never reaches real students.
