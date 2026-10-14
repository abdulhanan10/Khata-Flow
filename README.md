# KhataFlow

**KhataFlow** is a Flutter-based business ledger app for small businesses. It helps a business owner keep customer and supplier records, record credit and payments, track expenses, view financial summaries, and ask questions about business activity using an AI assistant.

> **Project status:** The Flutter tests have passed locally (6 tests). The app and AI backend should still be tested together on a real device with a signed-in Firebase account before the app is treated as production-ready. The AI backend uses a Render web service and Gemini; it is not the same as deploying Firebase Cloud Functions.

## Features

- **Firebase Authentication** — sign up, log in, password recovery, and sign out.
- **Multiple businesses** — create and switch between business workspaces.
- **Dashboard** — view key business totals and ledger activity for the selected business.
- **Customers and suppliers** — add and manage parties, search records, and inspect transaction history.
- **Ledger transactions** — record credit given, payments received, credit taken, and payments made.
- **Partial payments** — record a payment as a separate ledger entry so the remaining balance can be recalculated.
- **Expenses** — record business expenses with categories and review expense history.
- **KhataFlow Pulse** — display explainable signals derived from the selected business's stored records.
- **Ask KhataFlow** — ask typed questions, use speech-to-text where supported, and optionally hear answers with text-to-speech.
- **Firebase Firestore** — store business and ledger data in the cloud, subject to the configured Firestore rules.

## Technology stack

| Area | Technology |
| --- | --- |
| Mobile application and UI | Flutter, Dart, Material |
| Authentication | Firebase Authentication |
| Business and ledger data | Cloud Firestore |
| AI assistant UI | Flutter http, speech_to_text, flutter_tts |
| AI API | Google Gemini (gemini-2.5-flash) |
| AI backend hosting | Render |
| AI request identity | Firebase ID token verified by the backend |
| Tests | Flutter test framework |

## How the AI assistant works

1. The user signs in through Firebase Authentication in the Flutter app.
2. The user opens a business and asks a question in Ask KhataFlow.
3. Flutter obtains the user's Firebase ID token and sends it with the selected businessId and question to the Render endpoint: https://khata-flow.onrender.com/api/assistant.
4. The Render Node.js/Express server verifies the Firebase ID token and checks whether the user can access the requested business.
5. The backend reads relevant business and ledger records through the Firestore REST API using the user's token, then prepares context for Gemini.
6. Gemini generates an answer, which the backend returns to Flutter.
7. Flutter displays the answer and, if spoken replies are enabled, uses the phone's text-to-speech engine.

The Gemini API key belongs in Render's server-side environment variables. **Never place the Gemini API key in Dart code, commit it to Git, or ship it inside the APK.**

### Render environment and deployment

The Render web service is configured for the render_backend directory:

- **Root Directory:** render_backend
- **Build Command:** npm install
- **Start Command:** npm start
- **Environment variable:** GEMINI_API_KEY — set privately in Render
- **Environment variable:** FIREBASE_PROJECT_ID=khataflow-cfd44

Service health check: https://khata-flow.onrender.com/health

The backend endpoint requires a valid Firebase ID token. A successful health check only confirms that the web service is running; it does not prove that authentication, Firestore access, or a Gemini request has succeeded end to end.

**Privacy note:** To answer a question, relevant business data—including party names, transaction details, and notes where included in the context—is sent to Google's Gemini service. Do not use the assistant with sensitive business data unless this processing is acceptable to you. Review the backend's context-building logic before expanding the data it sends.

**Availability and cost:** Render free services may sleep after inactivity, causing a delay on the first request. Gemini usage and hosting are subject to the providers' current quotas, policies, and pricing. Do not assume unlimited or permanently free service.

## Run locally

Requirements:
- Flutter SDK and Dart compatible with the constraints in pubspec.yaml
- Android Studio / Android SDK for Android builds
- A configured Firebase project and valid lib/firebase_options.dart
- Node.js and npm if running the AI backend locally

From the project root:

~~~powershell
flutter pub get
dart format lib test
flutter analyze lib test
flutter test
~~~

Run on a connected device:

~~~powershell
flutter devices
flutter run -d <DEVICE_ID>
~~~

Build a release APK:

~~~powershell
flutter build apk --release
~~~

The APK is normally created at:

~~~text
build/app/outputs/flutter-apk/app-release.apk
~~~

Install on a connected Android device:

~~~powershell
flutter install --release -d <DEVICE_ID>
~~~

For distribution beyond personal testing, configure and protect an Android release signing key. Keep keystore files and passwords out of Git. A Google Play release generally uses an Android App Bundle (.aab) and requires Play Console setup and compliance with current Play policies.

## Run the AI backend locally

From the repository root:

~~~powershell
cd render_backend
npm install
$env:GEMINI_API_KEY = "set-your-key-in-this-local-terminal"
$env:FIREBASE_PROJECT_ID = "khataflow-cfd44"
npm start
~~~

Do not replace the placeholder with a real key in documentation, source code, or a committed file. For production, configure environment variables through Render's service settings. The local server listens on the port configured by the backend (Render supplies PORT automatically).

Health check:

~~~powershell
Invoke-RestMethod http://localhost:3000/health
~~~

The assistant request also requires a real Firebase ID token and a business the signed-in user is authorized to access; the health endpoint does not test those requirements.

## Repository map

~~~text
lib/
  main.dart                         App entry point
  app/khata_flow_app.dart            Root MaterialApp
  core/theme/app_theme.dart          Shared visual theme
  data/khataflow_repository.dart     Firestore data operations
  features/
    auth/                            Sign-in, sign-up, password recovery
    business/                        Business workspace and ledger screens
      parts/                         Dashboard, parties, transactions, expenses, settings
    assistant/                       Gemini assistant UI and network request
render_backend/
  server.js                          Express API, auth, Firestore context, Gemini request
  package.json                       Backend scripts and dependencies
functions/
  index.js                           Firebase callable-function implementation retained in the repo
firestore.rules                      Firestore access rules
firebase.json                        Firebase CLI configuration
pubspec.yaml                         Flutter dependencies and app configuration
test/widget_test.dart                Flutter widget tests
~~~

The active Flutter app's Ask KhataFlow screen is configured to call the **Render backend**. The repository also contains a Firebase Cloud Function implementation under functions/; that alternative requires Firebase Functions deployment configuration and may require a Blaze billing plan. Do not assume the retained function is deployed or used by the current Flutter screen.

## Security checklist

- Keep GEMINI_API_KEY only in Render environment settings or another trusted secret store.
- Do not commit .env files, service-account JSON files, signing keys, passwords, or API secrets.
- Keep Firestore rules restrictive and test access using accounts with different permissions.
- The backend verifies Firebase identity and business access before preparing AI context; keep those checks in place.
- Treat the assistant's output as AI-generated guidance and independently verify financial calculations before making business decisions.
- Before a public release, test sign-up, sign-in, password reset, business switching, all transaction types, expense entry, access control, offline/network failures, and AI responses on a physical device.

## More project notes

- [Integration notes](INTEGRATION.md)
- [Modular architecture notes](MODULAR_ARCHITECTURE.md)
