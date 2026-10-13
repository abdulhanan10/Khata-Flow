# KhataFlow remaining modules — integration guide

This bundle is designed to add the core Firestore-backed workspace without replacing your current Firebase login/registration UI or your existing `pubspec.yaml`.

## Included

- `lib/data/khataflow_repository.dart` — business, party, transaction, and expense data models and Firestore operations.
- `lib/features/business/business_home_screen.dart` — dashboard, business creation/switching, customer/supplier management, transaction ledger, expenses, and account settings.
- `firestore.rules` — starter Firestore rules that scope data to the signed-in business owner/member.

## 1. Copy source files

From the extracted bundle, copy these folders into the root of your existing Flutter project, merging with your existing `lib` folder:

- `lib/data/`
- `lib/features/business/`

Do not delete or replace your existing authentication classes.

## 2. Connect the new workspace to your existing AuthGate

Open `lib/main.dart` (the version where `flutter analyze lib/main.dart` reported no issues).

Add this import with the other imports at the top:

```dart
import 'features/business/business_home_screen.dart';
```

Find the existing `HomeScreen` class near the bottom of `main.dart`. It is the temporary authenticated landing screen that currently displays “Authentication connected”. Replace that entire `HomeScreen` class, from its `class HomeScreen extends StatelessWidget` declaration to the end of the file, with:

```dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return BusinessHomeScreen(user: user);
  }
}
```

Keep the existing `AuthGate`, `AuthScreen`, and `KhataFlowApp` classes. Your existing `main.dart` already imports `firebase_auth`, so `User` should be available. If it does not, add:

```dart
import 'package:firebase_auth/firebase_auth.dart';
```

## 3. Enable Cloud Firestore

In the Firebase Console for project `khataflow-cfd44`, open **Build → Firestore Database**. Create the database if it does not exist yet. Choose a location appropriate for your users and project; the database location cannot simply be changed later.

Then open the **Rules** tab. Review `firestore.rules` in this bundle and publish its contents. These rules are intentionally restrictive:

- Users can access a business they own or whose membership document they hold.
- A business owner membership is created in the same batch as the business.
- Transaction and expense records are append-only from this UI.
- Business deletion is disabled to avoid accidental deletion of financial history.

**Important:** Publishing these rules replaces the rules currently in that Firebase project's Rules tab. Review any existing rules first and merge intentionally. Do not use the app with real financial information until rules are published and reviewed.

## 4. Firestore data structure

The module writes this structure:

```text
businesses/{businessId}
  name, type, ownerId, currencyCode, createdAt, updatedAt
  members/{userId}
    userId, role, createdAt
  parties/{partyId}
    name, phone, partyType, notes, createdAt, updatedAt, createdBy
  transactions/{transactionId}
    partyId, partyName, partyType, transactionType, amountMinor,
    description, occurredAt, createdAt, createdBy
  expenses/{expenseId}
    amountMinor, category, description, occurredAt, createdAt, createdBy
```

Amounts are stored as integer minor units (for PKR, paisa) to avoid floating-point storage errors. Partial payments are represented as separate transactions; the dashboard calculates balances from those entries.

## 5. Run the full app later

As requested, this module bundle has not been presented as end-to-end tested. After applying all files and publishing reviewed rules, run these commands from the project root:

```powershell
flutter pub get
flutter analyze lib/main.dart lib/data/khataflow_repository.dart lib/features/business/business_home_screen.dart
flutter run
```

Then test registration/login, create two businesses and switch between them, create parties, record each transaction type, record split/partial payments as separate entries, add expenses, sign out, and sign back in. Keep using test data until all checks pass.

## Notes / current scope

- Business switching covers businesses owned by the signed-in account. Team invitations and adding members other than the owner are not included in this first implementation.
- Party records can be edited; deletion is disabled to preserve financial history.
- Transactions and expenses are append-only in the UI and rules. For corrections, add an offsetting entry or implement an audited correction flow later.
- Email/password auth continues to be supplied by your existing `AuthScreen`.
- Do not commit Firebase Admin credentials, service account keys, signing keystores, or other secrets to GitHub.
