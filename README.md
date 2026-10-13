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
