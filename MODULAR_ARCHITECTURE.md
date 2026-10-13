# KhataFlow modular Dart refactor

This bundle reorganizes the current project without changing the existing Firestore repository, security rules, `pubspec.yaml`, or Firebase config.

## What changes

- `lib/main.dart`: Firebase bootstrap only.
- `lib/app/khata_flow_app.dart`: MaterialApp and app theme entry.
- `lib/core/theme/app_theme.dart`: shared theme tokens/styles.
- `lib/features/auth/auth_gate.dart`: session routing and startup recovery UI.
- `lib/features/auth/screens/login_screen.dart`: login form.
- `lib/features/auth/screens/signup_screen.dart`: account registration form.
- `lib/features/auth/screens/forgot_password_screen.dart`: password reset form.
- `lib/features/auth/widgets/`: shared auth logo/header and form-card layout.
- `lib/features/business/business_home_screen.dart`: workspace shell + helpers.
- `lib/features/business/parts/`: dashboard, parties, transactions, expenses, and settings/account screens.

The business page pieces use Dart `part` files to preserve the existing private helper widgets and models while splitting the long screen into manageable files. The authentication screens are separate Dart libraries.

## Apply

1. Extract this ZIP into the root of your cloned project, for example `E:\khata_flow`. The bundle's files are under `modular_refactor/`, so they won't overwrite your source automatically.
2. In PowerShell, while in the project root, run:

   ```powershell
   .\scripts\apply_modular_refactor.ps1
   ```

   The script backs up the two files it replaces (`lib\main.dart` and `lib\features\business\business_home_screen.dart`) into `.git\` first when a Git repository is present. It then copies the modular files into `lib\`.
3. Verify the logo file exists at `lib\assets\images\app_logo.png`. This bundle assumes `pubspec.yaml` already declares `lib/assets/images/app_logo.png`, as in the current project.
4. Run:

   ```powershell
   dart format lib
   flutter pub get
   flutter analyze lib/main.dart lib/app lib/core lib/features lib/data
   flutter test test/widget_test.dart
   ```

5. Only after analysis/tests are successful, build/run the app. End-to-end Firebase tests still need to be performed manually with test data.

## Not included/unchanged

- `pubspec.yaml` and `pubspec.lock`
- `lib/firebase_options.dart`
- `lib/data/khataflow_repository.dart`
- `firestore.rules`
- `test/widget_test.dart`

If `scripts/apply_modular_refactor.ps1` cannot find `.git`, it stores backups in `.khataflow_backup` instead. Do not commit those backup files.
