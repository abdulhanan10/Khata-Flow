# KhataFlow — Core business modules

This source bundle adds the first complete Firestore-backed business workspace around the existing Firebase Auth flow.

## Modules included

1. Multiple owned businesses and in-app business switching.
2. Dashboard summaries for receivables, payables, expenses, and ledger entry count.
3. Customer/supplier records with search, edit, notes, and per-party transaction history.
4. Ledger entries for credit given, payment received, credit taken, and payment made.
5. Partial payments supported by adding separate transactions, with balances recalculated from the ledger.
6. Business expense recording with categories and a history list.
7. Settings/business list, signed-in profile display, and sign out.
8. Starter Firestore security rules.

## Apply to your existing project

1. Download and extract the ZIP directly into `C:\Users\DELL\StudioProjects\flutter_test_app`, merging the existing `lib` folder. The archive doesn't contain or replace `pubspec.yaml` or Firebase configuration.
2. In Android Studio Terminal (PowerShell) run:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\scripts\integrate_modules.ps1
   ```

   The script adds the workspace import and replaces only the old placeholder `HomeScreen` class. It preserves `AuthGate` and `AuthScreen`; it also stores a one-time backup inside `.git`.
3. Review and publish `firestore.rules` in Firebase Console → Firestore Database → Rules. Review existing rules before replacing them.
4. When you're ready to run the full suite, use the commands shown in `INTEGRATION.md`.

This bundle is not represented as end-to-end tested. It needs to be integrated into your local Flutter project and checked with your installed Flutter SDK and Firebase project before use with real ledger data.

## KhataFlow Pulse and voice assistant

The dashboard includes **KhataFlow Pulse**, which computes explainable balance, collection and expense signals from the selected business records. It does not label balances overdue because the current schema has no due-date field.

**Ask KhataFlow** provides typed questions, Android speech-to-text and spoken responses. It uses Gemini 2.5 Flash from a trusted Firebase callable function; the Gemini API key is never embedded in the Flutter app. The function verifies Firebase Authentication and selected-business ownership/membership before reading ledger data. Business context (including party names and transaction notes) is sent to Google Gemini to answer the question, so use the feature only if that processing is acceptable for your business data.

### Install and run

From the project root:

```powershell
flutter pub get
dart format lib test
flutter analyze lib test
flutter test
```

### Configure the AI backend

1. Install the Firebase CLI and sign in, then confirm the selected project is `khataflow-cfd44`.
2. Firebase Functions deployment and Secret Manager require the Firebase project to be on the **Blaze billing plan**. Gemini API usage itself has a free tier subject to Google's current model and rate limits; neither quota nor backend hosting is guaranteed unlimited or entirely cost-free.
3. Create a Gemini API key in Google AI Studio, then store it as a Firebase secret (do not put it in Dart code, Git, or a `.env` file committed to the repo):

   ```powershell
   firebase use khataflow-cfd44
   firebase functions:secrets:set GEMINI_API_KEY
   firebase deploy --only functions
   ```

4. Run the app again after `flutter pub get`. The callable function is deployed in `us-central1` and uses `gemini-2.5-flash`.

If the AI service is not configured, the assistant screen shows a setup message. Speech recognition availability depends on Android's installed speech service and microphone permission; spoken replies use the device's text-to-speech engine.